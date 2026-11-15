---
name: testing-qualityv2
description: Check that a change has meaningful business tests with minimal maintenance. Use before writing tests or when reviewing a change, branch, or PR.
---

# Testing Quality v2

Analyze the supplied change. Read the request, diff, affected callers, and nearby tests. Identify the user-visible outcome and the regression that would break it.

## Testing

- Do not add or extend tests for scripts in any language, skills, prompts, prose, CI, configuration, or package metadata. This includes existing tests, temporary harnesses, inline assertions, content checks, and snapshots.
- For excluded-only changes, review the diff and use relevant existing syntax checks, validators, linters, or builds. Explain why no test change is needed. Do not run destructive scripts, credential transfers, deployments, or external writes.
- For mixed changes, test changed application behavior, not excluded artifacts. Application logic that reads configuration or processes prompts still needs business tests. Do not extract excluded logic just to test it.
- Extend an existing business scenario first. Add a case only for distinct preconditions or outcomes, or when extension would obscure the scenario. Explain why reuse is insufficient; a new test file is a last resort.
- Reuse project fixtures, utilities, and conventions. Follow given/when/then. Do not introduce layered factories or helpers for one small change.
- Exercise the nearest public business boundary. Assert results and relevant stored state. After rejection, verify unchanged storage, not just empty search results. Keep the business rule real; mock external boundaries only.
- When rejection must explain a restriction, assert the field and cause without pinning the complete message.
- Select normal and changed failure/boundary scenarios from real risk. Avoid duplicate layers, unrelated parameter rows, and unrelated workflows. Test count and coverage percentage are not goals.
- Use independent expected values, not the production transformation such as `input.trim()`. Do not substitute source checks, private helper assertions, mock call counts, or implementation snapshots for business evidence.
- Technical tests need a concrete security, data integrity, compatibility, or performance risk. Classify application code by role, not path; excluded artifacts remain excluded.

## Output

Run repository-required checks and the smallest relevant tests. For regressions, show fail-before/pass-after when practical and restore the fix. Never report an unrun check as passed.

Report the business outcome, test extended or reason for a new case, exact commands and results, exclusions, blockers, and unverified behavior. In review-only work, report findings without edits. Do not demand tests for unchanged behavior or unrelated cleanup.
