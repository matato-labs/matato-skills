import { spawn } from "node:child_process";
import { constants } from "node:fs";
import { access, readFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { StringDecoder } from "node:string_decoder";
import { Cron } from "croner";
import {
  dailySessionArgs,
  scriptPath,
  type Automation,
  type AutomationConfig,
} from "../src/automation.ts";

type RpcMessage = { type?: string; success?: boolean; error?: string };

const configPath =
  process.env.MATATO_PI_AUTOMATIONS_CONFIG ??
  join(homedir(), ".config", "matato-pi", "automations", "config.json");
const schedules = new Map<string, Cron>();
let configStamp = "";
let stopping = false;

const log = (message: string): void =>
  console.log(`[matato-pi-worker] ${message}`);

async function loadAutomations(): Promise<Array<Automation>> {
  try {
    const config = JSON.parse(
      await readFile(configPath, "utf8"),
    ) as AutomationConfig;
    return config.automations.filter((automation) => automation.enabled);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return [];
    throw error;
  }
}

async function isDirectory(path: string): Promise<boolean> {
  try {
    return (await stat(path)).isDirectory();
  } catch {
    return false;
  }
}

async function resolveSkillPath(jobName: string): Promise<string> {
  const paths = [
    join(homedir(), ".pi", "agent", "skills", jobName),
    join(process.cwd(), "skills", jobName),
  ];
  for (const path of paths) {
    if (await isDirectory(path)) return path;
  }
  throw new Error(`Skill not found: ${jobName}`);
}

async function runScript(
  skillPath: string,
  scriptName: string | undefined,
): Promise<string | null> {
  const resolvedPath = scriptPath(skillPath, scriptName);
  if (!resolvedPath) return null;
  try {
    await access(resolvedPath, constants.X_OK);
  } catch {
    try {
      await access(resolvedPath, constants.F_OK);
    } catch {
      return null;
    }
  }

  return new Promise((resolve, reject) => {
    const child = spawn("bun", [resolvedPath], {
      cwd: skillPath,
      env: {
        ...process.env,
        STORAGE_PATH:
          process.env.STORAGE_PATH ?? join(homedir(), ".config", "matato-pi"),
      },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk: Buffer) => (stdout += chunk));
    child.stderr.on("data", (chunk: Buffer) => (stderr += chunk));
    child.once("error", reject);
    child.once("close", (code) => {
      if (code === 0) resolve(stdout.trim());
      else
        reject(new Error(stderr.trim() || `Script exited with code ${code}`));
    });
  });
}

function createPrompt(
  automation: Automation,
  preScriptOutput: string | null,
): string {
  const prompt = [`/skill:${automation.jobName}`, "", automation.userPrompt];
  if (preScriptOutput !== null)
    prompt.push("", "Pre-script output:", preScriptOutput);
  return prompt.join("\n");
}

function runPiRpc(
  automation: Automation,
  skillPath: string,
  prompt: string,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(
      "pi",
      [
        "--mode",
        "rpc",
        "--name",
        automation.jobName,
        "--approve",
        "--model",
        automation.model,
        "--thinking",
        automation.thinkingLevel,
        "--skill",
        skillPath,
        ...dailySessionArgs(automation),
      ],
      { cwd: process.cwd(), stdio: ["pipe", "pipe", "pipe"] },
    );
    const decoder = new StringDecoder("utf8");
    let buffer = "";
    let stderr = "";
    let settled = false;
    let failed = false;

    const fail = (error: Error): void => {
      if (failed || settled) return;
      failed = true;
      child.kill("SIGTERM");
      reject(error);
    };
    const handleLine = (line: string): void => {
      if (!line) return;
      let message: RpcMessage;
      try {
        message = JSON.parse(line) as RpcMessage;
      } catch {
        fail(new Error(`Invalid Pi RPC message: ${line}`));
        return;
      }
      if (message.type === "response" && message.success === false) {
        fail(new Error(message.error ?? "Pi rejected the scheduled prompt"));
      } else if (message.type === "agent_settled") {
        settled = true;
        child.stdin.end();
        child.kill("SIGTERM");
        resolve();
      }
    };

    child.stdout.on("data", (chunk: Buffer) => {
      buffer += decoder.write(chunk);
      let newline = buffer.indexOf("\n");
      while (newline !== -1) {
        const line = buffer.slice(0, newline).replace(/\r$/, "");
        buffer = buffer.slice(newline + 1);
        handleLine(line);
        newline = buffer.indexOf("\n");
      }
    });
    child.stderr.on("data", (chunk: Buffer) => (stderr += chunk));
    child.once("error", fail);
    child.once("close", (code) => {
      if (!settled && !failed)
        fail(new Error(stderr.trim() || `Pi exited with code ${code}`));
    });
    child.stdin.write(
      `${JSON.stringify({ id: automation.jobName, type: "prompt", message: prompt })}\n`,
    );
  });
}

async function runAutomation(automation: Automation): Promise<void> {
  const skillPath = await resolveSkillPath(automation.jobName);
  const preScriptOutput = await runScript(skillPath, "preScript.ts");
  if (preScriptOutput === "") {
    log(`Job skipped: ${automation.jobName} (pre-script produced no output)`);
    return;
  }
  await runPiRpc(
    automation,
    skillPath,
    createPrompt(automation, preScriptOutput),
  );
  await runScript(skillPath, "postScript.ts");
  log(`Job completed: ${automation.jobName}`);
}

function stopSchedules(): void {
  for (const schedule of schedules.values()) schedule.stop();
  schedules.clear();
}

async function reload(): Promise<void> {
  const automations = await loadAutomations();
  const nextSchedules = new Map<string, Cron>();
  try {
    for (const automation of automations) {
      nextSchedules.set(
        automation.jobName,
        new Cron(
          automation.schedule,
          { name: automation.jobName, protect: true },
          () =>
            runAutomation(automation).catch((error: Error) =>
              console.error(
                `[matato-pi-worker] Job failed: ${automation.jobName}`,
                error,
              ),
            ),
        ),
      );
    }
  } catch (error) {
    for (const schedule of nextSchedules.values()) schedule.stop();
    throw error;
  }

  stopSchedules();
  for (const [name, schedule] of nextSchedules) schedules.set(name, schedule);
  log(`Scheduled: ${[...schedules.keys()].join(", ") || "none"}`);
}

async function configFileStamp(): Promise<string> {
  try {
    const entry = await stat(configPath);
    return `${entry.mtimeMs}:${entry.size}`;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return "missing";
    throw error;
  }
}

async function sync(): Promise<void> {
  const nextStamp = await configFileStamp();
  if (nextStamp === configStamp) return;
  await reload();
  configStamp = nextStamp;
}

async function main(): Promise<void> {
  await sync();
  setInterval(() => {
    void sync().catch((error: Error) =>
      console.error("[matato-pi-worker] Could not reload automations", error),
    );
  }, 5_000).unref();
  log(`Watching ${configPath}`);
}

function shutdown(): void {
  if (stopping) return;
  stopping = true;
  stopSchedules();
  log("Stopped");
}

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
void main().catch((error: Error) => {
  console.error("[matato-pi-worker] Could not start", error);
  process.exitCode = 1;
});
