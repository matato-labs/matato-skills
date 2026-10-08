import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { Automation } from "./automation.ts";
import {
  automationConfigPath,
  loadAutomationConfig,
} from "./automationConfig.ts";

const originalConfig = process.env.MATATO_PI_CONFIG;
const originalAutomations = process.env.MATATO_PI_AUTOMATIONS_CONFIG;
const directories: Array<string> = [];

afterEach(async () => {
  if (originalConfig === undefined) delete process.env.MATATO_PI_CONFIG;
  else process.env.MATATO_PI_CONFIG = originalConfig;
  if (originalAutomations === undefined)
    delete process.env.MATATO_PI_AUTOMATIONS_CONFIG;
  else process.env.MATATO_PI_AUTOMATIONS_CONFIG = originalAutomations;
  await Promise.all(
    directories.splice(0).map((path) => rm(path, { recursive: true })),
  );
});

async function temporaryConfig(): Promise<string> {
  const directory = await mkdtemp(join(tmpdir(), "matatoAutomations"));
  directories.push(directory);
  return join(directory, "config.json");
}

describe("standalone automation configuration", () => {
  test("uses the repository config independently of storage and working directory", () => {
    delete process.env.MATATO_PI_AUTOMATIONS_CONFIG;
    process.env.MATATO_PI_CONFIG = "/customConfig";
    const originalDirectory = process.cwd();
    try {
      process.chdir(tmpdir());
      expect(automationConfigPath()).toBe(
        fileURLToPath(new URL("../config/config.json", import.meta.url)),
      );
    } finally {
      process.chdir(originalDirectory);
    }
  });

  test("supports an explicit automation config path", () => {
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = "/customAutomations.json";
    expect(automationConfigPath()).toBe("/customAutomations.json");
  });

  test("missing config returns no jobs", async () => {
    expect(await loadAutomationConfig(await temporaryConfig())).toEqual({
      automations: [],
    });
  });

  test("preserves jobs and defaults fields absent in historical configs", async () => {
    const path = await temporaryConfig();
    const legacyJob: Omit<Automation, "canOverlap" | "useSkill"> = {
      jobName: "heartbeat",
      enabled: false,
      schedule: "0 9 * * *",
      userPrompt: "Review work",
      model: "configuredModel",
      thinkingLevel: "low",
      canLaunchSubAgents: false,
    };
    const currentJob = {
      ...legacyJob,
      jobName: "review",
      enabled: true,
      canOverlap: true,
      useSkill: false,
    };
    await writeFile(
      path,
      JSON.stringify({ automations: [legacyJob, currentJob] }),
    );
    expect(await loadAutomationConfig(path)).toEqual({
      automations: [
        { ...legacyJob, canOverlap: false, useSkill: true },
        currentJob,
      ],
    });
  });

  test("loads only automation settings from a legacy mixed config", async () => {
    const path = await temporaryConfig();
    await writeFile(
      path,
      JSON.stringify({ automations: [], unrelatedSetting: "ignored" }),
    );
    expect(await loadAutomationConfig(path)).toEqual({ automations: [] });
  });

  test("invalid JSON is not silently treated as empty configuration", async () => {
    const path = await temporaryConfig();
    await writeFile(path, "{");
    await expect(loadAutomationConfig(path)).rejects.toThrow();
  });
});
