import { describe, expect, test } from "bun:test";
import { homedir } from "node:os";
import { scriptPath } from "./automation.ts";
import { databasePath, storagePath } from "./storagePath.ts";

describe("automation configuration", () => {
  test("uses the package storage directory and database name by default", () => {
    const original = process.env.MATATO_SKILLS_CONFIG;
    delete process.env.MATATO_SKILLS_CONFIG;
    try {
      expect(storagePath()).toBe(`${homedir()}/.config/matato-skills`);
      expect(databasePath()).toBe(
        `${homedir()}/.config/matato-skills/matato-skills.sqlite3`,
      );
    } finally {
      if (original === undefined) delete process.env.MATATO_SKILLS_CONFIG;
      else process.env.MATATO_SKILLS_CONFIG = original;
    }
  });

  test("expands a home-relative MATATO_SKILLS_CONFIG", () => {
    const original = process.env.MATATO_SKILLS_CONFIG;
    process.env.MATATO_SKILLS_CONFIG = "~/.config/matato-skills";
    try {
      expect(storagePath()).toBe(`${homedir()}/.config/matato-skills`);
    } finally {
      if (original === undefined) delete process.env.MATATO_SKILLS_CONFIG;
      else process.env.MATATO_SKILLS_CONFIG = original;
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
