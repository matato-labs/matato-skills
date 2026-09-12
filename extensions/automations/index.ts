import type { Automation } from "../../src/automation.ts";
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

type BrowserResult = { action: "close" | "refresh" };

type AutomationResponse = {
  automations: Array<AutomationRecord>;
};

type AutomationRecord = {
  id: number;
  job_name: string;
  enabled: boolean;
  schedule: string;
  user_prompt: string;
  daily_session: boolean;
  model: string;
  thinking_level: Automation["thinkingLevel"];
  can_launch_sub_agents: boolean;
  use_skill: boolean;
};

const automationApiUrl = `${process.env.MATATO_PI_WEB_URL ?? "http://localhost:4000"}/api/automations`;

function fromRecord(record: AutomationRecord): Automation {
  return {
    jobName: record.job_name,
    enabled: record.enabled,
    schedule: record.schedule,
    userPrompt: record.user_prompt,
    dailySession: record.daily_session,
    model: record.model,
    thinkingLevel: record.thinking_level,
    canLaunchSubAgents: record.can_launch_sub_agents,
    useSkill: record.use_skill,
  };
}

async function loadAutomations(): Promise<Array<Automation>> {
  const response = await fetch(automationApiUrl);
  if (!response.ok)
    throw new Error(`Automation API returned ${response.status}.`);
  const body = (await response.json()) as AutomationResponse;
  return body.automations.map(fromRecord);
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
      [data === "r", () => this.finish("refresh")],
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
          " ↑↓ select · r reload · Esc close · Ask the agent to change automations",
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
    this.done({ action });
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
        this.theme.fg("dim", " Ask the agent to create one."),
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
      `Skill: ${automation.useSkill ? automation.jobName : "none"}`,
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

export default function (pi: ExtensionAPI): void {
  pi.registerCommand("automations", {
    description: "Inspect scheduled Matato automations",
    handler: async (_args, ctx: ExtensionCommandContext) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/automations requires interactive TUI mode.", "error");
        return;
      }
      let automations: Array<Automation>;
      try {
        automations = await loadAutomations();
      } catch (error) {
        ctx.ui.notify(
          error instanceof Error
            ? error.message
            : "Could not read automations.",
          "error",
        );
        return;
      }
      while (true) {
        const result = await ctx.ui.custom<BrowserResult>(
          (tui, theme, _keybindings, done) =>
            new AutomationBrowser(automations, tui, theme, done),
        );
        if (!result || result.action === "close") return;
        try {
          automations = await loadAutomations();
        } catch (error) {
          ctx.ui.notify(
            error instanceof Error
              ? error.message
              : "Could not read automations.",
            "error",
          );
        }
      }
    },
  });
}
