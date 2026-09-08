import { join } from "node:path";
import { storagePath } from "./storagePath.ts";

export type ThinkingLevel =
  "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
export type Automation = {
  jobName: string;
  enabled: boolean;
  schedule: string;
  userPrompt: string;
  dailySession?: boolean;
  model: string;
  thinkingLevel: ThinkingLevel;
  canLaunchSubAgents: boolean;
};
export type AutomationConfig = { automations: Automation[] };

export function dailySessionArgs(
  automation: Automation,
  now = new Date(),
): string[] {
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
    join(storagePath(), "sessions"),
  ];
}

export function scriptPath(
  skillPath: string,
  scriptName: string | undefined,
): string | undefined {
  return scriptName && /^[\w.-]+\.ts$/.test(scriptName)
    ? join(skillPath, "scripts", scriptName)
    : undefined;
}
