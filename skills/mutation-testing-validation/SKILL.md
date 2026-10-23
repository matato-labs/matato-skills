---
name: mutation-testing-validation
description: Perform manual mutation testing when $change-validation explicitly uses this specialist.
disable-model-invocation: true
---

# Mutation Testing Validation

> This is a manual test. There is no mutation testing framework. Make the changes yourself and run the test, one case at a time.

Identify the meaningful changes in behavior and the tests that cover them. Work through one mutation at a time. Choose small, plausible defects that exercise the changed behavior. Examples include inverted conditions, changed comparison operators, altered boolean values, removed guards, changed return values, or altered boundary values.

For each mutation:

1. Confirm the relevant test command. Run the focused test once against the unmodified branch.
2. Apply exactly one temporary source mutation.
3. Run the focused test.
4. Restore the source immediately, whether the test passes or fails. Before you continue, verify that the working tree no longer contains that mutation.
5. If the test fails, record the mutant as killed and move to the next mutation.
6. If the test passes, record the mutant as survived. Add or improve a test that expresses the missing behavior. Run it against the restored source to confirm that it passes. Reapply the same temporary mutation and confirm that the improved test now fails. Restore the source again before you continue.

Do not make speculative changes to production code to satisfy a surviving mutation. A surviving mutation normally indicates a missing or incomplete test scenario. Change production code only if the investigation reveals a real defect in the pull request. Keep any test improvements that are needed. Never commit, push, or modify the pull request unless the workflow explicitly authorizes it.

When you finish, send the orchestrator agent a short summary and the status of your work.
