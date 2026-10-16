---
name: architecture
description: Assess proposed or implemented changes for architectural placement, boundaries, dependencies, contracts and impact. Use before coding or reviewing; default to lightweight layers only when no architecture is identifiable.
---

# Architecture fit

Establish required behavior, constraints, scope, checkout, review base and local changes; read applicable instructions. Analysis authorizes no edits, execution, installation, indexing, migrations or publication.

## Discover and trace

Inspect relevant entry points, manifests, decisions, source, configuration and tests. Verify intent against actual imports, calls, registrations, mounts and consumers. Cite current `path:line` evidence; separate observation, documentation and inference. History, generated artifacts, folder names and indexes cannot replace checkout verification.

Recognize framework, script, configuration, content and mixed subsystem patterns. Identify rule/state/effect ownership, dependency direction and exceptions. Separate type-only from runtime dependencies and static relationships from execution; follow indirect wiring. Missing graph edges do not prove absent behavior.

Missing source is an evidence gap: ask if it blocks placement. Only when targeted inspection identifies no architecture, provisionally use **entry/presentation → application/behavior → data/external effects**, with downward dependencies and reusable rules separate from effect details where needed. These are logical responsibilities: existing functions/files suffice, not mandatory directories, classes, interfaces or services. Keep configuration/content with actual loaders, formats and consumers; never relabel established architecture.

Trace required behavior through contracts, failures, state/effects and downstream consumers to tests. Include affected alternate entries, shared callers, platforms, generated contracts, shipped policy resources, deployment wiring and asynchronous boundaries. Verify actual wiring and distinguish configuration changes from activation. Stop once placement/impact are evidenced.

## Place and challenge

Prefer no change when existing facilities satisfy the request; otherwise choose the smallest complete change at the existing owner/extension point, not merely the shortest diff. Name files, consumers and integration. Reuse authoritative types, schemas, defaults and policies; fix causes, not downstream symptoms. Compare viable alternatives when placement is consequential; explain necessary boundary changes, tradeoffs and constraint conflicts.

Preserve relevant APIs, errors, identities, authorization, configuration precedence, stored-data compatibility, transactions, effect ordering, asynchronous lifetimes and cleanup unless intentionally changed. Distinguish inherited debt from introduced violations; neither preserve demonstrated bugs, copy debt nor expand into rewrites. Add abstractions, dependencies or migrations only when required.

Name a plausible boundary violation and detecting regression. Check a required flow and counterexample at the real integration seam, deriving checks from existing tests/instructions/CI. During implementation/review, inspect the whole diff against boundaries and affected consumers. Separate executed from proposed checks; approval, merge status, snapshots and metrics cannot prove correctness. Verify PR/review claims against source/final diff; disclose evidence gaps.

## Report

Judge fit: compatible, compatible with adjustments, conflicting, or blocked by missing evidence. Include cited boundaries, minimal file/flow changes, preserved contracts, regression checks and risks. Diagram when helpful; distinguish dependencies from runtime flow and mark proposed/uncertain relationships. Ask only correctness/placement-changing questions. No unsolicited architecture document or cleanup.
