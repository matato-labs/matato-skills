import {
  closeSync,
  existsSync,
  mkdtempSync,
  openSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { readFlagValue } from "../../../src/cli.ts";
import {
  readScenario,
  stepArguments,
  type BrowserScenario,
} from "./browserScenario.ts";

const pause = (milliseconds: number): Promise<void> =>
  new Promise((done) => setTimeout(done, milliseconds));
const errorMessage = (error: Error | string): string =>
  error instanceof Error ? error.message : error;

type RunOptions = {
  repo: string;
  url: string;
  startCommand: string;
  scenario: BrowserScenario;
};

const parseOptions = (args: Array<string>): RunOptions => {
  const repo = readFlagValue(args, "repo");
  const url = readFlagValue(args, "url");
  const startCommand = readFlagValue(args, "startCommand");
  const scenarioPath = readFlagValue(args, "scenario");
  if (!repo || !url || !startCommand || !scenarioPath)
    throw new Error(
      "Usage: bun runBrowser.ts --repo PATH --url URL --startCommand COMMAND --scenario FILE",
    );
  if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname))
    throw new Error("Only local application URLs are allowed.");
  if (!["http:", "https:"].includes(new URL(url).protocol))
    throw new Error("The application URL must use HTTP or HTTPS.");
  if (!existsSync(repo))
    throw new Error("The repository directory does not exist.");
  const scenario = readScenario(resolve(scenarioPath));
  if (!scenario.steps.some((step) => step.action === "expect"))
    throw new Error(
      "Include at least one expect step to verify a visible outcome.",
    );
  return { repo: resolve(repo), url, startCommand, scenario };
};

const responds = async (
  url: string,
  requireHealthy = false,
): Promise<boolean> => {
  try {
    const response = await fetch(url, {
      signal: AbortSignal.timeout(1000),
      redirect: "manual",
    });
    await response.body?.cancel();
    return !requireHealthy || response.status < 500;
  } catch {
    return false;
  }
};

const waitForApp = async (
  url: string,
  app: ChildProcess,
  signal: AbortSignal,
): Promise<void> => {
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline) {
    signal.throwIfAborted();
    if (app.exitCode !== null || app.signalCode !== null)
      throw new Error(
        "The application exited before becoming ready; inspect app.log.",
      );
    if (await responds(url, true)) return;
    await pause(250);
  }
  throw new Error(
    "The application did not become ready within 60 seconds; inspect app.log.",
  );
};

const stopApp = async (pid: number): Promise<void> => {
  const signalGroup = (signal: NodeJS.Signals): boolean => {
    try {
      process.kill(-pid, signal);
      return true;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ESRCH") return false;
      throw error;
    }
  };
  if (!signalGroup("SIGTERM")) return;
  await pause(500);
  signalGroup("SIGKILL");
};

class BrowserRun {
  readonly directory = mkdtempSync(join(tmpdir(), "matatoBrowser"));
  readonly session = `matato-${basename(this.directory)}`;
  private commandNumber = 0;
  private snapshotNumber = 0;

