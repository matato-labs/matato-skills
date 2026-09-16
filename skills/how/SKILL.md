---
name: how
description: Use this skill when the user wants to know how something works in a codebase
disable-model-invocation: true
---

The task is to review the user's request and provide a specific answer about how something works in a codebase. You need to read the code and never invent things; all answers need to be backed by evidence of what the actual code does.

A user request can be categorized in two ways: simple and complex. You need to do a first run and determine which route to take.

## Simple
The user's question can be answered by reading part of the code and doesn't require a complex analysis. Launch one subagent to do the analysis.

## Complex
The user's question needs to be answered only after a deep analysis. You need to gather some groundwork before passing on the investigation. Try to find files, classes, modules, functions, or any other code artifact and formulate different ideas you want to explore. Launch up to 4 subagents, each to investigate different routes.

## Output
When all investigations are done and you have a better overview, draft the answer to the user. Get to the point as if you are talking to a senior software engineer. Make any answer concise. Sacrifice grammar for the sake of concision.
