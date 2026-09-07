#!/usr/bin/env bun
import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { run, runResult } from "../../../src/workspaceRepos.ts";

type Project = { name: string; repositoryUrl: string; repository: string };
type State = { lastProposalDate?: string; proposals?: Array<unknown> };
type RepositoryFile = { type: string; name: string };
type PullRequest = { title: string; number: number; url: string };

const skip = (reason: string, details: Record<string, unknown> = {}): void =>
  console.log(JSON.stringify({ skip: true, reason, ...details }));

const localDate = (timezone: string): string => {
  const values = new Intl.DateTimeFormat("en", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts();
  const part = (type: string) =>
    values.find((value) => value.type === type)?.value;
  return `${part("year")}-${part("month")}-${part("day")}`;
};

const parseProject = (output: string): Project | undefined => {
  for (const line of output.split("\n")) {
    const repositoryUrl = line.match(
      /(?:https?:\/\/\S+|git@github\.com:\S+)$/,
    )?.[0];
    if (!repositoryUrl) continue;
    const name = line
      .slice(0, line.indexOf(repositoryUrl))
      .trim()
      .split(/\s+/, 2)[1];
    const repository = repositoryUrl
      .replace(/\.git$/, "")
      .match(/github\.com[:/]([^/]+\/[^/]+)$/)?.[1];
    if (name === "matato" && repository)
      return { name, repositoryUrl, repository };
  }
};

const readState = async (path: string): Promise<State> => {
  if (!existsSync(path)) {
    await mkdir(dirname(path), { recursive: true });
    await writeFile(
      path,
      '{\n  "lastProposalDate": "",\n  "proposals": []\n}\n',
    );
  }
  return JSON.parse(await readFile(path, "utf8")) as State;
};

const listRepositoryFiles = async (
  repository: string,
  directory: string,
): Promise<Array<RepositoryFile>> => {
  const result = await runResult("gh", [
    "api",
    `repos/${repository}/contents/${directory}`,
  ]);
  if (result.exitCode !== 0 && !result.stderr.includes("Not Found"))
    throw new Error(`gh failed: ${result.stderr}`);
  return result.exitCode === 0
    ? (JSON.parse(result.stdout) as Array<RepositoryFile>)
    : [];
};

const matchingPullRequests = async (
  repository: string,
  date: string,
): Promise<Array<PullRequest>> => {
  const pullRequests = JSON.parse(
    await run("gh", [
      "pr",
      "list",
      "--repo",
      repository,
      "--state",
      "open",
      "--search",
      `product proposal ${date} in:title`,
      "--json",
      "title,number,url",
    ]),
  ) as Array<PullRequest>;
  return pullRequests.filter((pullRequest) =>
    pullRequest.title.startsWith(`product proposal ${date}`),
  );
};

const main = async (): Promise<void> => {
  const storagePath = Bun.env.STORAGE_PATH?.trim();
  if (!storagePath) throw new Error("STORAGE_PATH must be set");

  const timezone = Bun.env.TIMEZONE?.trim() || "UTC";
  const date = localDate(timezone);
  const outputDirectory = "docs/productDevelopment";
  const stateFile = `${storagePath}/agent/product-manager.json`;
  const project = parseProject(await run("matato", ["project", "list"]));
  if (!project)
    return skip("Matato project is not configured with a repository");

  const files = await listRepositoryFiles(project.repository, outputDirectory);
  const proposal = files.find(
    (file) => file.type === "file" && file.name.startsWith(`${date}-`),
  );
  if (proposal)
    return skip(`Product proposal already exists for ${date}`, {
      localDate: date,
      file: `${outputDirectory}/${proposal.name}`,
    });

  const openPullRequests = await matchingPullRequests(project.repository, date);
  if (openPullRequests.length)
    return skip(
      `Open product proposal pull request already exists for ${date}`,
      {
        localDate: date,
        pullRequests: openPullRequests,
      },
    );

  const state = await readState(stateFile);
  if (state.lastProposalDate === date)
    return skip(`Product proposal already created for ${date}`, {
      localDate: date,
    });

  console.log(
    JSON.stringify({
      localDate: date,
      timezone,
      stateFile,
      outputDirectory,
      project: project.name,
      repositoryUrl: project.repositoryUrl,
      lastProposalDate: state.lastProposalDate ?? "",
      proposalsCount: state.proposals?.length ?? 0,
    }),
  );
};

await main();
