import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import {
  type Automation,
  type AutomationConfig,
} from "../../src/automation.ts";
import { automationConfigPath } from "../../src/storagePath.ts";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import {
  Key,
  matchesKey,
  truncateToWidth,
  visibleWidth,
  type TUI,
} from "@earendil-works/pi-tui";

type BrowserResult = {
  action: "add" | "edit" | "delete" | "close" | "refresh";
  index: number;
};

const configPath = automationConfigPath();

function parseAutomation(text: string): Automation {
  return JSON.parse(text) as Automation;
}

async function loadConfig(): Promise<AutomationConfig> {
  try {
    return JSON.parse(await readFile(configPath, "utf8")) as AutomationConfig;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT")
      return { automations: [] };
    throw error;
  }
}

async function saveConfig(config: AutomationConfig): Promise<void> {
  await mkdir(dirname(configPath), { recursive: true });
  const temporaryPath = `${configPath}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(config, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
  await rename(temporaryPath, configPath);
}

function defaultAutomation(ctx: ExtensionCommandContext): Automation {
  return {
    jobName: "new-automation",
    enabled: true,
    schedule: "0 9 * * *",
    userPrompt: "Describe the automation work here.",
    dailySession: false,
    model: ctx.model?.id ?? "model-id",
    thinkingLevel: "low",
    canLaunchSubAgents: false,
  };
}

class AutomationBrowser {
  private selected = 0;

  constructor(
    private readonly automations: Array<Automation>,
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly done: (result: BrowserResult) => void,
  ) {}

  handleInput(data: string): void {
    const actions: Array<[boolean, () => void]> = [
      [
        matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c")),
        () => this.finish("close"),
      ],
      [data === "a", () => this.finish("add")],
      [
        data === "d" && Boolean(this.automations.length),
        () => this.finish("delete"),
      ],
      [data === "r", () => this.finish("refresh")],
      [
        matchesKey(data, Key.enter) && Boolean(this.automations.length),
        () => this.finish("edit"),
      ],
      [matchesKey(data, Key.up), () => this.moveSelection(-1)],
      [matchesKey(data, Key.down), () => this.moveSelection(1)],
      [matchesKey(data, Key.home), () => this.jumpSelection(0)],
      [matchesKey(data, Key.end), () => this.jumpSelection(-1)],
    ];
    const action = actions.find(([matches]) => matches)?.[1];
    if (!action) return;
    action();
    this.tui.requestRender();
  }

  render(width: number): Array<string> {
    if (width < 64)
      return [
        this.theme.fg(
          "warning",
          "Automations needs a terminal at least 64 columns wide.",
        ),
      ];
    const leftWidth = Math.min(36, Math.max(24, Math.floor(width * 0.34)));
    const rightWidth = width - leftWidth - 1;
    const rows = Math.max(6, Math.floor((process.stdout.rows || 24) * 0.65));
    const border = (text: string) => this.theme.fg("borderMuted", text);
    const title = this.theme.fg(
      "accent",
      this.theme.bold(` Automations · ${this.automations.length} `),
    );
    const lines = [
      this.pad(
        `${border("─".repeat(3))}${title}${border("─".repeat(Math.max(0, width - visibleWidth(title) - 3)))}`,
        width,
      ),
    ];
    lines.push(
      this.row(
        this.theme.fg("accent", " Automations"),
        this.previewHeader(),
        leftWidth,
        rightWidth,
      ),
    );
    lines.push(
      this.row(
        border("─".repeat(leftWidth)),
        border("─".repeat(rightWidth)),
        leftWidth,
        rightWidth,
      ),
    );
    const start = Math.max(
      0,
      Math.min(
        this.selected - Math.floor(rows / 2),
        this.automations.length - rows,
      ),
    );
    const preview = this.previewLines(rightWidth);
    for (let row = 0; row < rows; row++) {
      const automation = this.automations[start + row];
      const selected = start + row === this.selected;
      const label = automation
        ? `${selected ? this.theme.fg("accent", "› ") : "  "}${selected ? this.theme.fg("accent", automation.jobName) : automation.jobName}`
        : "";
      lines.push(this.row(label, preview[row] ?? "", leftWidth, rightWidth));
    }
    lines.push(
      this.row(
        border("─".repeat(leftWidth)),
        border("─".repeat(rightWidth)),
        leftWidth,
        rightWidth,
      ),
    );
    lines.push(
      this.pad(
        this.theme.fg(
          "dim",
          " ↑↓ select · Enter edit JSON · a add · d delete · r reload · Esc close",
        ),
        width,
      ),
    );
    return lines;
  }

  invalidate(): void {}

  private moveSelection(delta: number): void {
    this.selected = Math.max(
      0,
      Math.min(this.automations.length - 1, this.selected + delta),
    );
  }

  private jumpSelection(index: number): void {
    this.selected =
      index < 0 ? Math.max(0, this.automations.length - 1) : index;
  }

  private finish(action: BrowserResult["action"]): void {
    this.done({ action, index: this.selected });
  }

  private previewHeader(): string {
    const automation = this.automations[this.selected];
    return this.theme.fg(
      "accent",
      automation ? ` ${automation.jobName}` : " Preview",
    );
  }

  private previewLines(width: number): Array<string> {
    const automation = this.automations[this.selected];
    if (!automation)
      return [
        this.theme.fg("muted", " No automations yet."),
        "",
        this.theme.fg("dim", " Press a to add one."),
      ];
    const enabled = automation.enabled
      ? this.theme.fg("success", "Enabled")
      : this.theme.fg("muted", "Paused");
    return [
      this.theme.bold(automation.jobName),
      "",
      `${enabled}  ·  Cron: ${automation.schedule}`,
      `Model: ${automation.model}`,
      `Reasoning: ${automation.thinkingLevel}`,
      `Sub-agents: ${automation.canLaunchSubAgents ? "allowed" : "not allowed"}`,
      `Daily session: ${automation.dailySession ? "enabled" : "disabled"}`,
      "",
      this.theme.fg("muted", "Prompt"),
      ...automation.userPrompt.split("\n"),
    ].map((line) => truncateToWidth(line, width));
  }

  private row(
    left: string,
    right: string,
    leftWidth: number,
    rightWidth: number,
  ): string {
    return `${this.pad(left, leftWidth)}${this.theme.fg("borderMuted", "│")}${this.pad(right, rightWidth)}`;
  }

  private pad(text: string, width: number): string {
    const clipped = truncateToWidth(text, width, "", true);
    return clipped + " ".repeat(Math.max(0, width - visibleWidth(clipped)));
  }
}

async function openEditor(
  ctx: ExtensionCommandContext,
  title: string,
  automation: Automation,
): Promise<Automation | undefined> {
  const text = await ctx.ui.editor(title, JSON.stringify(automation, null, 2));
  return text === undefined ? undefined : parseAutomation(text);
}

const assertUniqueJobName = (
  automations: Automation[],
  automation: Automation,
  current?: Automation,
): void => {
  if (
    automations.some(
      (entry) => entry.jobName === automation.jobName && entry !== current,
    )
  )
    throw new Error(
      `An automation named ${automation.jobName} already exists.`,
    );
};

async function handleAction(
  result: BrowserResult,
  config: AutomationConfig,
  ctx: ExtensionCommandContext,
): Promise<void> {
  const current = config.automations[result.index];
  if (result.action === "delete" && current) {
    if (
      await ctx.ui.confirm(
        "Remove automation?",
        `${current.jobName} will be removed from config.json.`,
      )
    ) {
      config.automations.splice(result.index, 1);
      await saveConfig(config);
      ctx.ui.notify(`Removed ${current.jobName}.`, "info");
    }
    return;
  }
  if (result.action === "add") {
    const automation = await openEditor(
      ctx,
      "Add automation JSON",
      defaultAutomation(ctx),
    );
    if (!automation) return;
    assertUniqueJobName(config.automations, automation);
    config.automations.push(automation);
    await saveConfig(config);
    ctx.ui.notify(`Added ${automation.jobName}.`, "info");
    return;
  }
  if (result.action === "edit" && current) {
    const automation = await openEditor(ctx, "Edit automation JSON", current);
    if (!automation) return;
    assertUniqueJobName(config.automations, automation, current);
    config.automations[result.index] = automation;
    await saveConfig(config);
    ctx.ui.notify(`Updated ${automation.jobName}.`, "info");
  }
}

export default function (pi: ExtensionAPI): void {
  pi.registerCommand("automations", {
    description: "Add, edit, remove, and inspect scheduled Matato automations",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/automations requires interactive TUI mode.", "error");
        return;
      }
      let config: AutomationConfig;
      try {
        config = await loadConfig();
      } catch (error) {
        ctx.ui.notify(
          error instanceof Error
            ? error.message
            : "Could not read automation config.",
          "error",
        );
        return;
      }
      while (true) {
        const result = await ctx.ui.custom<BrowserResult>(
          (tui, theme, _keybindings, done) =>
            new AutomationBrowser(config.automations, tui, theme, done),
        );
        if (!result || result.action === "close") return;
        if (result.action === "refresh") {
          config = await loadConfig();
          continue;
        }
        try {
          await handleAction(result, config, ctx);
        } catch (error) {
          ctx.ui.notify(
            error instanceof Error
              ? error.message
              : "Could not save automation.",
            "error",
          );
        }
      }
    },
  });
}
