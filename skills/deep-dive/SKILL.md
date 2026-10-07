---
name: deep-dive
description: Use this skill when the user wants to know how something works in a codebase or has a really presice question
disable-model-invocation: true
---

The task is to review the user's request and provide a specific answer regarding the user's question; the user could also ask `how does this component work in the codebase?`, `are there tests that cover this scenario?`, etc. You need to read the code and never invent things; all answers need to be backed by evidence of what the actual code does.

A user request can be categorized in two ways: simple and complex. You need to do a first run and determine which route to take.

## Simple
The user's question can be answered by reading part of the code and doesn't require a complex analysis. Launch one subagent to do the analysis.

## Complex
Give a quick analysis first; try to find files, classes, modules, functions or any code artifact and identify different branches that are worth exploring; for each branch, launch a sub-agent that will do a deep-dive and come back with a conclusion; they need to work until the branch's theory is proven or disproven.

## Output
When all investigations are done and you have a better overview, draft the answer to the user. Make any answer concise. Sacrifice grammar for the sake of concision.
