import { describe, expect, test } from "bun:test";
import {
  parseAutomationConfig,
  preScriptPath,
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
  test("keeps an optional pre-script filename", () => {
    expect(
      parseAutomationConfig({
        automations: [{ ...automation, preScriptName: "pre-script.ts" }],
      }),
    ).toEqual({
      automations: [{ ...automation, preScriptName: "pre-script.ts" }],
    });
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
    ])
      expect(() =>
        parseAutomationConfig({ automations: [{ ...automation, ...invalid }] }),
      ).toThrow("Invalid automation config");
  });

  test("resolves configured pre-scripts and skips jobs without one", () => {
    expect(preScriptPath("/skills/daily-review", "pre-script.ts")).toBe(
      "/skills/daily-review/scripts/pre-script.ts",
    );
    expect(preScriptPath("/skills/daily-review", undefined)).toBeUndefined();
    expect(
      preScriptPath("/skills/daily-review", "../secret.ts"),
    ).toBeUndefined();
  });
});
