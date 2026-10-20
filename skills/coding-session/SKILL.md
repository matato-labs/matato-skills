---
name: coding-session
description: Use this skill when the user asks you to work on code in one of the target projects.
disable-model-invocation: true
---

# Task Implementation

Use the supplied issue or information and the repository data. Given a plan from a ticket, GitHub issue, or user prompt, implement the changes in the target repository provided by the user. You MUST always create a worktree under `/tmp` to isolate your changes from other agents working in the same repository. Make the changes in that worktree.

Use ponytail for coding and testing-quality for testing.
