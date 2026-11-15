---
name: diagrams
description: Explain system flows with one or two deep Mermaid diagrams.
disable-model-invocation: true
---

# Diagrams

Use `$deep-dive` and `$why` to investigate; use this output format. Delegate branches when allowed; otherwise investigate directly. Wait and reconcile findings. Never invent behavior or intent.

## Investigation

Define the user's goal, trigger, boundary, and observable outcome. Check requested stages exist; separate absent behavior from external unknowns. Trace code, tests, and history through entry points, decisions, state, storage, external effects, and the user result. Trace async completion or mark its unverified boundary. Include rejection, failure, retry, and recovery paths.

Apply systems thinking: map actors, responsibilities, data/control flows, accumulated state, feedback, delays, and constraints where they exist. Model interactions, not files. Contrast expectations with behavior; separate facts, inference, and unknowns.

## Output

1. State scope and outcome. Give one or two deep Mermaid diagrams in fenced blocks. Use `flowchart` for decisions/state or `sequenceDiagram` for interactions/timing unless requested otherwise. A second diagram must add a distinct view.
2. Share numbered phase IDs across diagrams and evidence. Group responsibilities; mark boundaries, branches, and async handoffs. Distinguish state transitions from scheduled retries; do not imply cross-service atomicity.
3. Explain only non-obvious rules, state, feedback, delays, trade-offs, and failures below the diagrams. Cite `path:line` evidence by phase once. State gaps and exclusions. Verify paths against sources. Parse Mermaid when available; report manual, parsed, or rendered checks honestly.
