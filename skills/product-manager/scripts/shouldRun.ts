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

const main = async (): Promise<void> => {
  const storagePath = Bun.env.STORAGE_PATH?.trim();
  if (!storagePath) throw new Error("STORAGE_PATH must be set");

  const timezone = Bun.env.TIMEZONE?.trim() || "UTC";
  const date = localDate(timezone);
  const outputDirectory = "docs/productDevelopment";
  const stateFile = `${storagePath}/agent/product-manager.json`;
  const project = parseProject(
    await run("matato", ["--json", "project", "list"]),
  );
  if (!project)
    return skip("Matato project is not configured with a repository");

  const filesResult = await runResult("gh", [
    "api",
    `repos/${project.repository}/contents/${outputDirectory}`,
  ]);
  if (filesResult.exitCode !== 0 && !filesResult.stderr.includes("Not Found"))
    throw new Error(`gh failed: ${filesResult.stderr}`);
  const files =
    filesResult.exitCode === 0
      ? (JSON.parse(filesResult.stdout) as Array<RepositoryFile>)
      : [];
  const proposal = files.find(
    (file) => file.type === "file" && file.name.startsWith(`${date}-`),
  );
  if (proposal)
    return skip(`Product proposal already exists for ${date}`, {
      localDate: date,
      file: `${outputDirectory}/${proposal.name}`,
    });

  const pullRequests = JSON.parse(
    await run("gh", [
      "pr",
      "list",
      "--repo",
      project.repository,
      "--state",
      "open",
      "--search",
      `product proposal ${date} in:title`,
      "--json",
      "title,number,url",
    ]),
  ) as Array<PullRequest>;
  const matchingPullRequests = pullRequests.filter((pullRequest) =>
    pullRequest.title.startsWith(`product proposal ${date}`),
  );
  if (matchingPullRequests.length)
    return skip(
      `Open product proposal pull request already exists for ${date}`,
      {
        localDate: date,
        pullRequests: matchingPullRequests,
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
