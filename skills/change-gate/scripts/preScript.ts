#!/usr/bin/env bun
import { listWorkspaceRepos, run } from "../../../src/workspaceRepos.ts";

type PullRequest = {
  number: number;
  title: string;
  body?: string;
  url: string;
  labels: Array<{ name: string }>;
};

const skip = (reason: string): void =>
  console.log(JSON.stringify({ skip: true, reason }));

const main = async (): Promise<void> => {
  const [user, repositories] = await Promise.all([
    run("gh", ["api", "user", "--jq", ".login"]),
    listWorkspaceRepos(),
  ]);
  if (!repositories.length)
    return skip("No GitHub repositories found in WORKSPACE");

  for (const repository of repositories) {
    const number = await run(
      "gh",
      [
        "pr",
        "list",
        "--search",
        "label:ai-review no:assignee state:open",
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

    await run(
      "gh",
      ["pr", "edit", number, "--add-assignee", user],
      repository.directory,
    );
    const pullRequest = JSON.parse(
      await run(
        "gh",
        ["pr", "view", number, "--json", "number,title,body,url,labels"],
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
          labels: pullRequest.labels.map(({ name }) => name),
        },
        assignedTo: user,
      }),
    );
    return;
  }

  skip("No available ai-review pull requests");
};

await main();
