import { describe, expect, test } from "bun:test";
import { homedir } from "node:os";
import { scriptPath } from "./automation.ts";
import { storagePath } from "./storagePath.ts";

describe("automation configuration", () => {
  test("expands a home-relative MATATO_PI_CONFIG", () => {
    const original = process.env.MATATO_PI_CONFIG;
    process.env.MATATO_PI_CONFIG = "~/.config/matato-pi";
    try {
      expect(storagePath()).toBe(`${homedir()}/.config/matato-pi`);
    } finally {
      if (original === undefined) delete process.env.MATATO_PI_CONFIG;
      else process.env.MATATO_PI_CONFIG = original;
    }
  });

  test("resolves configured scripts and skips jobs without one", () => {
    expect(scriptPath("/skills/daily-review", "preScript.ts")).toBe(
      "/skills/daily-review/scripts/preScript.ts",
    );
    expect(scriptPath("/skills/daily-review", undefined)).toBeUndefined();
    expect(scriptPath("/skills/daily-review", "../secret.ts")).toBeUndefined();
  });
});
