import { stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { Automation } from "../src/automation.ts";
import { storagePath } from "../src/storagePath.ts";
import { createPiOutput } from "./piOutput.ts";
import { execute, type Execute } from "./process.ts";

const packageSkillsPath = fileURLToPath(new URL("../skills/", import.meta.url));

export async function resolveSkillPath(
  jobName: string,
  home = homedir(),
  packageSkills = packageSkillsPath,
): Promise<string> {
  if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(jobName))
    throw new Error(`Invalid skill name: ${jobName}`);
  for (const path of [
    join(home, ".pi", "agent", "skills", jobName),
    join(packageSkills, jobName),
  ]) {
    try {
      if ((await stat(path)).isDirectory()) return path;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }
  throw new Error(`Skill not found: ${jobName}`);
}

export function dailySessionArgs(
  automation: Automation,
  configPath = storagePath(),
  now = new Date(),
): Array<string> {
  if (!automation.dailySession) return [];
  const date = [
    now.getFullYear(),
    String(now.getMonth() + 1).padStart(2, "0"),
    String(now.getDate()).padStart(2, "0"),
  ].join("-");
  return [
    "--session-id",
    `${automation.jobName}-${date}`,
    "--session-dir",
    join(configPath, "sessions"),
  ];
}

export type RunnerOptions = {
  execute?: Execute;
  resolveSkill?: (jobName: string) => Promise<string>;
  cwd?: string;
  configPath?: string;
  env?: NodeJS.ProcessEnv;
  now?: () => Date;
  signal?: AbortSignal;
};

async function runScript(
  skillPath: string,
  name: "preScript.ts" | "postScript.ts",
  {
    run,
    env,
    signal,
  }: {
    run: Execute;
    env: NodeJS.ProcessEnv;
    signal: AbortSignal | undefined;
  },
): Promise<string | null> {
  const path = join(skillPath, "scripts", name);
  try {
    await stat(path);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw error;
  }
  return (await run("bun", [path], { cwd: skillPath, env, signal })).trim();
}

function automationPrompt(
  automation: Automation,
  skillPath: string | undefined,
  preScriptOutput: string | null,
): string {
  const userPrompt = [
    automation.userPrompt,
    ...(preScriptOutput === null
      ? []
      : ["", "Pre-script output:", preScriptOutput]),
  ].join("\n");
  return skillPath ? `/skill:${automation.jobName} ${userPrompt}` : userPrompt;
}

export async function runAutomation(
  automation: Automation,
  options: RunnerOptions = {},
): Promise<"completed" | "skipped"> {
  if (automation.monitor)
    throw new Error("monitor is not supported by the standalone worker");
  const run = options.execute ?? execute;
  const configPath = options.configPath ?? storagePath();
  const env: NodeJS.ProcessEnv = {
    ...process.env,
    ...options.env,
    MATATO_SKILLS_CONFIG: configPath,
  };
  if (!automation.canLaunchSubAgents) env.PI_SUBAGENT_DEPTH = "1";
  const skillPath = automation.useSkill
    ? await (options.resolveSkill ?? resolveSkillPath)(automation.jobName)
    : undefined;
  const preScriptOutput = skillPath
    ? await runScript(skillPath, "preScript.ts", {
        run,
        env,
        signal: options.signal,
      })
    : null;
  if (preScriptOutput === "") return "skipped";
  const prompt = automationPrompt(automation, skillPath, preScriptOutput);
  const output = createPiOutput();
  await run(
    "pi",
    [
      "--mode",
      "json",
      "--print",
      "--approve",
      "--name",
      automation.jobName,
      "--model",
      automation.model,
      "--thinking",
      automation.thinkingLevel,
      ...(skillPath ? ["--no-skills", "--skill", skillPath] : []),
      ...dailySessionArgs(
        automation,
        configPath,
        (options.now ?? (() => new Date()))(),
      ),
      "--",
      prompt,
    ],
    {
      cwd: options.cwd ?? process.cwd(),
      env,
      signal: options.signal,
      onStdout: output.write,
    },
  );
  output.verify();
  if (skillPath)
    await runScript(skillPath, "postScript.ts", {
      run,
      env,
      signal: options.signal,
    });
  return "completed";
}
