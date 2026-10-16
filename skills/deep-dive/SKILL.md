---
name: deep-dive
description: Use this skill when the user wants to know how something works in a codebase or has a very precise question.
disable-model-invocation: true
---

Review the user's request and give a specific answer to the question. For example, the user could ask `how does this component work in the codebase?` or `are there tests that cover this scenario?`. Read the code. Never invent information. Support every answer with evidence of what the code actually does.

Do an initial investigation. Classify the user's request as simple or complex, then use the corresponding workflow.

## Simple
Use this workflow when you can answer the user's question by reading part of the code without complex analysis. Launch one subagent to do the analysis.

## Complex
Give a quick analysis first. Look for relevant files, classes, modules, functions or other code artifacts. Identify investigation branches worth exploring. For each branch, launch a subagent to investigate in detail and return a conclusion. Each subagent must continue until it proves or disproves the branch's theory.

## Output
When all investigations are complete and you understand the findings, draft the answer to the user. Use short, complete sentences and active voice. Use the same term for the same concept. Give direct instructions. Avoid idioms and unnecessary words. Preserve technical accuracy, code, commands, and identifiers. Do not sacrifice grammar for brevity.
