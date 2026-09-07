import { execFileSync } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import {
  getMarkdownTheme,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  Key,
  Markdown,
  matchesKey,
  truncateToWidth,
  visibleWidth,
  type TUI,
} from "@earendil-works/pi-tui";

interface ArchiveFile {
  name: string;
  content: string;
}

type Focus = "files" | "preview";

async function loadArchives(directory: string): Promise<ArchiveFile[]> {
  try {
    const entries = await readdir(directory, { withFileTypes: true });
    const names = entries
      .filter(
        (entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".md"),
      )
      .map((entry) => entry.name)
      .sort((a, b) => b.localeCompare(a));
    return await Promise.all(
      names.map(async (name) => ({
        name,
        content: await readFile(join(directory, name), "utf8"),
      })),
    );
  } catch (error: unknown) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return [];
    throw error;
  }
}

function gitProjectName(cwd: string): string | undefined {
  try {
    const root = execFileSync("git", ["rev-parse", "--show-toplevel"], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    return root ? basename(root) : undefined;
  } catch {
    return undefined;
  }
}

class ArchiveBrowser {
  private selected = 0;
  private previewOffset = 0;
  private focus: Focus = "files";
  private markdown?: Markdown;
  private markdownIndex = -1;

  constructor(
    private readonly title: string,
    private readonly files: ArchiveFile[],
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly done: () => void,
  ) {}

  handleInput(data: string): void {
    const actions: Array<[boolean, () => void]> = [
      [
        matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c")),
        () => this.closePreview(),
      ],
      [
        (matchesKey(data, Key.enter) || matchesKey(data, Key.right)) &&
          Boolean(this.files.length),
        () => (this.focus = "preview"),
      ],
      [matchesKey(data, Key.left), () => (this.focus = "files")],
      [matchesKey(data, Key.up), () => this.move(-1)],
      [matchesKey(data, Key.down), () => this.move(1)],
      [matchesKey(data, Key.home), () => this.jump(0)],
      [matchesKey(data, Key.end), () => this.jump(this.files.length - 1)],
    ];
    const action = actions.find(([matches]) => matches)?.[1];
    if (!action) return;
    action();
    this.tui.requestRender();
  }

  render(width: number): string[] {
    if (width < 48)
      return [
        this.theme.fg(
          "warning",
          "Archive browser needs a terminal at least 48 columns wide.",
        ),
      ];

    const leftWidth = Math.min(36, Math.max(20, Math.floor(width * 0.32)));
    const rightWidth = width - leftWidth - 1;
    const bodyRows = Math.max(
      6,
      Math.floor((process.stdout.rows || 24) * 0.8) - 5,
    );
    const border = (text: string) => this.theme.fg("borderMuted", text);
    const title = this.theme.fg("accent", this.theme.bold(` ${this.title} `));
    const lines = [
      this.pad(
        `${border("─".repeat(3))}${title}${border("─".repeat(Math.max(0, width - visibleWidth(title) - 3)))}`,
        width,
      ),
    ];

    const previewLines = this.previewLines(rightWidth);
    this.previewOffset = Math.min(
      this.previewOffset,
      Math.max(0, previewLines.length - bodyRows),
    );
    const listStart = Math.max(
      0,
      Math.min(
        this.selected - Math.floor(bodyRows / 2),
        this.files.length - bodyRows,
      ),
    );

    lines.push(
      this.row(
        this.theme.fg(this.focus === "files" ? "accent" : "muted", " Files"),
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

    for (let row = 0; row < bodyRows; row++) {
      const file = this.files[listStart + row];
      const selected = listStart + row === this.selected;
      const label = file
        ? `${selected ? this.theme.fg("accent", "› ") : "  "}${selected ? this.theme.fg("accent", file.name) : this.theme.fg("text", file.name)}`
        : "";
      const preview = previewLines[this.previewOffset + row] ?? "";
      lines.push(this.row(label, preview, leftWidth, rightWidth));
    }

    lines.push(
      this.row(
        border("─".repeat(leftWidth)),
        border("─".repeat(rightWidth)),
        leftWidth,
        rightWidth,
      ),
    );
    const help =
      this.focus === "files"
        ? "↑↓ select · Enter preview · Esc close"
        : "↑↓ scroll · ←/Esc files";
    lines.push(this.pad(this.theme.fg("dim", ` ${help}`), width));
    return lines;
  }

  invalidate(): void {
    this.markdown?.invalidate();
  }

  private closePreview(): void {
    if (this.focus === "preview") this.focus = "files";
    else this.done();
  }

  private move(delta: number): void {
    if (!this.files.length) return;
    if (this.focus === "files") this.jump(this.selected + delta);
    else this.previewOffset = Math.max(0, this.previewOffset + delta);
  }

  private jump(index: number): void {
    if (!this.files.length) return;
    this.selected = Math.max(0, Math.min(index, this.files.length - 1));
    this.previewOffset = 0;
    this.markdownIndex = -1;
  }

  private previewHeader(): string {
    const file = this.files[this.selected];
    if (!file) return this.theme.fg("muted", " Preview");
    return this.theme.fg(
      this.focus === "preview" ? "accent" : "muted",
      ` ${file.name}`,
    );
  }

  private previewLines(width: number): string[] {
    const file = this.files[this.selected];
    if (!file) return [this.theme.fg("dim", " No archived files.")];
    if (this.markdownIndex !== this.selected) {
      this.markdown = new Markdown(file.content, 1, 0, getMarkdownTheme());
      this.markdownIndex = this.selected;
    }
    return this.markdown!.render(width);
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
  const openBrowser = async (
    title: string,
    directory: string,
    ctx: ExtensionCommandContext,
  ) => {
    if (ctx.mode !== "tui") {
      ctx.ui.notify(`${title} requires interactive TUI mode.`, "error");
      return;
    }
    const files = await loadArchives(directory);
    await ctx.ui.custom<void>(
      (tui, theme, _keybindings, done) =>
        new ArchiveBrowser(title, files, tui, theme, done),
      {
        overlay: true,
        overlayOptions: { anchor: "center", width: "95%", maxHeight: "80%" },
      },
    );
  };

  pi.registerCommand("plans", {
    description: "Browse archived plans for the current Git project",
    handler: async (_args, ctx) => {
      const project = gitProjectName(ctx.cwd);
      if (!project) {
        ctx.ui.notify("/plans requires a Git repository.", "error");
        return;
      }
      await openBrowser(
        "Plans",
        join(homedir(), ".config", "matato-pi", "plans", project),
        ctx,
      );
    },
  });

  pi.registerCommand("researches", {
    description: "Browse archived research",
    handler: async (_args, ctx) => {
      await openBrowser(
        "Researches",
        join(homedir(), ".config", "matato-pi", "research"),
        ctx,
      );
    },
  });
}
