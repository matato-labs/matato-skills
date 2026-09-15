---
name: task-implementation
description: Use this skill when the user asks you to code on one of the target projects
disable-model-invocation: true
---

# Task Implementation

Given a plan from a ticket, GitHub issue, or user prompt, you must implement the changes in the target repository that the user provides. Understand the code involved in the user's change. Decide the implementation approach yourself, then analyse the files that need to be changed and the code surrounding those files that impact the change in the overall architecture and E2E workflow. Do not limit your scope to the most obvious files.

## Testing

The tests need to cover all cases and be based on the business impact, following a BDD approach. Define the test cases based on acceptance criteria. There are times when the changes are purely technical; in such cases, you don't need to follow BDD.

## Output

Commit and push completed changes to the prepared branch. When no pull request exists, call `createPullRequest` with a useful title and body. When one already exists, push updates to the same branch without creating another. Report the implementation and verification evidence.

