---
name: handoff
description: Use $handoff to capture this session into a compact restart handoff that can be used as input for a new session.
disable-model-invocation: true
---

# Handoff

This skill still enables the user to take all work in the current session, compact it meaningfully, and preserve objectives, changes, errors, and state. The output should not omit important details that could be required to work in a new session.

Build the handoff from verified information and fact and don't invent things that didn't happened in this session.

The output is the prompt to the next agent, write it exactly as you would like to get your initial prompt to start working in something.

> If `pbcopy`, `wl-copy`, or any similar tool is available in the system, copy the handoff to the clipboard.
