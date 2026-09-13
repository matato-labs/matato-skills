import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const skill = readFileSync(join(import.meta.dir, "SKILL.md"), "utf8");

test("uses safe authentication without exposing credentials", () => {
  expect(skill).toContain(
    "`ntn api` uses `NOTION_API_TOKEN` when it is set; otherwise it uses the user's CLI login session.",
  );
  expect(skill).toContain(
    "If an authenticated command fails because authentication is absent or expired, tell the user to run `ntn login` themselves",
  );
  expect(skill).toContain(
    "Do not print the token to determine which is in use.",
  );
  expect(skill).toContain(
    "Do not install it, start OAuth, or otherwise change authentication on the user's behalf.",
  );
  expect(skill).not.toContain("test -n");
});

test("requires documented API discovery for scoped Notion reads and writes", () => {
  expect(skill).toContain("This skill is API-first and does not require MCP.");
  expect(skill).toContain(
    "Do not invent endpoint paths, methods, flags, or JSON fields.",
  );
  expect(skill).toContain("ntn api ls");
  expect(skill).toContain("ntn api <path> --docs");
  expect(skill).toContain("ntn api <path> --spec");
  expect(skill).toContain("ntn api v1/pages/<page-id>/markdown");
  expect(skill).toContain(
    "`ntn datasources query <data-source-id> --limit <n>`",
  );
  expect(skill).toContain(
    "do not assume a Markdown field or substitute `rich_text` without verifying the schema",
  );
  expect(skill).not.toContain("ntn pages");
});

test("requires fresh confirmation before Notion writes", () => {
  expect(skill).toContain(
    "Before any write, show the target workspace object, intended change, and exact command or request body, then obtain explicit user confirmation.",
  );
  expect(skill).toContain(
    "Do not proceed from an earlier or ambiguous confirmation.",
  );
  expect(skill).toContain(
    "Confirm the source, destination, and intended access before uploading a file.",
  );
  expect(skill).toContain(
    "Ask for fresh, explicit confirmation immediately before every externally visible or irreversible action",
  );
});
