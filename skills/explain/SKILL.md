---
name: explain
description: Use this skill when the user wants to fully understand something.
disable-model-invocation: true
---

Explain is a companion for `how` and `why`, let those skills do the investigation and you use the result to build a slow and comprehensive explanation for the user. If `how` and `why` ran already in this session, use that, if not launch subagents as you believe appropriate to run those skills.

Build up an incremental and digestible explanation for the user request following the next criteria:

1) Keep it simple, go to the point and avoid complex and long sentences.
2) Add evidence, code snapshots, sources or anything to allow the user to understand `where` something happens
3) Draw diagrams, charts or any visual artifact to help the user to understand `how` it works
4) When the user wants to know when it was changed or the business reason behind, add tickets, issues, docs, commits, pr or any external source to explain why.

