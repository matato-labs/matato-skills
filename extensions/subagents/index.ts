import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import type {
  ExtensionAPI,
  ToolDefinition,
} from "@earendil-works/pi-coding-agent";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  getMarkdownTheme,
  truncateTail,
} from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

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
  {
    signal,
    onStarted,
  }: {
    signal: AbortSignal | undefined;
    onStarted: () => void;
  },
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

function prepareTasks(
  params: SubagentParams,
  cwd: string,
): {
  batch: boolean;
  tasks: Array<SubagentTaskDetails>;
} {
  if ("tasks" in params)
    return {
      batch: true,
      tasks: params.tasks.map((task) => ({
        status: "queued",
        prompt: task.prompt,
        cwd: resolve(cwd, task.cwd ?? "."),
      })),
    };

  return {
    batch: false,
    tasks: [
      {
        status: "queued",
        prompt: params.prompt,
        cwd: resolve(cwd, params.cwd ?? "."),
      },
    ],
  };
}

interface SubagentRunSettings {
  model: string;
  thinkingLevel: string | undefined;
  signal: AbortSignal | undefined;
  tempDirs: Set<string>;
  update: () => void;
}

function subagentArgs(
  task: SubagentTaskDetails,
  settings: SubagentRunSettings,
): Array<string> {
  return [
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
}

function throwIfAborted(signal: AbortSignal | undefined): void {
  if (signal?.aborted) throw new Error("Subagent was aborted");
}

function completeTask(
  task: SubagentTaskDetails,
  output: TaskOutput,
  update: () => void,
): void {
  if (output.error) {
    task.status = "failed";
    task.error = output.error;
  } else {
    task.status = "finished";
    task.output = output.output;
  }
  update();
}

async function runSubagentTask(
  task: SubagentTaskDetails,
  settings: SubagentRunSettings,
): Promise<SubagentTaskDetails> {
  throwIfAborted(settings.signal);
  const result = await runPi(subagentArgs(task, settings), task.cwd, {
    signal: settings.signal,
    onStarted: () => {
      task.status = "running";
      settings.update();
    },
  });
  throwIfAborted(settings.signal);
  completeTask(
    task,
    await taskOutput(result, settings.tempDirs),
    settings.update,
  );
  return task;
}

function completedOutput(
  batch: boolean,
  tasks: Array<SubagentTaskDetails>,
): string {
  if (batch) return resultsOutput(tasks);
  return tasks[0].output ?? "";
}

function singleTaskError(
  batch: boolean,
  task: SubagentTaskDetails,
): string | undefined {
  if (batch || task.status !== "failed") return;
  return task.error ?? "Subagent failed";
}

function summaryText(
  tasks: Array<SubagentTaskDetails>,
  failed: number,
): string {
  if (failed)
    return `✓ ${tasks.length - failed}/${tasks.length} subagents finished; ${failed} failed`;
  return `✓ ${tasks.length || 1} subagent${tasks.length === 1 ? "" : "s"} finished`;
}

function displayedOutput(
  details: SubagentDetails | undefined,
  tasks: Array<SubagentTaskDetails>,
  fallback: string,
): string {
  if (details && tasks.length > 1) return resultsOutput(tasks);
  return tasks[0]?.output ?? fallback;
}

function resultTasks(
  details: SubagentDetails | undefined,
): Array<SubagentTaskDetails> {
  return details?.tasks ?? [];
}

function isInProgress(
  isPartial: boolean,
  details: SubagentDetails | undefined,
): boolean {
  return isPartial || details?.status === "running";
}

function resultColor(failed: number): "error" | "success" {
  return failed ? "error" : "success";
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

type SubagentExecute = ToolDefinition<
  typeof subagentParameters,
  SubagentDetails
>["execute"];

function createSubagentExecute(tempDirs: Set<string>): SubagentExecute {
  return async (
    ...[, params, signal, onUpdate, ctx]: Parameters<SubagentExecute>
  ) => {
    if (!ctx.model)
      throw new Error("Cannot launch a subagent without an active model");

    const prepared = prepareTasks(params, ctx.cwd);
    const details: SubagentDetails = {
      status: "running",
      tasks: prepared.tasks,
    };
    const update = () =>
      onUpdate?.({
        content: [{ type: "text", text: progressText(prepared.tasks) }],
        details,
      });
    const settings: SubagentRunSettings = {
      model: `${ctx.model.provider}/${ctx.model.id}`,
      thinkingLevel: ctx.thinkingLevel,
      signal,
      tempDirs,
      update,
    };
    const completedTasks = await runConcurrent(prepared.tasks, (task) =>
      runSubagentTask(task, settings),
    );

    details.status = "finished";
    const error = singleTaskError(prepared.batch, completedTasks[0]);
    if (error) throw new Error(error);
    return {
      content: [
        {
          type: "text",
          text: completedOutput(prepared.batch, completedTasks),
        },
      ],
      details,
    };
  };
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
      "Launch one fresh-context Pi subagent or a batch of independent subagents concurrently, wait for every task, and return each outcome.",
    promptSnippet: "Launch and await fresh-context Pi subagents",
    promptGuidelines: [
      "Use prompt for one task, or tasks for independent tasks. A batch runs all subagents concurrently and reports every task outcome.",
      "Immediately before calling subagent, write a brief assistant text update saying that you are launching the subagent or subagents and will wait for them to finish.",
      "Wait for all requested subagent results before continuing, then report what each returned or did.",
    ],
    parameters: subagentParameters,
    execute: createSubagentExecute(tempDirs),

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
      if (isInProgress(isPartial, details))
        return new Text(
          theme.fg("warning", progressText(resultTasks(details))),
          0,
          0,
        );

      const tasks = resultTasks(details);
      const failed = tasks.filter((task) => task.status === "failed").length;
      const summary = summaryText(tasks, failed);
      const color = resultColor(failed);
      if (!expanded) return new Text(theme.fg(color, summary), 0, 0);

      const firstContent = result.content[0];
      const fallback = firstContent?.type === "text" ? firstContent.text : "";
      const container = new Container();
      container.addChild(new Text(theme.fg(color, summary), 0, 0));
      container.addChild(new Spacer(1));
      container.addChild(
        new Markdown(
          displayedOutput(details, tasks, fallback),
          0,
          0,
          getMarkdownTheme(),
        ),
      );
      return container;
    },
  });
}
