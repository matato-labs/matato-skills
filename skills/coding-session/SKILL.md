---
name: coding-session
description: Implement and fix code with the smallest readable change that fully meets the request. Use for implementation, bug fixes and requested refactoring in any language or environment.
disable-model-invocation: true
---

# Coding session

Solve the whole request with the least new machinery. Read repository instructions, affected code and maintained tests. Find the shared cause, its owning boundary and affected integrations. Ask only about ambiguity that changes correctness.

Before adding logic, take the first complete option: change an existing expression; compose project facilities; use a language or platform operation; use an installed dependency; write direct code. Read the real API and its callers; probe uncertain semantics at the production call shape. Reuse authoritative contracts and native values, not parallel policy or adapters. Share reusable results at their common lifetime. Helpers need actual reuse or difficult logic to clarify; one-liners stay readable.

Implement only missing behavior. No speculative options, wrappers, dependencies, state or unrelated cleanup. Preserve observable contracts and existing layers, including distinctions between omitted and explicit values, precedence, identity and failure behavior. Never remove trust-boundary validation, security, synchronization, accessibility, data-loss protection or cleanup. Trust established internal guarantees rather than rechecking them. Recovery and extension paths obey the same policy.

Choose the maintained test seam before writing tests. Extend its fixtures, builders and assertions to expose the bug and protect contracts the change could break. Trace changed fixtures through their consumers and generators. Reuse one setup and assertion path for equivalent cases; add separate scenarios for distinct risks or interacting paths, not every combination of representations. Keep meaningful assertions and necessary integration coverage. New test files can fit that seam; parallel harnesses or acceptance matrices need a concrete gap. External checks supplement maintained regressions, not replace them or dictate a duplicate suite. Without a framework, leave a small executable self-check.

Run relevant checks and inspect the whole source and test diff. Can composition remove new machinery without losing behavior or clarity? Remove only unjustified additions, never safeguards or meaningful assertions for counts. For efficiency claims, measure the relevant repeated work and retained data. Stop once complete. Briefly report changes, checks actually run and remaining limits; do not claim unmeasured savings.
