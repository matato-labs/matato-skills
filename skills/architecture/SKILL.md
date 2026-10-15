---
name: architecture
description: Analyze a proposed or implemented change against current project architecture. Use before coding or when reviewing placement, boundaries, dependencies, contracts and impact. Default to lightweight layered architecture when none is identifiable.
---

# Architecture fit

Analyze the change, not an idealized replacement system. Establish required behavior, constraints, scope, exact checkout, comparison base when reviewing, and relevant local changes. Read applicable repository instructions. Analysis alone does not authorize edits, project execution, installation, indexing, migrations, or publication.

## Identify the current architecture

Inspect relevant entry points, manifests, design decisions, source, configuration and tests. Verify declared architecture against actual imports, calls, registrations, mounts and consumers. Identify responsibility, state and side-effect ownership, allowed dependency direction, and relevant exceptions. Cite current `path:line` evidence; distinguish documented intent, observed implementation and inference. Historical PRs, generated artifacts and folder names do not establish current architecture.

Recognize feature modules, framework conventions, libraries, scripts, configuration, content pipelines and mixed architectures. Analyze the affected subsystem rather than assigning one pattern to the whole repository. Distinguish runtime dependencies from type-only references and static relationships from execution. Follow indirect wiring when relevant; an absent graph edge does not establish absent behavior. Navigation tools are optional; verify indexed claims against the intended checkout's source.

If no architecture is identifiable after targeted inspection, explicitly adopt a provisional layered architecture for the affected change: **entry/presentation → application/behavior → data/external effects**. Dependencies go toward lower responsibilities, not back into entry points; keep reusable rules separate from effect details where needed. These are logical responsibilities, not mandatory directories, classes, interfaces or services. Use existing files or functions when sufficient. Configuration/content changes still belong with their loaders, formats and consumers. Missing source is an evidence gap, not proof of absent architecture; ask when it prevents a sound decision. Do not relabel an established architecture as layered.

## Trace and place the change

Trace the requested behavior from entry through rules, contracts, state/effects and downstream consumers to tests. Check alternate entry points, shared callers, platform variants, generated contracts and deployment wiring only where affected. Include relevant failures and asynchronous boundaries, not just the happy path. Stop when placement and impact have evidence; do not map unrelated code.

Identify the existing owner and extension point. Prefer no change when satisfied, then the smallest complete modification of existing facilities. Name files to touch, affected consumers and necessary integration. Reuse authoritative types, schemas, defaults and policies; do not duplicate contracts or repair downstream symptoms instead of the cause. Explain necessary boundary changes and tradeoffs; compare viable alternatives only when placement is consequential. If the request conflicts with established constraints, expose the conflict rather than silently changing architecture.

Preserve relevant public APIs, errors, identities, authorization, configuration precedence, stored-data compatibility, transaction boundaries, effect ordering, asynchronous lifetimes and cleanup unless intentionally changed. Current architecture is not an instruction to preserve a demonstrated bug. Distinguish relevant existing debt from violations introduced by this change; do not copy debt or expand the task into a rewrite. Add abstractions, dependencies or migrations only when required.

## Challenge and report

Name a plausible boundary violation and a concrete regression that would detect it. Check a required flow and a relevant counterexample at the real integration seam; derive checks from existing tests, instructions and CI. During implementation or review, compare the whole diff with proposed boundaries and check affected consumers. Report checks executed separately from proposed checks; do not treat approval, merge status, snapshots or clean metrics as architectural proof. Verify PR/review claims against source or the final diff; disclose incomplete evidence.

Return a concise fit judgment: compatible, compatible with stated adjustments, conflicting, or blocked by missing evidence. Support it with the current boundaries and citations, minimal file/flow changes, preserved contracts, concrete regression checks and unresolved risks. Use a small before/after diagram when helpful; distinguish dependencies from runtime flow and mark proposed or uncertain relationships. Ask only questions that change correctness or placement. Do not create an architecture document or perform unrelated cleanup unless requested.
