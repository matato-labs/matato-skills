import { afterEach, describe, expect, test } from "bun:test";
import { chmod, mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { run } from "../../../src/workspaceRepos.ts";

const directories: Array<string> = [];
const preScriptPath = fileURLToPath(new URL("./preScript.ts", import.meta.url));

afterEach(async () => {
  await Promise.all(
    directories
      .splice(0)
      .map((directory) => rm(directory, { recursive: true, force: true })),
  );
});

const createRepository = async (
  workspace: string,
  name: string,
): Promise<string> => {
  const directory = join(workspace, name);
  await mkdir(directory);
  await run("git", ["init", "-q"], directory);
  await run(
    "git",
    ["remote", "add", "origin", `https://example.com/${name}.git`],
    directory,
  );
  return directory;
};

const runPreScript = async (
  workspace: string,
  ghScript: string,
): Promise<string> => {
  const binDirectory = await mkdtemp(join(tmpdir(), "pr-screenshot-bin-"));
  directories.push(binDirectory);
  const ghPath = join(binDirectory, "gh");
  await writeFile(ghPath, ghScript);
  await chmod(ghPath, 0o755);

  const childProcess = Bun.spawn([process.execPath, preScriptPath], {
    env: {
      ...process.env,
      WORKSPACE: workspace,
      PATH: `${binDirectory}:${process.env.PATH ?? ""}`,
    },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(childProcess.stdout).text(),
    new Response(childProcess.stderr).text(),
    childProcess.exited,
  ]);
  expect(exitCode).toBe(0);
  expect(stderr).toBe("");
  return stdout.trim();
};

describe("pull-request screenshot pre-script", () => {
  test("supplies the labeled pull request and its repository context", async () => {
    const workspace = await mkdtemp(join(tmpdir(), "pr-screenshot-workspace-"));
    directories.push(workspace);
    await createRepository(workspace, "first");
    await createRepository(workspace, "reviewed");
    await createRepository(workspace, "zlater");

    const output = await runPreScript(
      workspace,
      `#!/bin/sh
if [ "$1" = pr ] && [ "$2" = list ]; then
  [ "$3" = --search ] && [ "$4" = 'label:ui-change state:open' ] && [ "$5" = --limit ] && [ "$6" = 1 ] && [ "$7" = --json ] && [ "$8" = number ] && [ "$9" = --jq ] && [ "\${10}" = '.[0].number // empty' ] || exit 1
  if [ "$(basename "$PWD")" = first ]; then exit 0; fi
  printf '47'
  exit 0
fi
[ "$1" = pr ] && [ "$2" = view ] && [ "$3" = 47 ] && [ "$4" = --json ] && [ "$5" = 'number,title,body,url,headRefName,baseRefName' ] || exit 1
printf '%s' '{"number":47,"title":"Review checkout","body":null,"url":"https://github.com/example/reviewed/pull/47","headRefName":"feature","baseRefName":"main"}'`,
    );

    expect(output.split("\n")).toHaveLength(1);
    expect(output).toContain('"body":""');
    expect(output).toContain('"project":"');
    expect(output).toContain('"repositoryUrl":"https://example.com/');
  });

  test("does not start an agent when no pull request is labeled for review", async () => {
    const workspace = await mkdtemp(join(tmpdir(), "pr-screenshot-workspace-"));
    directories.push(workspace);
    await createRepository(workspace, "repository");

    const output = await runPreScript(
      workspace,
      '#!/bin/sh\nif [ "$1" = pr ] && [ "$2" = list ]; then exit 0; fi\nexit 1',
    );

    expect(output).toBe("");
  });
});
