---
name: pr-comment-solver
description: Use this skill when prompted to solve all comments in a PR. You must only work on the target project.
---

# PR Review

When using `gh` for PR commands, inline comments, review threads, or payloads, follow the exact commands and examples in the `ghcli` skill. Do not invent custom `gh` flags or GraphQL fields.

## Task
Use the prepared branch, persisted pull request URL, and pre-script result to read the changes and comments prefixed with `AGENT:`. Understand what the requested changes are about, then implement them.

After you apply the requested changes, and after the change is pushed to the branch, resolve the GH comment so the next iteration doesn't pick it up again.

### Closed PRs
If the PR is already closed or merge you need get out of the loop with matato-cli skill.
