import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext, Theme } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, truncateToWidth, visibleWidth, type TUI } from "@earendil-works/pi-tui";

const thinkingLevels = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;

type ThinkingLevel = (typeof thinkingLevels)[number];
type Automation = {
  jobName: string;
  enabled: boolean;
  schedule: string;
  userPrompt: string;
  preScriptName?: string;
  model: string;
  thinkingLevel: ThinkingLevel;
  canLaunchSubAgents: boolean;
};
type AutomationConfig = { automations: Array<Automation> };
type BrowserResult = { action: "add" | "edit" | "delete" | "close" | "refresh"; index: number };

const configPath = join(homedir(), ".config", "matato-pi", "automations", "config.json");

function isThinkingLevel(value: string): value is ThinkingLevel {
  return thinkingLevels.includes(value as ThinkingLevel);
}

function isAutomation(value: unknown): value is Automation {
  if (!value || typeof value !== "object") return false;
  const entry = value as Partial<Automation>;
  return typeof entry.jobName === "string"
    && typeof entry.enabled === "boolean"
    && typeof entry.schedule === "string" && entry.schedule.trim().length > 0
    && typeof entry.userPrompt === "string" && entry.userPrompt.trim().length > 0
    && typeof entry.model === "string" && entry.model.trim().length > 0
    && typeof entry.canLaunchSubAgents === "boolean"
    && typeof entry.thinkingLevel === "string" && isThinkingLevel(entry.thinkingLevel)
    && (entry.preScriptName === undefined || typeof entry.preScriptName === "string");
}

function parseAutomation(text: string): Automation {
  const automation = JSON.parse(text) as unknown;
  if (!isAutomation(automation)) throw new Error("Invalid automation JSON. Check every required field and value.");
  return automation;
}

async function loadConfig(): Promise<AutomationConfig> {
  try {
    const config = JSON.parse(await readFile(configPath, "utf8")) as { automations?: unknown };
    if (!Array.isArray(config.automations) || !config.automations.every(isAutomation)) throw new Error("Invalid automation config");
    return { automations: config.automations };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return { automations: [] };
    throw error;
  }
}

