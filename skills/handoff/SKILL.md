---
name: handoff
description: Use $handoff to capture this session into a compact restart handoff that can be used as input for a new session.
disable-model-invocation: true
---

# Handoff

This skill still enables the user to take all work in the current session, compact it meaningfully, and preserve objectives, changes, errors, and state. The output should not omit important details that could be required to work in a new session.

Build the handoff from verified information:

- the current user request and accepted direction
- files, plans, and artifacts that exist in the workspace
- the current git/worktree state when relevant
- concrete decisions already made in this session
- blockers, risks, and unanswered questions that still matter
- changes made
- pending changes

Do not invent progress, decisions, or next steps that are not supported by the session or the workspace.

## What To Capture

Always capture these sections:

1. Objective: what the user is trying to achieve right now
2. Current state: what is already done and what remains
3. Important decisions: choices, assumptions, and constraints that shaped the work
4. Files and artifacts: important file paths, docs, tickets, branches, commands, or outputs that the next session should inspect first
5. Open issues: blockers, uncertainties, missing approvals, or pending validations
6. Next steps: the smallest correct sequence for resuming work

## Default Format

Use this structure unless the user asks for a different one:

```md
# Context
What are you doing, why, what has been done

# Next steps
What is missing base on the conversation

# Considerations
What to consider, trade off, important decisions taken

> If `pbcopy`, `wl-copy`, or any similar tool is available in the system, copy the handoff to the clipboard.
