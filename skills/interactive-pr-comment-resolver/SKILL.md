---
name: interactive-pr-comment-resolver
description: Use when a user asks you to resolve comments in a PR.
disable-model-invocation: true
---

Use this skill to implement PR feedback with the user's participation. Read the PR and identify what changed relative to the PR base branch. Evaluate how each comment affects the codebase. Discuss the comments with the user one at a time. For each comment, explain its meaning and identify its author. Explain whether to apply or challenge it, why, and what action to take next. Wait for user approval or discussion before acting on that comment.

## Working Assumptions

- The user must provide the PR URL.
- You may start in the repository folder or elsewhere. If you start elsewhere, clone the repository to a temporary folder and work there.

## Workflow

Briefly examine the PR to understand the changes and their impact. Do not do a detailed code review. Read comments in chronological order. Understand how each comment affects the PR. Decide whether the comment is relevant and choose `apply`, `challenge`, or `evaluate`.

### Apply

When you suggest applying the change stated in a comment, wait for the user's response. The user will approve the changes or ask more questions. Apply the changes only if the user allows you to do so. Always wait for their feedback.

### Challenge

When you challenge a comment, explain exactly why the challenge is important. Support the explanation with facts. The user may ask follow-up questions or request clarification.

### Evaluate

Choose `evaluate` when you are not sure what to do and need to discuss the change and the comment with the user. Give the user the information needed for that discussion.

## Interactive Loop Rules

- Do not present all comments at once unless the user explicitly asks for a batch summary.
- Present one comment at a time to avoid overloading the user.
- Keep each comment summary short and focused on the decision.
- State both the proposed action and the reason before asking the user to approve it.
- If the user disagrees, discuss only that comment until the next action is clear.
- Do not continue to the next comment without discussion after a disagreement or unresolved question.
- If several comments share the same underlying issue, you may mention that context. Keep the discussion focused on the current comment.

## Local Change Rules

- Limit changes to the review feedback.
- Preserve unrelated user work in the branch.

## Output Contract

During the loop, give the user a concise prompt for each comment. Include these fields:

- `Comment`: Give a short description of the feedback.
- `Summary`: State what the reviewer requests.
- `Disposition`: Choose `apply`, `challenge`, or `evaluate`.
- `Why`: Explain the decision with reference to the code, the diff, and the impact on the codebase.
- `Proposed action`: State the exact next step for this comment only.
- `Awaiting`: Explicitly ask for user approval or discussion before acting.

After the user approves and you complete the action, give a short outcome for the same comment before you continue. Include these fields:

- `Result`: State what you changed locally or what challenge text you prepared or posted.
- `Why`: Briefly confirm that the action matches the approved plan.

If you challenge a comment, explicitly state why it is not valid in the current PR context. Use a factual tone suitable for a review response so the user can decide whether to respond in GitHub.

## Suggested Response Shape

Use a compact structure similar to this:

- `Comment`: Extract validation into a shared helper.
  `Summary`: The reviewer wants to move duplicated validation out of two call sites.
  `Disposition`: apply
  `Why`: The diff introduced the duplication. The codebase already has a suitable location for the helper.
  `Proposed action`: Move the validation into `foo/bar.ts`, update both callers, then re-run the affected tests.
  `Awaiting`: Approve this plan or tell me what to change in the plan before I change the code.

- `Comment`: Rename the field `targetBranch` to `baseBranch`.
  `Disposition`: challenge
  `Summary`: The reviewer requests a rename to make the branch naming more explicit.
  `Why`: The PR already distinguishes the GitHub base branch from the deployment target branch. The requested rename would reduce clarity.
  `Proposed action`: Do not change the code. Draft a short reply explaining why the current naming is intentional.
  `Awaiting`: Approve this challenge or tell me how you want to respond.

## Failure Modes

- If no PR is associated with the branch, stop and tell the user.
- If you cannot read comments, stop and report the missing capability or authentication problem.
- If the working tree has unrelated uncommitted changes that make the review unsafe, warn the user before proceeding.
- If a comment requires you to understand product intent or reviewer intent that you cannot safely infer, challenge it instead of guessing.
- If the user stops the loop before the review is complete, summarize the comments you handled. Clearly mark the remaining comments as pending.
