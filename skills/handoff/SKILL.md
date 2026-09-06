---
name: handoff
description: Use $handoff to capture this session into a compact restart handoff that can be used as input for a new session.
disable-model-invocation: true
---

# Handoff

Handoff is a skill that enables the user to take all work in the current session, compact it in a meaningful way, and preserve objectives, changes, errors, and state. The output should not omit important details that could be required to work in a new session.

## Core Rule

Build the handoff from verified information:

- the current user request and accepted direction
- files, plans, and artifacts that exist in the workspace
- the current git/worktree state when relevant
- concrete decisions already made in this session
- blockers, risks, and unanswered questions that still matter

Do not invent progress, decisions, or next steps that are not supported by the session or the workspace.

## What To Capture

Always capture these sections:

1. Objective: what the user is trying to achieve right now
2. Current state: what is already done and what remains
3. Important decisions: choices, assumptions, and constraints that shaped the work
4. Files and artifacts: important file paths, docs, tickets, branches, commands, or outputs that the next session should inspect first
5. Open issues: blockers, uncertainties, missing approvals, or pending validations
6. Next steps: the smallest correct sequence for resuming work

## Verification Workflow

Before writing the handoff:

1. Re-read the latest user goal and your current in-flight plan.
2. Inspect the relevant workspace state instead of relying only on memory.
3. Check touched files, generated artifacts, and git status when they matter.
4. Separate verified facts from inferred conclusions.

If a detail is uncertain but still important, mark it clearly as `Needs verification`.

## Output Style

Produce a concise markdown handoff that is optimized for a new session.

Prefer:

- direct facts over narrative recap
- concrete file paths over vague references
- explicit next actions over generic advice
- compact wording over exhaustive history

Avoid:

- long chronological summaries
- repeated background that can be recovered from files
- low-signal chat details
- speculation presented as fact

## Default Format

Use this structure unless the user asks for a different one:

```md
# Handoff

## Objective

## Current State

## Important Decisions

## Files And Artifacts

## Open Issues

## Next Steps
```

## Optional File Output

If the user asks for a file, or if a persistent handoff note would clearly help, write the handoff to a markdown file in the workspace. If no path is specified, propose a concise path such as `handoff.md` or a project-specific note name.

If the user only asks for the handoff content, return it in the chat without forcing a file.
