---
name: break-me
description: Use $break-me to fuzz ordinary feature behavior and fix confirmed bugs.
disable-model-invocation: true
---

Read the contract and tests. Use the smallest boundary that shows the outcome: unit, local app or loopback HTTP. Use disposable copies and state. No live targets or security testing.

Set case and time limits. Seed variations of real fixtures or workflows: typical, boundary and near-invalid cases. Predict results independently of the code. Check output and stored state, including no change on rejection.

Save each failing input or action sequence and seed. Replay from clean state; shrink while preserving the same mismatch. Check setup and the contract before calling it a bug. Show a regression failing before the root-cause fix and passing after. Rerun the original cases, a fresh seed and relevant tests.

Report setup, replay commands, seeds, case counts, expected vs actual, fixes and gaps. Do not commit, push, branch or open a PR without permission.
