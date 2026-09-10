---
name: coding-session
description: Use this skill when the user asks you to code on one of the target projects
disable-model-invocation: true
---

# Task Implementation

When invoked, use the supplied issue and repository data. Given a plan from a ticket, GH Issue, or user's prompt, you must implement the changes in the target repository the user provides. Create a worktree to isolate yourself from other agents running in the same repository. Understand the code involved in the user change. Decide the implementation approach yourself, then analyse the files that need to be changed and the code surrounding those files that impacts the change in the overall architecture and E2E workflow. Do not limit your scope to the most obvious files.

## Testing

The tests need to cover all cases and be based on the business impact following a BDD approach. Define a testing case and acceptance criteria to draft the test. There are times when the changes are purely technical, in such cases you don't need to follow up BDD.

## Last Step

Create one PR with `gh` and add a label `ai-review`, if the label do not exist, create it and then add it to the PR, commit the changes and push to the PR.

- **DO NOT** merge anything to main — a human must review the PR.
