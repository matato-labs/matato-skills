---
name: gathering
description: Turn a rough feature idea into a clear brief and implement it. Ask one question at a time before coding.
disable-model-invocation: true
---

# Gathering

The user will use this when they do not have a clear idea of how to build something or when the idea is too big to put into words. Your task is to help the user examine the idea until all questions are answered and all doubts are resolved.

Read the user's initial idea and use `deep-dive` and `why` to navigate the code and identify the parts that can be used in the feature. Gather all questions that still need answers.

Ask the user one question at a time. Preferably, provide options A), B), and C), unless you have no idea how to proceed.

## Exit

The session will finish when you have enough information to do the work or the user says so.

## Output

The output is an explanation of how the feature will be built. Use `explain-extensive` to generate the output. Save the output in `/docs/adrs`.
