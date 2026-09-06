---
name: gh-pr-comment-resolver
description: Use when a user asks you to resolve the comments in a PR.
disable-model-invocation: true
---

Use this skill to turn PR feedback into an interactive implementation pass. Read the PR, understand what changed relative to the PR base branch, evaluate the codebase impact of each comment, and then walk the user through comments one by one. For each comment, explain what it means, the author, whether it should be applied or challenged, why, and what the next action would be. Wait for user approval or discussion before acting on that specific comment.

## Required Dependency

- gh: GitHub CLI

## Working Assumptions

- The user needs to provide the PR URL.
- You could be placed in the repository folder, but you could be placed somewhere else; in this case, clone the repository to a temp folder and work there.

## Workflow

Take a quick look at the PR to understand the changes and their impact, but do not do a deep code review. Read comments in chronological order and make sure you understand the impact of the comment in the PR. Decide if the comment is relevant and choose `apply`, `challenge`, or `evaluate`.

### Apply

When you suggest applying a change as stated in a comment, you need to wait for the user's response. The user will let you know if they agree to apply the changes or will start asking further questions. Only apply the changes in the comment if the user allows you to do so; ALWAYS wait for their feedback.

### Challenge

When doing a challenge, specify exactly why it is important to challenge this comment with factual data points. The user may ask follow-up questions or request clarifications.

### Evaluate

Evaluate is an option to talk to the user about the change and the comment when you are not sure what to do. Provide the user with the information required to follow a conversation about it.

## Interactive Loop Rules

- Never dump all comments at once unless the user explicitly asks for a batch summary.
- Present one comment at a time to avoid overloading the user.
- Keep each comment summary short and decision-oriented.
- State both the proposed action and the reason before asking the user to approve it.
- If the user disagrees, discuss only that comment until a direction is clear.
- Do not silently continue to the next comment after a disagreement or open question.
- If several comments share the same root issue, you may mention that context, but still anchor the conversation on the current single comment.

## Local Change Rules

- Keep changes tightly scoped to the review feedback.
- Preserve unrelated user work in the branch.

## Output Contract

During the loop, for each single comment, give the user a concise prompt with:

- `Comment`: short description of the feedback
- `Summary`: what the reviewer is asking for
- `Disposition`: `apply`, `challenge`, or `evaluate`
- `Why`: rationale tying the decision back to the code, diff, and codebase impact
- `Proposed action`: the exact next step for this comment only
- `Awaiting`: explicit request for user approval or discussion before acting

After the user approves and the action is completed, give a short outcome for that same comment before moving on:

- `Result`: what was changed locally or what challenge text was prepared or posted
- `Why`: short confirmation that the action matches the approved plan

If challenging a comment, explicitly state why it is not valid in the current PR context. Keep the tone factual and review-ready so the user can decide whether to respond in GitHub.

## Suggested Response Shape

Use a compact structure similar to this:

- `Comment`: Extract validation into shared helper
  `Summary`: The reviewer wants duplicated validation moved out of two call sites.
  `Disposition`: apply
  `Why`: The diff introduced the duplication and the helper already has a natural home.
  `Proposed action`: Move the validation into `foo/bar.ts`, update both callers, then re-run the affected tests.
  `Awaiting`: Approve this plan or tell me what you want changed before I touch the code.

- `Comment`: Rename field `targetBranch` to `baseBranch`
  `Disposition`: challenge
  `Summary`: The reviewer is asking for a rename to make the branch naming more explicit.
  `Why`: The PR already distinguishes GitHub base branch from deployment target branch, so the requested rename would reduce clarity.
  `Proposed action`: No code change. Draft a short reply explaining why the current naming is intentional.
  `Awaiting`: Approve this challenge or tell me how you want to respond.

## Failure Modes

- If no PR is associated with the branch, stop and tell the user.
- If comments cannot be read, stop and report the missing capability or auth problem.
- If the working tree has unrelated uncommitted changes that make the review unsafe, warn the user before proceeding.
- If a comment requires product or reviewer intent that cannot be inferred safely, challenge it instead of guessing.
- If the user stops the loop mid-review, summarize the handled comments and clearly mark the remaining ones as pending.
