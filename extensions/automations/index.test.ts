import { afterEach, describe, expect, mock, test } from "bun:test";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { visibleWidth, type TUI } from "@earendil-works/pi-tui";
import type { Automation } from "../../src/automation.ts";
import registerAutomations, {
  AutomationBrowser,
  loadAutomations,
} from "./index.ts";

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

async function temporaryDirectory(): Promise<string> {
  const path = await mkdtemp(join(tmpdir(), "matatoAutomationsBrowser"));
  directories.push(path);
  return path;
}

const automation: Automation = {
  jobName: "heartbeat",
  enabled: true,
  schedule: "0 9 * * *",
  userPrompt: "Review work",
  model: "configuredModel",
  thinkingLevel: "low",
  canLaunchSubAgents: false,
  canOverlap: false,
  dailySession: true,
  monitor: true,
  useSkill: true,
};

function browser(jobs: Array<Automation>) {
  const theme = {
    fg: (color: Parameters<Theme["fg"]>[0], text: string) => text,
    bold: (text: string) => text,
  } as Theme;
  const requestRender = mock(() => {});
  const done = mock(() => {});
  const tui: Partial<TUI> = { requestRender };
  return new AutomationBrowser(jobs, tui as TUI, theme, done);
}

function commandHandler() {
  const registerCommand = mock<ExtensionAPI["registerCommand"]>();
  const pi: Partial<ExtensionAPI> = { registerCommand };
  registerAutomations(pi as ExtensionAPI);
  return registerCommand.mock.calls[0][1].handler;
}

type BrowserFactory = Parameters<ExtensionCommandContext["ui"]["custom"]>[0];
type BrowserAction = { action: "close" | "refresh" };

function commandContext(
  mode: ExtensionCommandContext["mode"],
  custom: (factory: BrowserFactory) => Promise<BrowserAction>,
) {
  const notify = mock(() => {});
  const ui: Partial<ExtensionCommandContext["ui"]> = { notify };
  Object.assign(ui, { custom });
  const ctx: Partial<ExtensionCommandContext> = {
    mode,
    ui: ui as ExtensionCommandContext["ui"],
  };
  return { ctx: ctx as ExtensionCommandContext, notify };
}

const emptyApi = () =>
  mock(() => Promise.resolve(Response.json({ automations: [] })));

