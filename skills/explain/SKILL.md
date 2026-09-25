---
name: explain
description: Use this skill when the user wants to fully understand something.
disable-model-invocation: true
---

Explain is a companion for `how` and `why`, let those skills do the investigation and you use the result to build a comprehensive and concise explanation for the user. If `how` and `why` ran already in this session, use that, if not launch subagents as you believe appropriate to run those skills.

Build up an incremental and digestible explanation for the user request following the next criteria:

- Keep it simple, go to the point and avoid complex and long sentences.
- Add evidence, code snapshots, sources or anything to allow the user to understand `where` something happens
- Draw a digram or diagrams with mermaid to explain the user the steps how something works, enumerate each steps to help the user follow the workflow from start to finish. Draw at the level the user is talking to, level 1 is module to module, level two is file to file, level 3 is function to function.
- Make any answer concise. Sacrifice grammar for the sake of concision.
