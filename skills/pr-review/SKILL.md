---
name: pr-review
description: Use this skill when prompted to run the pr-review routine. It monitors open pull requests across tracked projects and reviews the changes.
---

# PR Review

> When using `gh` for PR commands, inline comments, review threads, or payloads, follow the exact commands and examples in the `ghcli` skill. Do not invent custom `gh` flags or GraphQL fields.

## Task
Use the prepared workspace and repository context, including the persisted pull request URL when present, to understand the changes deeply and perform a great code review.

The PR review has 3 main parts:

**Correctness**: The changes do what the requirements say. Are all cases covered? Are all cases implemented correctly? Is everything tested correctly?
**Simplicity**: Code and architecture must be simple, with easy solutions instead of overengineered solutions. The code must follow SOLID principles. Files should be short, no more than 600 lines or 4 nested levels.
**Security**: (there are projects that don't require security) Security is a big concern. There should not be unauthenticated endpoints, it should not expose user data, it should not log user data, it should not expose secrets or log secrets, and authentication and authorisation must be handled well.

Do not limit yourself only to the 3 points or what is mentioned in them. Expand as much as you believe is needed.

When you are done with the review, comment in the PR on the corresponding line with each one of your findings. Prefix every comment with `AGENT: {}`

## Output
Return the actionable findings and review evidence. Do not force a rigid template.

Write with direct wording. Use short sections or bullets only where they make the handoff clearer. Avoid placeholder fields, long templates, and generic advice.
