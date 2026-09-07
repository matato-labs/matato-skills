import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { listWorkspaceRepos, run, runResult } from "./workspaceRepos.ts";

const workspace = process.env.WORKSPACE;
afterEach(() => {
  if (workspace === undefined) delete process.env.WORKSPACE;
  else process.env.WORKSPACE = workspace;
});

describe("workspace commands", () => {
  test("returns trimmed output and rejects failed commands", async () => {
    await expect(runResult("printf", [" value "])).resolves.toMatchObject({
      stdout: "value",
      stderr: "",
      exitCode: 0,
    });
    await expect(run("sh", ["-c", "echo failed >&2; exit 3"])).rejects.toThrow(
      "sh failed: failed",
    );
  });

  test("requires WORKSPACE and lists only repositories with origin remotes", async () => {
    delete process.env.WORKSPACE;
    await expect(listWorkspaceRepos()).rejects.toThrow("WORKSPACE must point");
    const root = await mkdtemp(join(tmpdir(), "workspace-"));
    const repository = join(root, "repository");
    await mkdir(repository);
    await run("git", ["init", "-q"], repository);
    await run(
      "git",
      ["remote", "add", "origin", "https://example.com/repository.git"],
      repository,
    );
    await mkdir(join(root, "not-a-repository"));
    process.env.WORKSPACE = root;
    await expect(listWorkspaceRepos()).resolves.toEqual([
      {
        name: "repository",
        directory: repository,
        repositoryUrl: "https://example.com/repository.git",
      },
    ]);
  });
});
