import { join } from "node:path";

export type ThinkingLevel =
  "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
export type Automation = {
  botId?: string;
  jobName: string;
  enabled: boolean;
  schedule: string;
  userPrompt: string;
  dailySession?: boolean;
  canOverlap: boolean;
  model: string;
  thinkingLevel: ThinkingLevel;
  canLaunchSubAgents: boolean;
  monitor?: boolean;
  useSkill: boolean;
};
export type AutomationConfig = { automations: Automation[] };

export function scriptPath(
  skillPath: string,
  scriptName: string | undefined,
): string | undefined {
  return scriptName && /^[\w.-]+\.ts$/.test(scriptName)
    ? join(skillPath, "scripts", scriptName)
    : undefined;
}
