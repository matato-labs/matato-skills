---
name: testing-qualityv2
description: Review or improve tests for a change using business outcomes, existing scenarios, and minimal test maintenance. Use before writing tests or when reviewing a diff, branch, or PR. Excludes tests for scripts, prose, CI, and configuration.
---

# Testing quality v2

Choose the smallest test change that proves the changed business behavior. Test count and coverage percentage are not goals.

## Decide what needs a test

Read the request, production diff, affected callers, and nearby tests before changing tests. State the user-visible outcome and the regression that would break it.

Do not add or extend automated tests for scripts in any language; skills, prompts, documentation, or other prose; CI workflows; configuration or package metadata. Do not add file-content assertions, snapshots, or a test harness for these artifacts. This applies to existing tests, temporary files, inline assertion commands, and throwaway harnesses, not just committed tests.

For changes limited to those artifacts, review the diff and use an existing syntax check, linter, validator, or build when relevant. Report that no automated test change is needed and why. Do not execute scripts with destructive effects, credentials, deployments, or external writes just to verify them.

For a mixed change, test the changed application behavior, not the excluded files. Application logic that reads configuration or processes prompts still needs business tests when its behavior changes. Do not move excluded logic into a module just to justify testing it.

## Reuse before adding

Find the existing test that exercises the same business scenario. Extend its inputs or assertions first. Add a new case only when the scenario, preconditions, or expected outcome are materially different, or an extension would obscure the original scenario. Explain why an existing test cannot cover it. A new test file is a last resort.

Reuse the project's fixtures, test utilities, and conventions. Do not introduce layered factories or utility files for one small change. Use readable given/when/then structure without requiring those words as comments.

## Assert outcomes

Exercise the public application boundary nearest the business rule: a service, API, persistence operation, or user interaction. Assert the result the user depends on, including stored state or the absence of side effects after rejection when relevant. If rejection must explain a restriction, check the relevant field and cause, not just that any error occurred. Avoid pinning the complete message wording.

Prefer the normal scenario and the changed failure or boundary scenario. Select cases from the actual risk, not every possible input. Do not repeat the same rule at every layer unless the boundaries have distinct risks. Keep distinct business scenarios clear instead of growing one test into unrelated workflows. Do not expand unrelated parameterized cases just because they share a test.

Do not substitute source-text checks, private helper assertions, mock call counts, or implementation snapshots for business evidence. Mock external boundaries when needed; keep the changed business rule real. Reuse realistic fixtures and derive expected results independently of the implementation. For example, assert that a stored padded name becomes the literal `Daily review`, not `input.trim()` when trimming is the behavior under test.

Technical tests are exceptions. Name the concrete risk, such as credential exposure, data corruption, protocol compatibility, or a required performance limit. Test the observable contract at the narrowest useful boundary. A file under `ci/` or a configuration parser can be application code; classify its role, not just its path. The excluded artifacts themselves remain out of scope.

## Verify and report

Run the smallest relevant existing test command. For a regression fix, show that the changed assertion fails without the production fix when practical. Restore the fix afterward. Do not claim an unrun check passed. Report environment blockers and any behavior left unverified.

Report the business outcome covered, the existing test extended or reason for a new case, the exact check and result, and excluded artifacts intentionally left without test changes. In review-only work, report findings without editing files. Do not demand tests for unchanged behavior or unrelated cleanup of old tests.
