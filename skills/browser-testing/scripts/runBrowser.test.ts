import { afterEach, describe, expect, spyOn, test } from "bun:test";
import { existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import * as childProcess from "node:child_process";
import {
  BrowserRun,
  browserCommandPrefix,
  cleanup,
  parseOptions,
} from "./runBrowser.ts";

const directories: Array<string> = [];
const browserRun = (): BrowserRun => {
  const browser = new BrowserRun();
  directories.push(browser.directory);
  return browser;
};

const scenarioArgs = (): Array<string> => {
  const directory = mkdtempSync(join(tmpdir(), "browserRunnerTest"));
  directories.push(directory);
  const scenario = join(directory, "scenario.json");
  writeFileSync(
    scenario,
    JSON.stringify({
      name: "smoke",
      steps: [{ action: "expect", text: "Saved" }],
    }),
  );
  return [
    "--repo",
    directory,
    "--url",
    "http://localhost:5173",
    "--startCommand",
    "bun dev",
    "--scenario",
    scenario,
  ];
};

afterEach(() => {
  for (const directory of directories.splice(0))
    rmSync(directory, { recursive: true, force: true });
});

describe("browser CLI interface", () => {
  test("uses dedicated session commands without a subcommand", () => {
    expect(
      browserCommandPrefix(
        "Usage: playwright-cli -s=<session> <command> [args] [options]",
      ),
    ).toEqual([]);
  });

  test("uses the current Playwright cli subcommand instead of passing session flags to its top level", () => {
    const prefix = browserCommandPrefix(
      "Usage: npx playwright [options] [command]\n  cli                                    run playwright cli commands from terminal",
    );
    expect(prefix).toEqual(["cli"]);
    const browser = new BrowserRun(prefix);
    directories.push(browser.directory);
    const command = spyOn(childProcess, "spawnSync").mockReturnValue({
      pid: 1,
      output: [null, Buffer.from("snapshot saved"), Buffer.from("")],
      stdout: Buffer.from("snapshot saved"),
      stderr: Buffer.from(""),
      status: 0,
      signal: null,
    });
    try {
      browser.command(["snapshot"]);
      expect(command).toHaveBeenCalledWith(
        "playwright-cli",
        ["cli", `-s=${browser.session}`, "snapshot"],
        expect.objectContaining({ cwd: browser.directory }),
      );
    } finally {
      command.mockRestore();
    }
  });

  test("rejects an unrelated CLI before starting an app or browser", () => {
    expect(() => browserCommandPrefix("Usage: unrelated tool")).toThrow(
      "does not expose browser session commands",
    );
  });
});

describe("browser runner options", () => {
  test("preserves local URLs and command values", () => {
    const args = scenarioArgs();
    expect(parseOptions(args)).toMatchObject({
      repo: args[1],
      url: args[3],
      startCommand: "bun dev",
    });
    args[3] = "https://[::1]:5173";
    expect(parseOptions(args).url).toBe(args[3]);
  });

  test("rejects missing flags, remote URLs, protocols, directories, and unverified scenarios", () => {
    expect(() => parseOptions([])).toThrow("Usage:");
    const args = scenarioArgs();
    args[3] = "https://example.com";
    expect(() => parseOptions(args)).toThrow("Only local");
    args[3] = "ftp://localhost";
    expect(() => parseOptions(args)).toThrow("HTTP or HTTPS");
    args[3] = "http://localhost:5173";
    const repo = args[1];
    args[1] = join(repo, "missing");
    expect(() => parseOptions(args)).toThrow("does not exist");
    args[1] = repo;
    writeFileSync(args[7], JSON.stringify({ name: "unverified", steps: [] }));
    expect(() => parseOptions(args)).toThrow("at least one expect");
  });
});

describe("browser runner steps", () => {
  test("takes fresh snapshots around actions and retries visible outcomes", async () => {
    const browser = browserRun();
    const snapshots = spyOn(browser, "snapshot")
      .mockReturnValueOnce('- button "Save" [ref=e9]')
      .mockReturnValueOnce("Saving")
      .mockReturnValueOnce("Saving")
      .mockReturnValueOnce("Saved");
    const commands = spyOn(browser, "command").mockReturnValue("");
    await browser.execute(
      {
        name: "save",
        steps: [
          { action: "click", target: 'button "Save"' },
          { action: "expect", text: "Saved" },
        ],
      },
      new AbortController().signal,
    );
    expect(commands.mock.calls).toEqual([[["click", "e9"]]]);
    expect(snapshots).toHaveBeenCalledTimes(4);
  });

  test("rejects a missing outcome after the deadline", async () => {
    const browser = browserRun();
    spyOn(browser, "snapshot").mockReturnValue("Saving");
    const clock = spyOn(Date, "now")
      .mockReturnValueOnce(0)
      .mockReturnValue(10000);
    try {
      await expect(
        browser.execute(
          { name: "save", steps: [{ action: "expect", text: "Saved" }] },
          new AbortController().signal,
        ),
      ).rejects.toThrow('Visible outcome not found: "Saved"');
    } finally {
      clock.mockRestore();
    }
  });

  test("honors interruption during expectation retries", async () => {
    const browser = browserRun();
    const controller = new AbortController();
    const snapshots = spyOn(browser, "snapshot").mockImplementation(() => {
      controller.abort(new Error("Interrupted"));
      return "Saving";
    });
    await expect(
      browser.execute(
        { name: "save", steps: [{ action: "expect", text: "Saved" }] },
        controller.signal,
      ),
    ).rejects.toThrow("Interrupted");
    expect(snapshots).toHaveBeenCalledTimes(1);
  });
});

describe("browser runner cleanup", () => {
  test("keeps incomplete evidence and deletes only successfully cleaned runs", () => {
    const browser = browserRun();
    expect(() => cleanup(browser.directory)).toThrow("Only completed runs");
    const report = join(browser.directory, "report.json");
    writeFileSync(report, JSON.stringify({ cleanupComplete: false }));
    expect(() => cleanup(browser.directory)).toThrow("Process cleanup failed");
    expect(existsSync(browser.directory)).toBe(true);
    writeFileSync(report, JSON.stringify({ cleanupComplete: true }));
    cleanup(browser.directory);
    expect(existsSync(browser.directory)).toBe(false);
  });

  test("refuses unrelated temporary directories", () => {
    const args = scenarioArgs();
    expect(() => cleanup(args[1])).toThrow("Refusing to delete");
    expect(existsSync(args[1])).toBe(true);
  });
});

describe("browser runner evidence", () => {
  test("collects screenshot, console, each request body, then static requests", () => {
    const browser = browserRun();
    const commands = spyOn(browser, "command").mockImplementation((args) =>
      args[0] === "requests" ? "1. [GET] /api\n2. [POST] /save" : "",
    );
    expect(browser.evidence()).toEqual([]);
    expect(commands.mock.calls.map(([args]) => args)).toEqual([
      ["screenshot", `--filename=${join(browser.directory, "result.png")}`],
      ["console", "error"],
      ["requests"],
      ["request", "1"],
      ["response-body", "1"],
      ["request", "2"],
      ["response-body", "2"],
      ["requests", "--static"],
    ]);
  });

  test("continues other collectors after failure and stops a failed request collection", () => {
    const browser = browserRun();
    const commands = spyOn(browser, "command").mockImplementation((args) => {
      if (args[0] === "screenshot") throw new Error("screenshot failed");
      if (args[0] === "response-body") throw new Error("body failed");
      return args[0] === "requests" ? "1. [GET] /api\n2. [POST] /save" : "";
    });
    expect(browser.evidence()).toEqual(["screenshot failed", "body failed"]);
    expect(commands.mock.calls.map(([args]) => args[0])).toEqual([
      "screenshot",
      "console",
      "requests",
      "request",
      "response-body",
    ]);
  });
});
