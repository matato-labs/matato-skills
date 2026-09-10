import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  getMarkdownTheme,
  truncateTail,
} from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const MAX_CONCURRENT_SUBAGENTS = 4;
const MAX_BATCH_SIZE = 16;

interface SubagentTask {
  prompt: string;
  cwd?: string;
}

interface SubagentTaskDetails {
  status: "queued" | "running" | "finished" | "failed";
  prompt: string;
  cwd: string;
  output?: string;
  error?: string;
}

interface SubagentDetails {
  status: "running" | "finished";
  tasks: Array<SubagentTaskDetails>;
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
  signal: AbortSignal | undefined,
  onStarted: () => void,
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
      signal?.removeEventListener("abort", abort);
    };

    child.once("spawn", onStarted);
    child.stdout.on("data", (chunk: Buffer) => (stdout += chunk.toString()));
    child.stderr.on("data", (chunk: Buffer) => (stderr += chunk.toString()));
    child.once("error", (error: Error) =>
      finish({ code: 1, stdout, stderr: error.message }),
    );
    child.once("close", (code) => finish({ code: code ?? 1, stdout, stderr }));

    if (signal?.aborted) abort();
    else signal?.addEventListener("abort", abort, { once: true });
  });
}

export async function runBounded<T, R>(
  tasks: Array<T>,
  limit: number,
  run: (task: T, index: number) => Promise<R>,
): Promise<Array<R>> {
  const results: Array<R> = new Array(tasks.length);
  let nextIndex = 0;

  const worker = async (): Promise<void> => {
    while (nextIndex < tasks.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await run(tasks[index], index);
    }
  };

  await Promise.all(
    Array.from({ length: Math.min(limit, tasks.length) }, () => worker()),
  );
  return results;
}

function taskOutput(
  result: ProcessResult,
  tempDirs: Set<string>,
): Promise<TaskOutput> {
  const output = result.stdout.trim();
  if (result.code !== 0)
    return Promise.resolve({
      error:
        result.stderr.trim() ||
        output ||
        `Subagent exited with code ${result.code}`,
    });
  if (!output)
    return Promise.resolve({ error: "Subagent finished without output" });

  const truncated = truncateTail(output, {
    maxBytes: DEFAULT_MAX_BYTES,
    maxLines: DEFAULT_MAX_LINES,
  });
  if (!truncated.truncated)
    return Promise.resolve({ output: truncated.content });

  return mkdtemp(join(tmpdir(), "pi-subagent-")).then(async (dir) => {
    const file = join(dir, "output.txt");
    tempDirs.add(dir);
    await writeFile(file, output, { encoding: "utf8", mode: 0o600 });
    return {
      output: `${truncated.content}\n\n[Output truncated to ${truncated.outputLines} of ${truncated.totalLines} lines (${formatSize(truncated.outputBytes)} of ${formatSize(truncated.totalBytes)}). Full output: ${file}]`,
    };
  });
}

function resultsOutput(tasks: Array<SubagentTaskDetails>): string {
  return tasks
    .map(
      (task, index) =>
        `## Task ${index + 1}: ${task.status}\n\n${task.output ?? task.error ?? "No result"}`,
    )
    .join("\n\n");
}

function progressText(tasks: Array<SubagentTaskDetails>): string {
  const completed = tasks.filter(
    (task) => task.status === "finished" || task.status === "failed",
  ).length;
  const running = tasks.filter((task) => task.status === "running").length;
  return `Subagent batch: ${completed}/${tasks.length} finished, ${running} running.`;
}

