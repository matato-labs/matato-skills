import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import type {
  CustomMessageEntryDraft,
  ExtensionAPI,
  Theme,
} from "@earendil-works/pi-coding-agent";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  truncateTail,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const MAX_BATCH_SIZE = 16;

interface SubagentTask {
  prompt: string;
  cwd?: string;
}

interface ProcessResult {
  code: number;
  stdout: string;
  stderr: string;
}

type TaskOutput =
  { output: string; error?: never } | { error: string; output?: never };

interface SingleSubagentParams {
  prompt: string;
  cwd?: string;
}

interface BatchSubagentParams {
  tasks: Array<SubagentTask>;
}

type SubagentParams = SingleSubagentParams | BatchSubagentParams;

function getPiInvocation(args: Array<string>): {
  command: string;
  args: Array<string>;
} {
  const script = process.argv[1];
  if (script && !script.startsWith("/$bunfs/root/") && existsSync(script)) {
    return { command: process.execPath, args: [script, ...args] };
  }

  const executable = basename(process.execPath).toLowerCase();
  return /^(node|bun)(\.exe)?$/.test(executable)
    ? { command: "pi", args }
    : { command: process.execPath, args };
}

function runPi(
  args: Array<string>,
  cwd: string,
  signal: AbortSignal,
): Promise<ProcessResult> {
  return new Promise((resolvePromise) => {
    const invocation = getPiInvocation(args);
    const child = spawn(invocation.command, invocation.args, {
      cwd,
      env: {
        ...process.env,
        PI_OFFLINE: "1",
        PI_SUBAGENT_DEPTH: String(
          Number(process.env.PI_SUBAGENT_DEPTH ?? "0") + 1,
        ),
      },
      shell: false,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let settled = false;
    let killTimer: NodeJS.Timeout | undefined;

    const finish = (result: ProcessResult) => {
      if (settled) return;
      settled = true;
      cleanup();
      resolvePromise(result);
    };
    const abort = () => {
      child.kill("SIGTERM");
      killTimer = setTimeout(() => child.kill("SIGKILL"), 5_000);
    };
    const cleanup = () => {
      if (killTimer) clearTimeout(killTimer);
      signal.removeEventListener("abort", abort);
    };

    child.stdout.on("data", (chunk: Buffer) => (stdout += chunk.toString()));
    child.stderr.on("data", (chunk: Buffer) => (stderr += chunk.toString()));
    child.once("error", (error: Error) =>
      finish({ code: 1, stdout, stderr: error.message }),
    );
    child.once("close", (code) => finish({ code: code ?? 1, stdout, stderr }));

    if (signal.aborted) abort();
    else signal.addEventListener("abort", abort, { once: true });
  });
}

export async function runConcurrent<T, R>(
  tasks: Array<T>,
  run: (task: T, index: number) => Promise<R>,
): Promise<Array<R>> {
  return Promise.all(tasks.map(run));
}

function processError(
  result: ProcessResult,
  output: string,
): string | undefined {
  if (result.code === 0) return;
  return (
    result.stderr.trim() || output || `Subagent exited with code ${result.code}`
  );
}

async function saveTruncatedOutput(
  output: string,
  truncated: ReturnType<typeof truncateTail>,
  tempDirs: Set<string>,
): Promise<TaskOutput> {
  const dir = await mkdtemp(join(tmpdir(), "pi-subagent-"));
  const file = join(dir, "output.txt");
  tempDirs.add(dir);
  await writeFile(file, output, { encoding: "utf8", mode: 0o600 });
  return {
    output: `${truncated.content}\n\n[Output truncated to ${truncated.outputLines} of ${truncated.totalLines} lines (${formatSize(truncated.outputBytes)} of ${formatSize(truncated.totalBytes)}). Full output: ${file}]`,
  };
}

async function taskOutput(
  result: ProcessResult,
  tempDirs: Set<string>,
): Promise<TaskOutput> {
  const output = result.stdout.trim();
  const error = processError(result, output);
  if (error) return { error };
  if (!output) return { error: "Subagent finished without output" };

  const truncated = truncateTail(output, {
    maxBytes: DEFAULT_MAX_BYTES,
    maxLines: DEFAULT_MAX_LINES,
  });
  if (!truncated.truncated) return { output: truncated.content };
  return saveTruncatedOutput(output, truncated, tempDirs);
}

function resultsOutput(tasks: Array<TaskOutput>): string {
  return tasks
    .map(
      ({ output, error }, index) =>
        `## Task ${index + 1}: ${error === undefined ? "finished" : "failed"}\n\n${output ?? error}`,
    )
    .join("\n\n");
}

interface SubagentRunSettings {
  model: string;
  thinkingLevel: string | undefined;
  signal: AbortSignal;
  tempDirs: Set<string>;
}

async function runSubagentTask(
  task: SubagentTask,
  parentCwd: string,
  settings: SubagentRunSettings,
): Promise<TaskOutput> {
  try {
    settings.signal.throwIfAborted();
    const args = [
      "--mode",
      "text",
      "--print",
      "--no-session",
      "--model",
      settings.model,
      "--thinking",
      settings.thinkingLevel ?? "off",
      "--",
      task.prompt,
    ];
    const cwd = resolve(parentCwd, task.cwd ?? ".");
    const result = await runPi(args, cwd, settings.signal);
    settings.signal.throwIfAborted();
    return await taskOutput(result, settings.tempDirs);
  } catch (error) {
    return { error: String(error) };
  }
}

const subagentParameters = Type.Union([
  Type.Object(
    {
      prompt: Type.String({
        minLength: 1,
        description:
          "Self-contained prompt for the fresh subagent. Start with /skill:<name> when delegating to a specific Pi skill.",
      }),
      cwd: Type.Optional(
        Type.String({
          description: "Working directory; defaults to the parent session cwd",
        }),
      ),
    },
    { additionalProperties: false },
  ),
  Type.Object(
    {
      tasks: Type.Array(
        Type.Object({
          prompt: Type.String({
            minLength: 1,
            description: "Self-contained prompt for this fresh subagent.",
          }),
          cwd: Type.Optional(
            Type.String({
              description:
                "Working directory for this task; defaults to the parent session cwd",
            }),
          ),
        }),
        {
          minItems: 1,
          maxItems: MAX_BATCH_SIZE,
          description:
            "Independent tasks. All child Pi processes run concurrently.",
        },
      ),
    },
    { additionalProperties: false },
  ),
]);

function renderSubagentCall(args: SubagentParams, theme: Theme): Text {
  const taskCount = "tasks" in args ? args.tasks.length : 1;
  const prompt = "tasks" in args ? args.tasks[0].prompt : args.prompt;
  const preview = prompt.length > 100 ? `${prompt.slice(0, 100)}…` : prompt;
  const title = taskCount === 1 ? "subagent" : `subagent batch (${taskCount})`;
  return new Text(
    `${theme.fg("toolTitle", theme.bold(title))}\n${theme.fg("dim", preview)}`,
    0,
    0,
  );
}

export default function (pi: ExtensionAPI) {
  if (Number(process.env.PI_SUBAGENT_DEPTH ?? "0") > 0) return;

  const tempDirs = new Set<string>();
  const session = new AbortController();
  const pending = new Set<Promise<void>>();
  const oneShotResults: Array<CustomMessageEntryDraft> = [];

  // A one-shot run has no next user turn, so deliver results before it exits.
  pi.on("agent_before_settle", async (event, ctx) => {
    if (ctx.mode !== "print" && ctx.mode !== "json") return;
    await Promise.all([...pending]);
    if (!oneShotResults.length) return;
    return {
      entries: [...event.entries, ...oneShotResults.splice(0)],
      continue: true,
    };
  });

  pi.on("session_shutdown", async () => {
    session.abort();
    await Promise.all([...pending]);
    await Promise.all(
      [...tempDirs].map((dir) => rm(dir, { recursive: true, force: true })),
    );
    tempDirs.clear();
  });

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      "Start one fresh-context Pi subagent or a concurrent batch in the background. Returns a launch acknowledgement; results arrive separately.",
    promptSnippet: "Launch fresh-context Pi subagents in the background",
    promptGuidelines: [
      "Use prompt for one task, or tasks for independent tasks. Give each subagent a self-contained prompt.",
      "Continue with work that does not need the results, including asking the user a question. For interviews, keep the subagents' questions as suggestions; only the main agent asks the user. Do not poll, relaunch pending tasks, or report findings before they arrive.",
      "In chat, results enter context without starting a turn. Apply the user's latest answers and do not repeat resolved questions. If you cannot proceed without results, tell the user to send a follow-up once the results are ready.",
      "Use this only if T3 Code orchestration is not available.",
    ],
    parameters: subagentParameters,
    async execute(...[id, params, signal, , ctx]) {
      signal?.throwIfAborted();
      session.signal.throwIfAborted();
      if (!ctx.model)
        throw new Error("Cannot launch a subagent without an active model");

      const tasks = "tasks" in params ? params.tasks : [params];
      const { cwd, mode, ui } = ctx;
      const settings = {
        model: `${ctx.model.provider}/${ctx.model.id}`,
        thinkingLevel: ctx.thinkingLevel,
        signal: session.signal,
        tempDirs,
      };
      const job = runConcurrent(tasks, (task) =>
        runSubagentTask(task, cwd, settings),
      )
        .then((results) => {
          if (session.signal.aborted) return;
          const message = {
            customType: "subagent-results",
            content: `Subagent results for ${id}:\n\n${resultsOutput(results)}`,
            display: true,
          };
          if (mode === "print" || mode === "json") {
            oneShotResults.push({ type: "custom_message", ...message });
            return;
          }
          pi.sendMessage(
            { ...message, display: false },
            { triggerTurn: false },
          );
          if (mode === "tui") ui.notify("Subagent results ready.", "info");
        })
        .catch((error) => {
          if (!session.signal.aborted)
            ui.notify(
              `Could not deliver subagent results: ${String(error)}`,
              "error",
            );
        })
        .finally(() => pending.delete(job));
      pending.add(job);

      return {
        content: [
          {
            type: "text",
            text: `Started ${tasks.length} subagent task(s) in the background (${id}).`,
          },
        ],
        details: undefined,
      };
    },
    renderCall: renderSubagentCall,
  });
}
