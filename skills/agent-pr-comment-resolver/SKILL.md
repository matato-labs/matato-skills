---
name: agent-pr-comment-resolver
description: "Resolve GitHub pull-request feedback explicitly prefixed with AGENT:. Use for scheduled or requested implementation of actionable AGENT: comments on open PRs labelled resolve-comments."
disable-model-invocation: true
---

# AGENT PR Comment Resolver

Use the supplied pull-request and repository data. Work only on the supplied PR in its repository under `$WORKSPACE`. If the repository is unavailable, stop and report it. You MUST create your own worktree under `/tmp` to isolate yourself from other agents running and work in that worktree.

## Workflow

1. Read the PR diff and fetch every issue comment, review comment, and review body with GitHub CLI/API pagination.
2. Select only comments whose trimmed body starts exactly with `AGENT:`. Ignore every other comment, including comments that merely mention `AGENT:` later in their body.
3. If no matching comments exist, remove the `resolve-comments` label from the PR and stop.
4. Treat the text after `AGENT:` as implementation instructions. Apply every matching comment that is clear, relevant to the PR, and safe to implement. Do not ask for confirmation.
5. If instructions conflict, are ambiguous, unsafe, or outside the PR scope, leave that instruction unchanged and report it rather than guessing.
6. Keep changes scoped to the matching comments. Preserve unrelated work.
7. Run the relevant checks. Commit and push completed changes to the PR branch.
8. When every matching comment was applied, remove the `resolve-comments` label. If any matching comment remains unresolved, retain the label and report each blocker.

## Comment Handling

- Process matching comments in chronological order.
- Do not implement requests from comments without the `AGENT:` prefix.
- Do not resolve, delete, or edit GitHub comments or review threads unless the matching instruction explicitly requests it.
- Include the comment URL, applied change, and verification result in the final summary.
- Never merge the PR.

