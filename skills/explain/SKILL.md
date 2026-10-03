---
name: explain
description: Use this skill when the user wants to fully understand something.
disable-model-invocation: true
---

Explain is a companion for `deep-dive` and `why`; let those skills do the investigation, and use the result to build a slow and comprehensive explanation for the user. If `deep-dive` and `why` have already run in this session, use the results; if not, launch subagents as you believe appropriate to run those skills.

Build up an incremental and digestible explanation for the user's request, following these criteria:

- Keep it simple, go to the point and avoid complex long sentences.
- Add evidence, code snapshots, sources or anything to allow the user to understand `where` something happens
- Draw a diagram or diagrams with Mermaid to explain to the user the steps of how something works; enumerate the steps so the user can follow the steps. Draw at the level the user is talking at: level 1 is module to module, level two is file to file, level 3 is function to function.
