---
name: coding-session
description: Use this skill when the user asks you to code on one of the target projects
disable-model-invocation: true
---

# Task Implementation

When invoked, use the supplied issue or information and repository data. Given a plan from a ticket, GH Issue, or user's prompt, you must implement the changes in the target repository the user provides. You MUST always create a worktree under `/tmp` to isolate yourself from other agents running in the same repository and do the changes in that worktree.

Understand the code involved in the user change. Decide the implementation approach yourself, then analyse the files that need to be changed and the code surrounding those files that impacts the change in the overall architecture and E2E workflow. Do not limit your scope to the most obvious files.

The tests need to cover all cases and be based on the business impact following a BDD approach. Define a testing case and acceptance criteria to draft the test. There are times when the changes are purely technical, in such cases you don't need to follow up BDD.

Before creating the PR, decide whether the completed change has a runnable, user-visible UI or browser flow worth reviewing. This includes rendered pages, LiveViews, forms, interactive browser behavior, and visual styling. Do not mark backend-only, documentation-only, infrastructure-only, or non-runnable changes.

Create one PR with `gh` and add a label `ai-validation`, if the label does not exist, create it and then add it to the PR. For a change suitable for UI testing, create the `AI review` label if it does not exist and add it to the PR. Commit the changes and push to the PR.
