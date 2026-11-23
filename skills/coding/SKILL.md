---
name: coding
description: Implement, fix, or refactor code with the smallest complete change. Use for coding tasks that edit code, not for read-only change reviews or repository audits.
---

# Coding

Solve the requested problem, not the surrounding problems. If a proposed mechanism adds cost without serving the need, explain why and use the smaller solution if it still satisfies the request. Do not drop an explicit requirement. Ask only when different interpretations would change the result and the code does not resolve them.

## Find the existing path

- State the required behavior and what must stay the same. Find the entry point, owning rule, callers, and nearest tests. Follow the failing input through the real path for a bug; fix the common cause, not each symptom.
- Inspect the closest working example before designing anything. Look for the same operation, framework conventions, test fixtures, and dependencies already in use. Read the behavior of a helper before reusing it; similar names do not guarantee the same contract.

## Make the smallest complete change

- First ask whether deleting, narrowing, or changing an existing operation solves the task. Then prefer a matching local helper or framework pattern, an idiomatic language or standard-library operation, or a dependency already declared for this package. Add code only for behavior those paths do not provide.
- Keep the project's error, state, and data flow. Use native types and framework lifecycle hooks where they fit. Do not add a wrapper, flag, new dependency, public API, or general-purpose abstraction unless the behavior needs it. Do not widen the diff for formatting or nearby cleanup.
- Optimize for fewer concepts and fewer places to change, not fewer characters. Preserve caller contracts, validation, accessibility, and error handling unless the request explicitly changes them.

## Prove it

For changes to application behavior, extend the nearest suitable test at the public boundary. Name a plausible wrong implementation that could pass a happy-path test. Pick an input that distinguishes it from the correct behavior: make values that could be confused disagree, or exercise both scopes if a helper serves changed and unchanged callers. Do not add cases that only repeat existing coverage.

Run the focused check against the original and the fix when practical. For skill instructions, prose, or metadata, use relevant existing validators instead of adding dedicated tests. Run the relevant project checks. Before finishing, read the diff and remove anything that neither delivers nor verifies the requested behavior.

Say what changed, how you checked it, and any important check or risk that remains. Do not claim a check passed unless it ran.
