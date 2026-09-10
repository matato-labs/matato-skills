#!/usr/bin/env bun
import { listWorkspaceRepos, run } from "../../../src/workspaceRepos.ts";

type Issue = {
  number: number;
  title: string;
  body?: string;
  url: string;
  labels: Array<{ name: string }>;
};

const main = async (): Promise<void> => {
  const projects = await listWorkspaceRepos();
  if (!projects.length) return;

  for (const project of projects) {
    const number = await run(
      "gh",
      [
        "issue",
        "list",
        "--search",
        "label:ai no:assignee state:open",
        "--limit",
        "1",
        "--json",
        "number",
        "--jq",
        ".[0].number // empty",
      ],
      project.directory,
    );
    if (!number) continue;

    const user = await run("gh", ["api", "user", "--jq", ".login"]);
    await run(
      "gh",
      ["issue", "edit", number, "--add-assignee", user],
      project.directory,
    );
    const issue = JSON.parse(
      await run(
        "gh",
        ["issue", "view", number, "--json", "number,title,body,url,labels"],
        project.directory,
      ),
    ) as Issue;
    console.log(
      JSON.stringify({
        issue: {
          ...issue,
          project: project.name,
          repositoryUrl: project.repositoryUrl,
          body: issue.body ?? "",
          labels: issue.labels.map(({ name }) => name),
        },
        assignedTo: user,
      }),
    );
    return;
  }
};

await main();
