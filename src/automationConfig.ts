import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type { Automation, AutomationConfig } from "./automation.ts";
import { storagePath } from "./storagePath.ts";

type StoredAutomation = Omit<Automation, "canOverlap" | "useSkill"> &
  Partial<Pick<Automation, "canOverlap" | "useSkill">>;
type StoredConfig = { automations: Array<StoredAutomation> };

export const automationConfigPath = (): string =>
  process.env.MATATO_PI_AUTOMATIONS_CONFIG ??
  join(storagePath(), "automations", "config.json");

export async function loadAutomationConfig(
  path = automationConfigPath(),
): Promise<AutomationConfig> {
  try {
    const config = JSON.parse(await readFile(path, "utf8")) as StoredConfig;
    return {
      automations: config.automations.map((automation) => ({
        ...automation,
        canOverlap: automation.canOverlap ?? false,
        useSkill: automation.useSkill ?? true,
      })),
    };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT")
      return { automations: [] };
    throw error;
  }
}
