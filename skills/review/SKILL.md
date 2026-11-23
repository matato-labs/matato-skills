---
name: review
description: Review a patch, branch, commit, or pull request for bugs, regressions, missing tests, and unnecessary complexity. Use for read-only reviews of changes, not whole-repository audits.
---

# Review

Review the named change. If none is named, review uncommitted changes or the last commit if the tree is clean. Use read-only inspection and report findings. Do not edit files, change system or repository state, or publish results. Assess security defects by tracing code and existing evidence, not by developing exploits, reproducing vulnerabilities, or running offensive tests.

## Check the contract, not just the diff

- Identify the requested outcome and what callers could rely on before the change. Trace changed behavior from its entry point through helpers, storage or side effects, and return values. Find callers, tests, and the nearest implementation of the same operation.
- Compare old and new outcomes for a concrete input, failure, or execution order. Prioritize wrong results, broken callers, lost data, weakened security, and failure at the expected load. Use the repo's deploy configuration or docs for load assumptions; state an assumption only when it affects a finding.
- Check that tests cover the new outcome and the regression most likely to matter. Look for a test that could pass despite the bug. Report a missing test only when you can name the application behavior it would protect. Do not require dedicated tests for skill instructions, prose, or metadata.

## Challenge the extra code

Ask what each new branch, dependency, abstraction, and option buys. Identify code that can go away without losing behavior. Name the matching local helper, idiom, framework feature, or installed dependency when one makes the fix smaller. Check that it preserves contracts and error handling. Do not ask for a preference-based rewrite.

## Triage and report

Keep a finding only if the changed code supports it. Give the file and line, the case that reaches it, the consequence, and the smallest complete fix. Verify upstream guards and downstream behavior before assigning severity. Separate pre-existing problems from regressions; leave unrelated issues out. Do not treat a documented trade-off as a bug unless a real requirement crosses its limit.

Start with a short description of the change. Rank findings by impact: **Must fix** for broken behavior or material safety risk; **Should fix** for a concrete test, performance, or maintenance cost; **Nice to have** only for a verified small saving. Number findings and omit empty groups. End with a ship or fix-first verdict and any material checks you could not do. If there are no findings, say what you checked.