describe("automation browser source", () => {
  test("local jobs do not require the web app", async () => {
    const path = join(await temporaryDirectory(), "config.json");
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = path;
    await writeFile(
      path,
      JSON.stringify({
        automations: [
          {
            jobName: "heartbeat",
            enabled: true,
            schedule: "0 9 * * *",
            userPrompt: "Review work",
            model: "configuredModel",
            thinkingLevel: "low",
            canLaunchSubAgents: false,
          },
        ],
      }),
    );
    const fetchImpl = emptyApi();
    const jobs = await loadAutomations(fetchImpl);
    expect(jobs[0].jobName).toBe("heartbeat");
    expect(jobs[0].useSkill).toBe(true);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test("prefers the default local file over web jobs", async () => {
    delete process.env.MATATO_PI_AUTOMATIONS_CONFIG;
    const directory = await temporaryDirectory();
    process.env.MATATO_PI_CONFIG = directory;
    await mkdir(join(directory, "automations"));
    await writeFile(
      join(directory, "automations", "config.json"),
      '{"automations":[]}',
    );
    const fetchImpl = emptyApi();
    expect(await loadAutomations(fetchImpl)).toEqual([]);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test("an explicit missing config does not fall back to HTTP", async () => {
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = join(
      await temporaryDirectory(),
      "missing.json",
    );
    const fetchImpl = emptyApi();
    expect(await loadAutomations(fetchImpl)).toEqual([]);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test("retains web app browsing when no local config exists", async () => {
    delete process.env.MATATO_PI_AUTOMATIONS_CONFIG;
    process.env.MATATO_PI_CONFIG = await temporaryDirectory();
    const fetchImpl = emptyApi();
    expect(await loadAutomations(fetchImpl)).toEqual([]);
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });

  test("broken local JSON is surfaced instead of falling back to HTTP", async () => {
    const path = join(await temporaryDirectory(), "broken.json");
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = path;
    await writeFile(path, "{");
    const fetchImpl = emptyApi();
    await expect(loadAutomations(fetchImpl)).rejects.toThrow();
    expect(fetchImpl).not.toHaveBeenCalled();
  });
});

describe("automation browser rendering", () => {
  test("preserves labels, selection and terminal widths", () => {
    const component = browser([
      automation,
      { ...automation, jobName: "second" },
    ]);
    expect(component.render(63)).toEqual([
      "Automations needs a terminal at least 64 columns wide.",
    ]);
    const lines = component.render(100);
    expect(lines.join("\n")).toContain("› heartbeat");
    expect(lines.every((line) => visibleWidth(line) === 100)).toBe(true);
    component.handleInput("\u001b[B");
    expect(component.render(100).join("\n")).toContain("› second");
  });

  test("retains the empty preview", () => {
    const text = browser([]).render(100).join("\n");
    expect(text).toContain("No automations yet.");
    expect(text).toContain("Ask the agent to create one.");
  });

  test("monitoring distinguishes local, enabled and disabled jobs", async () => {
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = join(
      await temporaryDirectory(),
      "missing.json",
    );
    expect(browser([automation]).render(100).join("\n")).toContain(
      "Monitoring: unavailable in TS worker",
    );
    delete process.env.MATATO_PI_AUTOMATIONS_CONFIG;
    process.env.MATATO_PI_CONFIG = await temporaryDirectory();
    expect(browser([automation]).render(100).join("\n")).toContain(
      "Monitoring: enabled",
    );
    expect(
      browser([{ ...automation, monitor: false }])
        .render(100)
        .join("\n"),
    ).toContain("Monitoring: disabled");
  });
});

describe("automation command", () => {
  test("rejects noninteractive mode before loading", async () => {
    const { ctx, notify } = commandContext("print", async () => ({
      action: "close",
    }));
    await commandHandler()("", ctx);
    expect(notify).toHaveBeenCalledWith(
      "/automations requires interactive TUI mode.",
      "error",
    );
  });

  test("initial load errors notify and do not open the browser", async () => {
    const path = join(await temporaryDirectory(), "broken.json");
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = path;
    await writeFile(path, "{");
    const custom = mock<(factory: BrowserFactory) => Promise<BrowserAction>>(
      async () => ({ action: "close" }),
    );
    const { ctx, notify } = commandContext("tui", custom);
    await commandHandler()("", ctx);
    expect(notify).toHaveBeenCalledTimes(1);
    expect(custom).not.toHaveBeenCalled();
  });

  test("failed reload notifies and keeps the previous list", async () => {
    const path = join(await temporaryDirectory(), "config.json");
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = path;
    await writeFile(path, JSON.stringify({ automations: [automation] }));
    const custom = mock<(factory: BrowserFactory) => Promise<BrowserAction>>(
      async () => ({ action: "close" }),
    ).mockImplementationOnce(async () => {
      await writeFile(path, "{");
      return { action: "refresh" };
    });
    const { ctx, notify } = commandContext("tui", custom);
    await commandHandler()("", ctx);
    expect(custom).toHaveBeenCalledTimes(2);
    expect(notify).toHaveBeenCalledTimes(1);
    const factory = custom.mock.calls[1][0];
    const tui: Partial<TUI> = { requestRender: () => {} };
    const component = await factory(
      tui as TUI,
      {
        fg: (color: Parameters<Theme["fg"]>[0], text: string) => text,
        bold: (text: string) => text,
      } as Theme,
      {} as Parameters<typeof factory>[2],
      () => {},
    );
    expect(component.render(100).join("\n")).toContain("heartbeat");
  });
});
