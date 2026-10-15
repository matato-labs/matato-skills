---
name: coding-session
description: Implement and fix code with the smallest readable change that fully meets the request. Use for implementation, bug fixes and requested refactoring in any language or environment.
disable-model-invocation: true
---

# Coding session

Read the request, repository instructions, affected code and existing tests. Find the shared cause and the callers, types, exports, configuration and fixtures the change must reach. Preserve existing acceptance guarantees. Ask only about ambiguity that changes correctness; do not create an extra specification unless requested.

Change existing code first. Prefer an existing project facility, then a standard library or platform operation, then an installed dependency, before direct implementation. Read the actual contract; when uncertain, probe the production call shape, options and callbacks. Check consumption limits, omission versus explicit values, ordering, partial results, error identity and ownership. Reuse authoritative types, schemas, defaults and semantic policy across callers and extension points, not merely similarly named APIs. Preserve field presence for sparse updates. Keep native values native; count adapters as part of the solution.

Keep trust-boundary validation, security, synchronization, accessibility, data-loss protections and required cleanup. Preserve failure, replacement and recovery behavior, including precedence. Trust established internal guarantees rather than duplicating them. Do not trade these contracts for a shorter diff.

Add only behavior and integration the request needs. Keep existing layers and readable expressions; extract shared work or clarify genuinely difficult logic, not speculative flexibility. No unrelated cleanup, wrappers, conversions, dependencies or new configuration. Comments explain non-obvious constraints. Ask of each addition: what requirement or concrete regression fails without it?

For required efficiency work, identify the expensive operation and its unit across the whole caller path. Share reusable results rather than intermediates every consumer must transform again; keep consumer-specific outcomes separate and bound sharing lifetime. Compare repeated transformations, copies and retained data as well as boundary calls. Fewer lines or a native API alone proves no resource saving.

Read maintained coverage before adding tests. Extend existing fixtures and parameterize equivalent cases. Add focused maintained regressions for real failures and changed contracts, including interactions with distinct risk; use a persistent executable self-check if no test framework exists. Keep meaningful assertions and necessary integration coverage. External probes supplement, never replace, needed repository regressions. Avoid duplicating setup or re-testing platform guarantees that the change does not threaten.

Run relevant checks and inspect the complete source and test diff. Remove only unjustified additions, not coverage or safeguards to improve counts. Stop when the complete requirement is met. Briefly report the change, checks actually run and remaining limits; do not claim unmeasured savings.
