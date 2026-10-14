---
name: coding-session
description: Write or change code using the least code and complexity needed to fully satisfy the requirements, without sacrificing readability. Use for implementation, bug fixes and requested refactoring in any language or environment, especially to prevent LLM overengineering, unnecessary abstractions and speculative behavior.
disable-model-invocation: true
---

# Coding session

Implement the whole requirement, not every idea it suggests. Every addition must pay for an observable requirement, necessary integration or concrete regression risk. Fewer lines are useful only when behavior stays correct and readable.

## Establish the boundary

Read the request, affected source and repository instructions. Identify the required behavior, existing behavior that must survive, and the callers, tests, fixtures, exports or configuration that actually need to change. For a bug, find the shared cause and its callers before editing. Ask only about ambiguity that changes correctness; otherwise choose the smallest complete interpretation.

Do not turn this into a new specification, framework or planning document unless requested. A requirement already satisfied needs no implementation.

## Choose less code

Try, in order: no change; changing existing code; an existing project facility; a standard library or platform operation; an installed dependency; direct code. Respect the project's established interfaces and layers. Reuse contracts as well as functions: types, schemas, defaults, validation and error handling. When two required consumers need the same contract, share its existing definition rather than creating parallel declarations or rewriting unrelated fields. Defaults are part of that contract: keep one authoritative definition, not a second set of placeholder defaults. Use existing field-presence facilities for sparse updates rather than rebuilding the model. Extract only the common part actually used now. Check reuse semantics: a similar name is not enough; preserve distinctions such as omitted versus explicitly empty values.

First try changing the existing expression or condition. Do not expand a simple return into several branches or locals when one readable expression keeps the contract. Use guard clauses to remove nesting, not to multiply equivalent exits. Do not compress several responsibilities into a clever one-liner. A helper earns its place through actual reuse or by making necessary logic easier to understand, not by giving one expression a name. Do not add a dependency for a few lines.

Preserve observable distinctions: absent versus empty values, ownership and mutation, ordering, error behavior and public contracts. Keep required copying, validation at untrusted boundaries, synchronization, security, accessibility and protection against data loss. Trust established internal types and guarantees; do not validate them again without a concrete failure they cannot prevent. Recovery, fallback and alternate paths must obey the same required precedence and error contracts as the normal path. Reuse that policy, not a second one.

## Make each addition justify itself

While implementing, ask of each statement, branch, helper, type, option, file, comment and dependency: **What required behavior fails if this is removed?** Keep it only for that behavior, required integration or a concrete regression risk. Apply the same question to generated scaffolding and test setup. A helper or comment may prevent a concrete misreading of necessary logic; speculative future maintenance is not a justification.

Remove invented configurability, fallback behavior, wrappers, conversions, state and defensive checks. Do not add support for inputs, environments or future callers the task does not require. Keep native values in their existing form. Do not bundle nearby cleanup or broaden a bug fix into a rewrite. A comment explains a non-obvious constraint, never narrates the code.

## Finish the smallest complete change

Update every affected integration, not just the obvious function. For new non-trivial behavior, add a focused regression in the existing test framework, or a tiny executable self-check when none exists. Exercise required behaviors in combination where paths interact, not just each requirement in isolation. Reuse fixtures and parameterize equivalent cases instead of copying setup or building a test framework. Add cases for the new failure and distinct contracts it could break; do not re-prove already-covered behavior or exhaust a platform's entire input space. Preserve meaningful assertions; test fewer things only when they are genuinely outside the requirement, not to shrink the diff.

Run the relevant checks. Inspect the whole diff, including caller and test churn, and remove anything without a necessity argument. Do not claim a smaller solution by moving complexity elsewhere, squeezing formatting or deleting safeguards. Do not claim an unrun check passed. Report the change, checks actually run and any remaining limitation briefly; no ceremony
or unsolicited audit report. Stop when the requirement is met.
