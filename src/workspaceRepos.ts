import { readdir } from "node:fs/promises";
import { basename } from "node:path";

export type WorkspaceRepo = {
  name: string;
  directory: string;
  repositoryUrl: string;
};

export type CommandResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
};

export const runResult = async (
  command: string,
  args: Array<string>,
  cwd?: string,
): Promise<CommandResult> => {
  const process = Bun.spawn([command, ...args], {
    cwd,
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
    process.exited,
  ]);
  return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode };
};

export const run = async (
  command: string,
  args: Array<string>,
  cwd?: string,
): Promise<string> => {
  const result = await runResult(command, args, cwd);
  if (result.exitCode !== 0)
    throw new Error(`${command} failed: ${result.stderr}`);
  return result.stdout;
};

export const listWorkspaceRepos = async (): Promise<Array<WorkspaceRepo>> => {
  const workspace = Bun.env.WORKSPACE?.trim();
  if (!workspace)
    throw new Error(
      "WORKSPACE must point to the directory containing repositories",
    );

  const entries = await readdir(workspace, { withFileTypes: true });
  const repositories = await Promise.all(
    entries
      .filter((entry) => entry.isDirectory())
      .map(async (entry) => {
        const directory = `${workspace}/${entry.name}`;
        const repositoryUrl = await run(
          "git",
          ["remote", "get-url", "origin"],
          directory,
        ).catch(() => undefined);
        return repositoryUrl
          ? { name: basename(directory), directory, repositoryUrl }
          : undefined;
      }),
  );
  return repositories.filter(
    (repository): repository is WorkspaceRepo => repository !== undefined,
  );
};