async function saveConfig(config: AutomationConfig): Promise<void> {
  await mkdir(join(homedir(), ".config", "matato-pi", "automations"), { recursive: true });
  const temporaryPath = `${configPath}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(config, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
  await rename(temporaryPath, configPath);
}

function defaultAutomation(ctx: ExtensionCommandContext): Automation {
  return {
    jobName: "new-automation",
    enabled: true,
    schedule: "0 9 * * *",
    userPrompt: "Describe the automation work here.",
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
    if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) this.finish("close");
    else if (data === "a") this.finish("add");
    else if (data === "d" && this.automations.length) this.finish("delete");
    else if (data === "r") this.finish("refresh");
    else if (matchesKey(data, Key.enter) && this.automations.length) this.finish("edit");
    else if (matchesKey(data, Key.up)) this.selected = Math.max(0, this.selected - 1);
    else if (matchesKey(data, Key.down)) this.selected = Math.min(this.automations.length - 1, this.selected + 1);
    else if (matchesKey(data, Key.home)) this.selected = 0;
    else if (matchesKey(data, Key.end)) this.selected = Math.max(0, this.automations.length - 1);
    else return;
    this.tui.requestRender();
  }

  render(width: number): Array<string> {
    if (width < 64) return [this.theme.fg("warning", "Automations needs a terminal at least 64 columns wide.")];
    const leftWidth = Math.min(36, Math.max(24, Math.floor(width * 0.34)));
    const rightWidth = width - leftWidth - 1;
    const rows = Math.max(6, Math.floor((process.stdout.rows || 24) * 0.65));
    const border = (text: string) => this.theme.fg("borderMuted", text);
    const title = this.theme.fg("accent", this.theme.bold(` Automations · ${this.automations.length} `));
    const lines = [this.pad(`${border("─".repeat(3))}${title}${border("─".repeat(Math.max(0, width - visibleWidth(title) - 3)))}`, width)];
    lines.push(this.row(this.theme.fg("accent", " Automations"), this.previewHeader(), leftWidth, rightWidth));
    lines.push(this.row(border("─".repeat(leftWidth)), border("─".repeat(rightWidth)), leftWidth, rightWidth));
    const start = Math.max(0, Math.min(this.selected - Math.floor(rows / 2), this.automations.length - rows));
    const preview = this.previewLines(rightWidth);
    for (let row = 0; row < rows; row++) {
      const automation = this.automations[start + row];
      const selected = start + row === this.selected;
      const label = automation ? `${selected ? this.theme.fg("accent", "› ") : "  "}${selected ? this.theme.fg("accent", automation.jobName) : automation.jobName}` : "";
      lines.push(this.row(label, preview[row] ?? "", leftWidth, rightWidth));
    }
    lines.push(this.row(border("─".repeat(leftWidth)), border("─".repeat(rightWidth)), leftWidth, rightWidth));
    lines.push(this.pad(this.theme.fg("dim", " ↑↓ select · Enter edit JSON · a add · d delete · r reload · Esc close"), width));
    return lines;
  }

  invalidate(): void {}

  private finish(action: BrowserResult["action"]): void {
    this.done({ action, index: this.selected });
  }

  private previewHeader(): string {
    const automation = this.automations[this.selected];
    return this.theme.fg("accent", automation ? ` ${automation.jobName}` : " Preview");
  }

  private previewLines(width: number): Array<string> {
    const automation = this.automations[this.selected];
    if (!automation) return [this.theme.fg("muted", " No automations yet."), "", this.theme.fg("dim", " Press a to add one.")];
    const enabled = automation.enabled ? this.theme.fg("success", "Enabled") : this.theme.fg("muted", "Paused");
    const script = automation.preScriptName ?? "None";
    return [
      this.theme.bold(automation.jobName),
      "",
      `${enabled}  ·  Cron: ${automation.schedule}`,
      `Model: ${automation.model}`,
      `Reasoning: ${automation.thinkingLevel}`,
      `Sub-agents: ${automation.canLaunchSubAgents ? "allowed" : "not allowed"}`,
      `Pre-script: ${script}`,
      "",
      this.theme.fg("muted", "Prompt"),
      ...automation.userPrompt.split("\n"),
    ].map((line) => truncateToWidth(line, width));
  }

  private row(left: string, right: string, leftWidth: number, rightWidth: number): string {
    return `${this.pad(left, leftWidth)}${this.theme.fg("borderMuted", "│")}${this.pad(right, rightWidth)}`;
  }

  private pad(text: string, width: number): string {
    const clipped = truncateToWidth(text, width, "", true);
    return clipped + " ".repeat(Math.max(0, width - visibleWidth(clipped)));
  }
}

async function openEditor(ctx: ExtensionCommandContext, title: string, automation: Automation): Promise<Automation | undefined> {
  const text = await ctx.ui.editor(title, JSON.stringify(automation, null, 2));
  return text === undefined ? undefined : parseAutomation(text);
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
        ctx.ui.notify(error instanceof Error ? error.message : "Could not read automation config.", "error");
        return;
      }
      while (true) {
        const result = await ctx.ui.custom<BrowserResult>((tui, theme, _keybindings, done) => new AutomationBrowser(config.automations, tui, theme, done));
        if (!result || result.action === "close") return;
        if (result.action === "refresh") {
          config = await loadConfig();
          continue;
        }
        const current = config.automations[result.index];
        try {
          if (result.action === "delete" && current && await ctx.ui.confirm("Remove automation?", `${current.jobName} will be removed from config.json.`)) {
            config.automations.splice(result.index, 1);
            await saveConfig(config);
            ctx.ui.notify(`Removed ${current.jobName}.`, "info");
          }
          if (result.action === "add") {
            const automation = await openEditor(ctx, "Add automation JSON", defaultAutomation(ctx));
            if (!automation) continue;
            if (config.automations.some((entry) => entry.jobName === automation.jobName)) throw new Error(`An automation named ${automation.jobName} already exists.`);
            config.automations.push(automation);
            await saveConfig(config);
            ctx.ui.notify(`Added ${automation.jobName}.`, "info");
          }
          if (result.action === "edit" && current) {
            const automation = await openEditor(ctx, "Edit automation JSON", current);
            if (!automation) continue;
            if (config.automations.some((entry) => entry.jobName === automation.jobName && entry !== current)) throw new Error(`An automation named ${automation.jobName} already exists.`);
            config.automations[result.index] = automation;
            await saveConfig(config);
            ctx.ui.notify(`Updated ${automation.jobName}.`, "info");
          }
        } catch (error) {
          ctx.ui.notify(error instanceof Error ? error.message : "Could not save automation.", "error");
        }
      }
    },
  });
}
