---
name: explain
description: Use this skill when the user wants to fully understand something.
disable-model-invocation: true
---

Use Explain with `deep-dive` and `why`. Let those skills do the investigation. Use the results to give the user a gradual, comprehensive explanation. If `deep-dive` and `why` have already run in this session, use their results. Otherwise, launch subagents as appropriate to run those skills.

Build the explanation in small, clear steps. Address the user's request and follow these criteria.

- Keep the explanation simple and direct. Avoid long, complex sentences.
- Add evidence, code snapshots, sources or other material that helps the user understand `where` something happens.
- Draw one or more Mermaid diagrams to show how something works. Number the steps so the user can follow the sequence. Use the level of detail in the user's request. Level 1 shows module-to-module steps. Level 2 shows file-to-file steps. Level 3 shows function-to-function steps.