export default function (pi: ExtensionAPI) {
  if (Number(process.env.PI_SUBAGENT_DEPTH ?? "0") > 0) return;

  const tempDirs = new Set<string>();
  pi.on("session_shutdown", async () => {
    await Promise.all(
      [...tempDirs].map((dir) => rm(dir, { recursive: true, force: true })),
    );
    tempDirs.clear();
  });

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      "Launch one fresh-context Pi subagent or a bounded batch of independent subagents, wait for every task, and return each outcome. Use only when the user explicitly asks you to run a subagent.",
    promptSnippet: "Launch and await fresh-context Pi subagents",
    promptGuidelines: [
      "Use subagent only when the user explicitly asks you to run, launch, or delegate to a subagent in their request. Never use it solely because a skill, prompt, or other instruction suggests delegation.",
      "Use prompt for one task, or tasks for independent tasks. A batch runs at most four subagents concurrently and reports every task outcome.",
      "Immediately before calling subagent, write a brief assistant text update saying that you are launching the subagent or subagents and will wait for them to finish.",
      "Wait for all requested subagent results before continuing, then report what each returned or did.",
    ],
    parameters: Type.Union([
      Type.Object(
        {
          prompt: Type.String({
            minLength: 1,
            description:
              "Self-contained prompt for the fresh subagent. Start with /skill:<name> when delegating to a specific Pi skill.",
          }),
          cwd: Type.Optional(
            Type.String({
              description:
                "Working directory; defaults to the parent session cwd",
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
                "Independent tasks. At most four child Pi processes run concurrently.",
            },
          ),
        },
        { additionalProperties: false },
      ),
    ]),

    async execute(_toolCallId, params: SubagentParams, signal, onUpdate, ctx) {
      if (!ctx.model)
        throw new Error("Cannot launch a subagent without an active model");

      const model = ctx.model;
      const batch = "tasks" in params;
      const requestedTasks = batch ? params.tasks : [params];
      const tasks: Array<SubagentTaskDetails> = requestedTasks.map((task) => ({
        status: "queued",
        prompt: task.prompt,
        cwd: resolve(ctx.cwd, task.cwd ?? "."),
      }));
      const details: SubagentDetails = { status: "running", tasks };
      const update = () =>
        onUpdate?.({
          content: [{ type: "text", text: progressText(tasks) }],
          details,
        });

      const completedTasks = await runBounded(
        tasks,
        batch ? MAX_CONCURRENT_SUBAGENTS : 1,
        async (task) => {
          const args = [
            "--mode",
            "text",
            "--print",
            "--no-session",
            "--model",
            `${model.provider}/${model.id}`,
            "--thinking",
            ctx.thinkingLevel ?? "off",
            "--",
            task.prompt,
          ];
          const result = await runPi(args, task.cwd, signal, () => {
            task.status = "running";
            update();
          });
          if (signal?.aborted) throw new Error("Subagent was aborted");

          const output = await taskOutput(result, tempDirs);
          if (output.error) {
            task.status = "failed";
            task.error = output.error;
          } else {
            task.status = "finished";
            task.output = output.output;
          }
          update();
          return task;
        },
      );

      details.status = "finished";
      if (!batch && completedTasks[0].status === "failed")
        throw new Error(completedTasks[0].error ?? "Subagent failed");

      const output = batch
        ? resultsOutput(completedTasks)
        : (completedTasks[0].output ?? "");
      return {
        content: [{ type: "text", text: output }],
        details,
      };
    },

    renderCall(args: SubagentParams, theme) {
      const taskCount = "tasks" in args ? args.tasks.length : 1;
      const prompt = "tasks" in args ? args.tasks[0].prompt : args.prompt;
      const preview = prompt.length > 100 ? `${prompt.slice(0, 100)}…` : prompt;
      const title =
        taskCount === 1 ? "subagent" : `subagent batch (${taskCount})`;
      return new Text(
        `${theme.fg("toolTitle", theme.bold(title))}\n${theme.fg("dim", preview)}`,
        0,
        0,
      );
    },

    renderResult(result, { expanded, isPartial }, theme) {
      const details = result.details as SubagentDetails | undefined;
      if (isPartial || details?.status === "running")
        return new Text(
          theme.fg("warning", progressText(details?.tasks ?? [])),
          0,
          0,
        );

      const tasks = details?.tasks ?? [];
      const failed = tasks.filter((task) => task.status === "failed").length;
      const summary = failed
        ? `✓ ${tasks.length - failed}/${tasks.length} subagents finished; ${failed} failed`
        : `✓ ${tasks.length || 1} subagent${tasks.length === 1 ? "" : "s"} finished`;
      if (!expanded)
        return new Text(theme.fg(failed ? "error" : "success", summary), 0, 0);

      const output =
        details && tasks.length > 1
          ? resultsOutput(tasks)
          : (details?.tasks[0]?.output ??
            (result.content[0]?.type === "text" ? result.content[0].text : ""));
      const container = new Container();
      container.addChild(
        new Text(theme.fg(failed ? "error" : "success", summary), 0, 0),
      );
      container.addChild(new Spacer(1));
      container.addChild(new Markdown(output, 0, 0, getMarkdownTheme()));
      return container;
    },
  });
}
