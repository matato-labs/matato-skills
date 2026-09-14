#!/usr/bin/env bun
import { listWorkspaceRepos, run } from "../../../src/workspaceRepos.ts";

type PullRequest = {
  number: number;
  title: string;
  body: string | null;
  url: string;
  headRefName: string;
  baseRefName: string;
};

const main = async (): Promise<void> => {
  const repositories = await listWorkspaceRepos();

  for (const repository of repositories) {
    const number = await run(
      "gh",
      [
        "pr",
        "list",
        "--search",
        'label:ui-change state:open',
        "--limit",
        "1",
        "--json",
        "number",
        "--jq",
        ".[0].number // empty",
      ],
      repository.directory,
    );
    if (!number) continue;

    const pullRequest = JSON.parse(
      await run(
        "gh",
        [
          "pr",
          "view",
          number,
          "--json",
          "number,title,body,url,headRefName,baseRefName",
        ],
        repository.directory,
      ),
    ) as PullRequest;

    console.log(
      JSON.stringify({
        pullRequest: {
          ...pullRequest,
          project: repository.name,
          repositoryUrl: repository.repositoryUrl,
          body: pullRequest.body ?? "",
        },
      }),
    );
    return;
  }
};

await main();
