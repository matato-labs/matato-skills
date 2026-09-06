---
name: mutation-testing-review
description: Perform manual mutation testing as an explicit specialist used by $change-gate.
disable-model-invocation: true
---

# Mutation Testing Review

> This is a MANUAL TEST; There is no mutation testing frame work, you need to do the changes your self and run the test, once case at a time.

Identify the meaningful behavioral changes and the tests that cover them. Work through one mutation at a time. Choose small, plausible defects that exercise the changed behavior, such as inverted conditions, changed comparison operators, altered boolean values, removed guards, changed return values, or altered boundary values.

For each mutation:

1. Confirm the relevant test command and run the focused test once against the unmodified branch.
2. Apply exactly one temporary source mutation.
3. Run the focused test.
4. Restore the source immediately, whether the test passes or fails, and verify the working tree no longer contains that mutation before continuing.
5. If the test fails, record the mutant as killed and move to the next mutation.
6. If the test passes, record the mutant as survived. Add or improve a test that expresses the missing behavior, run it against the restored source to confirm it passes, reapply the same temporary mutation, and confirm the improved test now fails. Restore the source again before continuing.

Do not make speculative production-code changes to satisfy a surviving mutation. A surviving mutation is normally a missing or incomplete test scenario; only change production code if the investigation reveals a real defect in the pull request. Keep any test improvements that are needed, but never commit, push, or modify the pull request unless the workflow explicitly authorizes it.

When you are done, reply to the orchestrator agent with a small summary and the state of your work.