  command(args: Array<string>): string {
    const result = spawnSync(
      "playwright-cli",
      [`-s=${this.session}`, ...args],
      {
        cwd: this.directory,
        encoding: "utf8",
        timeout: 30000,
        maxBuffer: 10 * 1024 * 1024,
      },
    );
    const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
    const path = join(this.directory, `command${++this.commandNumber}.log`);
    writeFileSync(path, output);
    console.log(`\n$ playwright-cli ${args.join(" ")}\n${output}`);
    if (result.error) throw result.error;
    if (result.status !== 0 || /### Error\b/.test(output))
      throw new Error(`Browser command failed; inspect ${path}`);
    return output;
  }

  snapshot(): string {
    const path = join(this.directory, `snapshot${++this.snapshotNumber}.yml`);
    this.command(["snapshot", `--filename=${path}`]);
    const content = readFileSync(path, "utf8");
    console.log(content);
    return content;
  }

  async execute(scenario: BrowserScenario, signal: AbortSignal): Promise<void> {
    for (const [index, step] of scenario.steps.entries()) {
      signal.throwIfAborted();
      console.log(`\nSTEP ${index + 1}: ${JSON.stringify(step)}`);
      let snapshot = this.snapshot();
      if (step.action !== "expect") {
        this.command(stepArguments(step, snapshot));
        this.snapshot();
        continue;
      }
      const deadline = Date.now() + 10000;
      while (!snapshot.includes(step.text) && Date.now() < deadline) {
        await pause(250);
        signal.throwIfAborted();
        snapshot = this.snapshot();
      }
      if (!snapshot.includes(step.text))
        throw new Error(
          `Visible outcome not found: ${JSON.stringify(step.text)}`,
        );
      console.log(`PASS: visible outcome ${JSON.stringify(step.text)}`);
    }
  }

  evidence(): Array<string> {
    const failures: Array<string> = [];
    for (const args of [
      ["screenshot", `--filename=${join(this.directory, "result.png")}`],
      ["console", "error"],
      ["requests"],
    ]) {
      try {
        const output = this.command(args);
        if (args[0] === "requests") {
          for (const match of output.matchAll(/^(\d+)\. \[/gm)) {
            this.command(["request", match[1]]);
            this.command(["response-body", match[1]]);
          }
          this.command(["requests", "--static"]);
        }
      } catch (error) {
        failures.push(error instanceof Error ? error.message : String(error));
      }
    }
    return failures;
  }
}

const startApp = (options: RunOptions, browser: BrowserRun): ChildProcess => {
  const config = join(browser.directory, "browserConfig.json");
  writeFileSync(
    config,
    JSON.stringify({
      browser: {
        browserName: "chromium",
        launchOptions: { executablePath: "/usr/bin/brave" },
      },
    }),
  );
  const appLog = join(browser.directory, "app.log");
  const logFd = openSync(appLog, "w");
  let app: ChildProcess;
  try {
    app = spawn("/bin/bash", ["-lc", options.startCommand], {
      cwd: options.repo,
      detached: true,
      stdio: ["ignore", logFd, logFd],
    });
  } finally {
    closeSync(logFd);
  }
  return app;
};

const recordApp = (
  options: RunOptions,
  browser: BrowserRun,
  app: ChildProcess,
): void => {
  writeFileSync(
    join(browser.directory, "run.json"),
    JSON.stringify(
      {
        url: options.url,
        scenario: options.scenario.name,
        appPid: app.pid,
        appLog: join(browser.directory, "app.log"),
        session: browser.session,
      },
      null,
      2,
    ),
  );
};

const run = async (options: RunOptions): Promise<void> => {
  if (
    spawnSync("playwright-cli", ["--version"], { encoding: "utf8" }).status !==
    0
  )
    throw new Error(
      "playwright-cli is missing; do not install it during a task.",
    );
  if (!existsSync("/usr/bin/brave"))
    throw new Error(
      "Brave is missing at /usr/bin/brave; do not download a browser.",
    );
  if (await responds(options.url))
    throw new Error(
      "The URL already responds. Use an unused port; never reuse a human/shared server.",
    );
  const browser = new BrowserRun();
  const failures: Array<string> = [];
  let app: ChildProcess | undefined;
  let opened = false;
  let cleanupComplete = true;
  const controller = new AbortController();
  const onSignal = (): void =>
    controller.abort(new Error("Browser run interrupted"));
  process.once("SIGINT", onSignal);
  process.once("SIGTERM", onSignal);
  try {
    app = startApp(options, browser);
    app.on("error", (error) => controller.abort(error));
    recordApp(options, browser, app);
    await waitForApp(options.url, app, controller.signal);
    controller.signal.throwIfAborted();
    opened = true;
    browser.command([
      "--config",
      join(browser.directory, "browserConfig.json"),
      "open",
      options.url,
    ]);
    await browser.execute(options.scenario, controller.signal);
  } catch (error) {
    failures.push(error instanceof Error ? error.message : String(error));
  } finally {
    if (opened) {
      failures.push(...browser.evidence());
      try {
        browser.command(["close"]);
      } catch (error) {
        cleanupComplete = false;
        failures.push(error instanceof Error ? error.message : String(error));
      }
    }
    if (app?.pid) {
      try {
        await stopApp(app.pid);
      } catch (error) {
        cleanupComplete = false;
        failures.push(error instanceof Error ? error.message : String(error));
      }
    }
    process.removeListener("SIGINT", onSignal);
    process.removeListener("SIGTERM", onSignal);
  }
  const report = {
    result: failures.length ? "FAIL" : "PASS",
    url: options.url,
    scenario: options.scenario.name,
    failures,
    cleanupComplete,
    artifacts: browser.directory,
    screenshot: opened ? join(browser.directory, "result.png") : null,
    limitation:
      "PASS covers snapshot assertions only. Read console/network evidence and inspect the screenshot. HTTP request logs do not inspect WebSocket messages.",
  };
  writeFileSync(
    join(browser.directory, "report.json"),
    JSON.stringify(report, null, 2),
  );
  console.log(`\n${JSON.stringify(report, null, 2)}`);
  if (failures.length) {
    console.log(
      `\nAPP LOG\n${readFileSync(join(browser.directory, "app.log"), "utf8").slice(-12000)}`,
    );
    process.exitCode = 1;
  }
};

const cleanup = (directory: string): void => {
  const path = realpathSync(directory);
  if (
    dirname(path) !== realpathSync(tmpdir()) ||
    !/^matatoBrowser[A-Za-z0-9]+$/.test(basename(path))
  )
    throw new Error(
      "Refusing to delete a directory outside the browser runner's temporary artifacts.",
    );
  if (!existsSync(join(path, "report.json")))
    throw new Error(
      "Only completed runs can be deleted. Stop any interrupted app/session first.",
    );
  const report = JSON.parse(
    readFileSync(join(path, "report.json"), "utf8"),
  ) as { cleanupComplete: boolean };
  if (!report.cleanupComplete)
    throw new Error(
      "Process cleanup failed; resolve it before deleting the evidence.",
    );
  rmSync(path, { recursive: true });
  console.log(`Deleted browser artifacts: ${path}`);
};

if (import.meta.main) {
  try {
    const args = process.argv.slice(2);
    const directory = readFlagValue(args, "cleanup");
    if (directory) cleanup(directory);
    else await run(parseOptions(args));
  } catch (error) {
    console.error(errorMessage(error instanceof Error ? error : String(error)));
    process.exitCode = 1;
  }
}
