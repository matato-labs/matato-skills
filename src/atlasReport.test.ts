import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(
  new URL("../scripts/atlasReport.sh", import.meta.url),
);
let directory: string;

beforeEach(() => {
  directory = mkdtempSync(join(tmpdir(), "atlasReport"));
  writeFileSync(
    join(directory, "uv"),
    '#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "$ATLAS_ARGS"\nprintf "%s" "$ATLAS_REPORT"\nprintf "%s" "$ATLAS_ERROR" >&2\nexit "$ATLAS_STATUS"\n',
    { mode: 0o755 },
  );
});

afterEach(() => rmSync(directory, { recursive: true, force: true }));

const runReport = (
  report: string,
  args: Array<string> = [],
  env: Record<string, string> = {},
) =>
  Bun.spawnSync(["bash", script, ...args], {
    cwd: directory,
    env: {
      ...process.env,
      PATH: `${directory}${delimiter}${process.env.PATH}`,
      ATLAS_PROJECT: "",
      ATLAS_ARGS: join(directory, "args"),
      ATLAS_REPORT: report,
      ATLAS_ERROR: "",
      ATLAS_STATUS: "0",
      TMPDIR: directory,
      ...env,
    },
  });

describe("Atlas report CLI", () => {
  test("prints a clean report and uses a fresh, database-free analysis", () => {
    const report = '{"findings":[]}';
    const result = runReport(report);
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toBe(report);
    expect(readFileSync(join(directory, "args"), "utf8").split("\n")).toEqual([
      "run",
      "--project",
      "../atlas/atlas",
      "--no-dev",
      "atlas",
      "report",
      "--f",
      ".",
      "--skip-save",
      "--format",
      "json",
      "",
    ]);
  });

  test("passes overridden project and folder paths as single arguments", () => {
    const result = runReport('{"findings":[]}', ["/folder with spaces"], {
      ATLAS_PROJECT: "/atlas project/atlas",
    });
    expect(result.exitCode).toBe(0);
    const args = readFileSync(join(directory, "args"), "utf8").split("\n");
    expect(args[2]).toBe("/atlas project/atlas");
    expect(args[7]).toBe("/folder with spaces");
  });

  test("fails on findings while keeping the report visible", () => {
    const report = JSON.stringify({
      findings: [
        {
          type: "complexity",
          subject: "example",
          files: [{ path: "example.ts", line: 1 }],
          details: ["Cyclomatic complexity is 9 (limit: 8)."],
        },
      ],
    });
    const result = runReport(report);
    expect(result.exitCode).not.toBe(0);
    expect(result.stdout.toString()).toBe(report);
    expect(result.stderr.toString()).toContain("Atlas check failed");
  });

  test.each(["not json", "", "{}", '{"findings":null}', '{"findings":""}'])(
    "fails on invalid or missing findings: %s",
    (report) => expect(runReport(report).exitCode).not.toBe(0),
  );

  test("propagates an Atlas failure even if stdout contains a clean report", () => {
    const result = runReport('{"findings":[]}', [], {
      ATLAS_STATUS: "7",
      ATLAS_ERROR: "Analysis failed",
    });
    expect(result.exitCode).toBe(7);
    expect(result.stderr.toString()).toContain("Analysis failed");
  });

  test("shows help without running Atlas", () => {
    const result = runReport("", ["--help"]);
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toContain("Usage:");
  });

  test("rejects extra arguments", () => {
    expect(runReport("", ["one", "two"]).exitCode).not.toBe(0);
  });
});
