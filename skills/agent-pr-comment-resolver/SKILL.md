---
name: agent-pr-comment-resolver
description: "Resolve GitHub pull-request feedback that starts with AGENT:. Use for scheduled or requested work to implement actionable AGENT: comments on open PRs labelled resolve-comments."
disable-model-invocation: true
---

# AGENT PR Comment Resolver

Use the supplied pull-request and repository data. Work only on the supplied PR in its repository under `$WORKSPACE`. If the repository is unavailable, stop and report it. You must create your own worktree under `/tmp` to keep your work separate from other running agents. Work in that worktree.

## Workflow

1. Read the PR diff. Use GitHub CLI/API pagination to fetch every issue comment, review comment, and review body.
2. Select only comments whose trimmed body starts exactly with `AGENT:`. Ignore every other comment, including comments that merely mention `AGENT:` later in their body.
3. If no matching comments exist, remove the `resolve-comments` label from the PR and stop.
4. Treat the text after `AGENT:` as implementation instructions. Apply every matching comment that is clear, relevant to the PR, and safe to implement. Do not ask for confirmation.
5. If an instruction conflicts with another instruction, is ambiguous, is unsafe, or is outside the PR scope, leave it unchanged. Report it instead of guessing.
6. Limit changes to the matching comments. Preserve unrelated work.
7. Run the relevant checks. Commit and push completed changes to the PR branch.
8. When you have applied every matching comment, remove the `resolve-comments` label. If any matching comment remains unresolved, keep the label and report each blocker.

## Comment Handling

- Process matching comments in chronological order.
- Do not implement requests from comments without the `AGENT:` prefix.
- Do not resolve, delete, or edit GitHub comments or review threads unless the matching instruction explicitly requests it.
- In the final summary, include the comment URL, the change you applied, and the verification result.
- Never merge the PR.

