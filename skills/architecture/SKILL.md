---
name: architecture
description: Assess where proposed or implemented changes belong in the architecture. Check boundaries, dependencies, contracts and impact. Use before coding or reviewing. Use lightweight layers as the default only when you cannot identify an architecture.
---

# Architecture fit

Identify the required behavior, constraints, scope, checkout, review base and local changes. Read the applicable instructions. Analysis does not authorize edits, execution, installation, indexing, migrations or publication.

## Discover and trace

Inspect relevant entry points, manifests, decisions, source, configuration and tests. Check the intended behavior against actual imports, calls, registrations, mounts and consumers. Cite current evidence as `path:line`. Distinguish what you observed, what documentation states and what you inferred. Do not use history, generated artifacts, folder names or indexes as a substitute for checking the checkout.

Identify patterns used by frameworks, scripts, configuration, content and mixed subsystems. Identify who owns rules, state and effects. Identify dependency direction and exceptions. Distinguish type-only dependencies from runtime dependencies. Distinguish static relationships from execution. Follow indirect connections. Missing graph edges do not prove that behavior is absent.

Treat missing source as an evidence gap. Ask for help if the gap prevents you from deciding where the change belongs. Only when targeted inspection identifies no architecture, provisionally use **entry/presentation → application/behavior → data/external effects**. Use downward dependencies. Separate reusable rules from effect details where needed. These layers describe logical responsibilities. Existing functions and files are sufficient. You do not need separate directories, classes, interfaces or services. Keep configuration and content with their actual loaders, formats and consumers. Never relabel an established architecture.

Trace the required behavior through contracts, failures, state, effects and downstream consumers to tests. Include affected alternate entry points, shared callers, platforms, generated contracts, shipped policy resources, deployment connections and asynchronous boundaries. Verify the actual connections. Distinguish configuration changes from activation. Stop when evidence supports both placement and impact.

## Place and challenge

Prefer no change when existing facilities satisfy the request. Otherwise, choose the smallest complete change at the existing owner or extension point. Do not choose only by diff size. Name the files, consumers and integration. Reuse authoritative types, schemas, defaults and policies. Fix causes, not downstream symptoms. Compare viable alternatives when placement has important consequences. Explain necessary boundary changes, tradeoffs and conflicts between constraints.

Preserve relevant APIs, errors, identities, authorization, configuration precedence, stored-data compatibility, transactions, effect ordering, asynchronous lifetimes and cleanup unless the change intentionally alters them. Distinguish existing technical debt from violations that the change introduces. Do not preserve demonstrated bugs, copy technical debt or expand the work into rewrites. Add abstractions, dependencies or migrations only when required.

Name a plausible boundary violation and a regression check that would detect it. Check a required flow and a counterexample at the actual integration boundary. Derive these checks from existing tests, instructions and CI. During implementation or review, inspect the whole diff against boundaries and affected consumers. Distinguish checks you executed from checks you propose. Approval, merge status, snapshots and metrics cannot prove correctness. Verify claims in the PR or review against the source and final diff. State any evidence gaps.

## Report

Classify the architectural fit as compatible, compatible with adjustments, conflicting, or blocked by missing evidence. Include citations for boundaries, minimal changes to files and flows, preserved contracts, regression checks and risks. Add a diagram when helpful. Distinguish dependencies from runtime flow. Mark proposed or uncertain relationships. Ask only questions whose answers could change correctness or placement. Do not create an architecture document or perform cleanup unless requested.
