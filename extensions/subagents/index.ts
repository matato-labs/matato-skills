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

interface SubagentDetails {
  status: "running" | "finished";
  prompt: string;
  cwd: string;
  output?: string;
}

interface ProcessResult {
  code: number;
  stdout: string;
  stderr: string;
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
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
  args: string[],
  cwd: string,
  signal: AbortSignal | undefined,
  onStarted: () => void,
): Promise<ProcessResult> {
  return new Promise((resolvePromise, reject) => {
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
    let killTimer: NodeJS.Timeout | undefined;

    const abort = () => {
      child.kill("SIGTERM");
      killTimer = setTimeout(() => child.kill("SIGKILL"), 5_000);
    };
    const cleanup = () => {
      if (killTimer) clearTimeout(killTimer);
      signal?.removeEventListener("abort", abort);
    };

    child.once("spawn", onStarted);
    child.stdout.on("data", (chunk) => (stdout += chunk.toString()));
    child.stderr.on("data", (chunk) => (stderr += chunk.toString()));
    child.once("error", (error) => {
      cleanup();
      reject(error);
    });
    child.once("close", (code) => {
      cleanup();
      if (signal?.aborted) return reject(new Error("Subagent was aborted"));
      resolvePromise({ code: code ?? 1, stdout, stderr });
    });

    if (signal?.aborted) abort();
    else signal?.addEventListener("abort", abort, { once: true });
  });
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
      "Launch a fresh-context Pi subagent for a delegated prompt, wait for it to finish, and return its final output. Use only when the user explicitly asks you to run a subagent.",
    promptSnippet: "Launch and await a fresh-context Pi subagent",
    promptGuidelines: [
      "Use subagent only when the user explicitly asks you to run, launch, or delegate to a subagent in their request. Never use it solely because a skill, prompt, or other instruction suggests delegation.",
      "Immediately before calling subagent, write a brief assistant text update saying that you are launching a subagent and will wait for it to finish.",
      "Wait for the subagent result before continuing, then report what it returned or did.",
    ],
    parameters: Type.Object({
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
    }),

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      if (!ctx.model)
        throw new Error("Cannot launch a subagent without an active model");

      const cwd = resolve(ctx.cwd, params.cwd ?? ".");
      const details: SubagentDetails = {
        status: "running",
        prompt: params.prompt,
        cwd,
      };
      const args = [
        "--mode",
        "text",
        "--print",
        "--no-session",
        "--model",
        `${ctx.model.provider}/${ctx.model.id}`,
        "--thinking",
        ctx.thinkingLevel ?? "off",
        "--",
        params.prompt,
      ];

      const result = await runPi(args, cwd, signal, () => {
        onUpdate?.({
          content: [
            {
              type: "text",
              text: "Subagent launched. Waiting for it to finish…",
            },
          ],
          details,
        });
      });

      const output = result.stdout.trim();
      if (result.code !== 0)
        throw new Error(
          result.stderr.trim() ||
            output ||
            `Subagent exited with code ${result.code}`,
        );
      if (!output) throw new Error("Subagent finished without output");

      const truncated = truncateTail(output, {
        maxBytes: DEFAULT_MAX_BYTES,
        maxLines: DEFAULT_MAX_LINES,
      });
      let modelOutput = truncated.content;
      if (truncated.truncated) {
        const dir = await mkdtemp(join(tmpdir(), "pi-subagent-"));
        const file = join(dir, "output.txt");
        tempDirs.add(dir);
        await writeFile(file, output, { encoding: "utf8", mode: 0o600 });
        modelOutput += `\n\n[Output truncated to ${truncated.outputLines} of ${truncated.totalLines} lines (${formatSize(truncated.outputBytes)} of ${formatSize(truncated.totalBytes)}). Full output: ${file}]`;
      }

      return {
        content: [{ type: "text", text: modelOutput }],
        details: {
          ...details,
          status: "finished",
          output: modelOutput,
        } satisfies SubagentDetails,
      };
    },

    renderCall(args, theme) {
      const preview =
        args.prompt.length > 100
          ? `${args.prompt.slice(0, 100)}…`
          : args.prompt;
      return new Text(
        `${theme.fg("toolTitle", theme.bold("subagent"))}\n${theme.fg("dim", preview)}`,
        0,
        0,
      );
    },

    renderResult(result, { expanded, isPartial }, theme) {
      const details = result.details as SubagentDetails | undefined;
      if (isPartial || details?.status === "running") {
        return new Text(
          theme.fg(
            "warning",
            "⏳ Subagent is running. Waiting for it to finish…",
          ),
          0,
          0,
        );
      }

      const output =
        details?.output ??
        (result.content[0]?.type === "text" ? result.content[0].text : "");
      if (!expanded)
        return new Text(theme.fg("success", "✓ Subagent finished"), 0, 0);

      const container = new Container();
      container.addChild(
        new Text(theme.fg("success", "✓ Subagent finished"), 0, 0),
      );
      container.addChild(new Spacer(1));
      container.addChild(new Markdown(output, 0, 0, getMarkdownTheme()));
      return container;
    },
  });
}
