import { describe, expect, test } from "bun:test";
import {
  dailySessionArgs,
  parseAutomationConfig,
  scriptPath,
  type Automation,
} from "./automation.ts";

const automation = {
  jobName: "daily-review",
  enabled: true,
  schedule: "0 9 * * *",
  userPrompt: "Review the daily changes.",
  model: "openai/gpt-5",
  thinkingLevel: "low",
  canLaunchSubAgents: false,
} satisfies Automation;

describe("automation configuration", () => {
  test("keeps optional script and daily-session settings", () => {
    expect(
      parseAutomationConfig({
        automations: [
          {
            ...automation,
            preScriptName: "pre-script.ts",
            postScriptName: "post-script.ts",
            dailySession: true,
            skipIfPreScriptEmpty: true,
          },
        ],
      }),
    ).toEqual({
      automations: [
        {
          ...automation,
          preScriptName: "pre-script.ts",
          postScriptName: "post-script.ts",
          dailySession: true,
          skipIfPreScriptEmpty: true,
        },
      ],
    });
  });

  test("creates a stable per-day session only when enabled", () => {
    expect(dailySessionArgs(automation, new Date(2026, 8, 7))).toEqual([]);
    expect(
      dailySessionArgs(
        { ...automation, dailySession: true },
        new Date(2026, 8, 7),
      ).slice(0, 2),
    ).toEqual(["--session-id", "daily-review-2026-09-07"]);
  });

  test("honors MATATO_PI_STORAGE_PATH for the session directory", () => {
    const original = process.env.MATATO_PI_STORAGE_PATH;
    process.env.MATATO_PI_STORAGE_PATH = "/tmp/matato-pi-test-storage";
    try {
      expect(
        dailySessionArgs({ ...automation, dailySession: true }).slice(2),
      ).toEqual(["--session-dir", "/tmp/matato-pi-test-storage/sessions"]);
    } finally {
      if (original === undefined) delete process.env.MATATO_PI_STORAGE_PATH;
      else process.env.MATATO_PI_STORAGE_PATH = original;
    }
  });

  test("requires an automation array", () => {
    for (const value of [null, {}, { automations: {} }])
      expect(() => parseAutomationConfig(value)).toThrow(
        "Invalid automation config",
      );
  });

  test("rejects invalid automation fields", () => {
    for (const invalid of [
      { jobName: 1 },
      { enabled: "true" },
      { schedule: " " },
      { userPrompt: " " },
      { model: " " },
      { thinkingLevel: "invalid" },
      { canLaunchSubAgents: "false" },
      { preScriptName: "../secret.ts" },
      { postScriptName: "../secret.ts" },
      { dailySession: "true" },
      { skipIfPreScriptEmpty: "true" },
    ])
      expect(() =>
        parseAutomationConfig({ automations: [{ ...automation, ...invalid }] }),
      ).toThrow("Invalid automation config");
  });

  test("resolves configured scripts and skips jobs without one", () => {
    expect(scriptPath("/skills/daily-review", "pre-script.ts")).toBe(
      "/skills/daily-review/scripts/pre-script.ts",
    );
    expect(scriptPath("/skills/daily-review", undefined)).toBeUndefined();
    expect(scriptPath("/skills/daily-review", "../secret.ts")).toBeUndefined();
  });
});
