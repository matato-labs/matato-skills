import { join } from "node:path";
import { storagePath } from "./storagePath.ts";

export const thinkingLevels = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
] as const;

export type ThinkingLevel = (typeof thinkingLevels)[number];
export type Automation = {
  jobName: string;
  enabled: boolean;
  schedule: string;
  userPrompt: string;
  preScriptName?: string;
  postScriptName?: string;
  dailySession?: boolean;
  model: string;
  thinkingLevel: ThinkingLevel;
  canLaunchSubAgents: boolean;
};
export type AutomationConfig = { automations: Automation[] };

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === "object";

export function isThinkingLevel(value: string): value is ThinkingLevel {
  return thinkingLevels.includes(value as ThinkingLevel);
}

const isNonEmptyString = (value: unknown): value is string =>
  typeof value === "string" && value.trim().length > 0;

const isScriptName = (value: unknown): boolean =>
  value === undefined ||
  (typeof value === "string" && /^[\w.-]+\.ts$/.test(value));

export function isAutomation(value: unknown): value is Automation {
  if (!isRecord(value)) return false;
  return (
    isNonEmptyString(value.jobName) &&
    typeof value.enabled === "boolean" &&
    isNonEmptyString(value.schedule) &&
    isNonEmptyString(value.userPrompt) &&
    isNonEmptyString(value.model) &&
    typeof value.canLaunchSubAgents === "boolean" &&
    typeof value.thinkingLevel === "string" &&
    isThinkingLevel(value.thinkingLevel) &&
    isScriptName(value.preScriptName) &&
    isScriptName(value.postScriptName) &&
    (value.dailySession === undefined ||
      typeof value.dailySession === "boolean")
  );
}

export function parseAutomationConfig(value: unknown): AutomationConfig {
  if (!isRecord(value) || !Array.isArray(value.automations))
    throw new Error("Invalid automation config");
  if (!value.automations.every(isAutomation))
    throw new Error("Invalid automation config");
  return { automations: value.automations };
}

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
