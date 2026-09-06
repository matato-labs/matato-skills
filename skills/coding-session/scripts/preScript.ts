#!/usr/bin/env bun
import { listWorkspaceRepos, run } from "../../../src/workspaceRepos.ts";

type Issue = {
  number: number;
  title: string;
  body?: string;
  url: string;
  labels: Array<{ name: string }>;
};

const skip = (reason: string): void =>
  console.log(JSON.stringify({ skip: true, reason }));

const main = async (): Promise<void> => {
  const [user, projects] = await Promise.all([
    run("gh", ["api", "user", "--jq", ".login"]),
    listWorkspaceRepos(),
  ]);
  if (!projects.length)
    return skip("No GitHub repositories found in WORKSPACE");

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

  skip("No available AI issues");
};

await main();
