import { expect, test } from "bun:test";

const skillPaths = [
  "agent-pr-comment-resolver/SKILL.md",
  "change-gate/SKILL.md",
  "coding-session/SKILL.md",
];

test("skills require isolated worktrees under tmp", async () => {
  for (const skillPath of skillPaths) {
    const skill = await Bun.file(
      new URL(`./${skillPath}`, import.meta.url),
    ).text();

    expect(skill).toContain("worktree under `/tmp`");
  }
});
