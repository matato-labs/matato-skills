# Initial V5 independent quality/mechanism review

**Recommendation: no superiority or deployment claim from this round.** All nine fixes pass acceptance and meaningful maintained regressions, but every Python generation is an invalid 600-second completion and introduces a failing repository-required policy check. Passing post-run native commands does not cure either defect.

Reviewed the plan, three development briefs, all nine patches and affected workspace contracts/tests. Profiles, holdout and raw/auth/private logs remained unopened; no model trials or prompt changes. Labels identify artifacts, not presumed quality: **A** = `26cf444118fe…bea23fa05558`, **B** = `b167b64db50c…cece4418f5a2`, **C** = `ba68ff26239c…9d07b1e583f4`. Full paths: evidence `inventory.json`.

## All nine patches

Counts below are executed maintained test methods/items, not added-test counts. Every candidate passes; every corresponding original-production control fails behaviorally with candidate tests retained.

| Artifact | Maintained checks | Assessment / coverage distinction |
|---|---:|---|
| A TypeScript | 3 | Real Git fixtures cover parent-origin leakage, exclusions, spaces and workspace symlink. Gitfile fixture uses separate Git directory, not a linked worktree. |
| B TypeScript | 6 | Broader independent cases, linked-checkout metadata and origin removal; oversized suite callback noted below. |
| C TypeScript | 4 | Linked-checkout/shared-origin regression, exclusions and symlink spelling; original rejected in two tests. |
| A Bash | 2; 11 scenarios | Three successful OS routes; Linux DevPod failures; SDK failures only on simulated macOS. |
| B Bash | 3; 15 scenarios | Adds SDK failures across all OS routes; missing bubblewrap skips the suite, so require a non-skipped run. |
| C Bash | 2; 15 scenarios | All routes/failures, ordering and no-retry assertions. |
| A Python | 59 | Production-indexed shared pickup sample; exact/short budgets, BFS route and evidence assertions; five snapshot files change. |
| B Python | 64 | Existing samples, duplicate-prefix/exact-cycle cases, service/CLI parity, negative assertion controls and explicit bounded-reader assertion. |
| C Python | 59 | Existing samples, BFS route and exact inheritance budget; service parity applied to collected context/path responses. |

All nine independent acceptance reruns pass. All three TypeScript type/focused-lint checks and all three Python Ruff/Pyright checks pass with the pinned interpreter explicitly selected. A’s additionally affected coffee suites pass **125 tests plus 78 subtests**.

## Findings

**Required check regression, all Python artifacts.** `atlas check --f .` exits 1 on newly authored test helpers, while the same immutable original repository exits 0. A: `CoffeeNavigation.pickup_edge_budgets` weighted complexity 26/8 and nested loops 8/0 (`atlas/tests/coffee_navigation.py:279`). B: `duplicate_prefix_budgets` nested loops 1/0 (`:317`). C: `budgeted_calls` complexity 14/8, loops 2/0 (`:285`); `budgeted_inheritance` complexity 9/8, loops 1/0 (`:314`). These are introduced policy failures, not missing dependencies or inherited debt. Evidence: `checks/{A,B,C}/py/candidate/wholeCheck.stdout`; clean baseline: `checks/A/py/original/baselineWholeCheck.*`.

**Size qualification.** No changed code file exceeds 600 lines; no individual test body or new Python function reaches 100 lines. B’s expanded `describe` callback is nevertheless **130 lines**, `src/workspaceRepos.test.ts:31–160`; strict function-size enforcement flags this container. AST evidence: `checks/*/ts/candidate/sizes.stdout`, `inventory.json`.

**Contracts and placement otherwise fit.** TypeScript preserves discovery ownership, immediate-directory filtering, returned spelling and remote-failure skipping; physical root comparison excludes inherited/bare/admin roots without a `.git`-directory assumption. Bash fixes the existing errexit/AND-list interaction and HTTP handling without package/order/location/mode changes. Python stays on `CLI → NavigationService → Traversal → NavigationReader`; a `max_edges + 1` adjacency prefix permits included ordinals plus overflow evidence, remains finite/indexed, and leaves node/depth/path ownership intact. No new production abstractions, dependencies or unrelated storage/CLI redesign.

**Snapshot-first adherence is substantive.** All Python regressions use the shared production indexing/navigation assertion seam. B/C retain all 19 existing snapshot responses exactly, adding 16/7 responses. A adds a shared fixture: identity-based review finds no removed/changed existing extraction files, symbols, graph nodes or report nodes; additions are one file, four symbols, seven calls, five graph nodes and twelve graph edges. Existing navigation changes are counts/ordinals. Thus broader churn is explained, not evidence of concealed failures; reusing existing evidence would have reduced review surface. See `snapshotChanges.json`, `snapshotIdentity.json`.

**Discovery matters.** Bash native is only `bash -n`; it does not discover authored behavior tests. Explicit unittest discovery executed all 2/3/2 methods with no skips; fixture command files are invoked as inert subprocess doubles, not tests. Original controls fail on false successful completion, not isolation errors. TypeScript controls expose inherited-origin rows; Python controls fail maintained assertions before snapshot equality. All Bash execution remained inside outer harness isolation plus the fixture sandbox. Linux simulation is not native macOS validation.

All TypeScript patches also contain the absolute `node_modules` symlink created by manifest setup. It is delivery/measurement contamination, not evidence of agent-authored dependency changes; do not ship it as application code.

## Timeout mechanism and procedural improvements

Public traces show completed TypeScript/Bash runs around **102–138 seconds**, versus three Python global timeouts at **600 seconds**. Focused Python native checks completed in roughly 39–69 seconds during generation. A then spent 250 seconds on a full-suite timeout; B 240; C timed out at 120 and restarted with 300 seconds, still unfinished at global termination. Parallel durations must not be summed as wall time. A/C broad searches emitted about 0.78 MB each; B/C default-interpreter type checks emitted about 0.26 MB before environment correction. This supports avoidable orchestration overhead, not a proven language/profile cause or diagnosed test hang (`traces.txt`).

For subsequent approved work, inventory **every repository-required check**, its offline dependencies and actual deadline before implementation. Schedule bounded, nonoverlapping test shards against collected test IDs, recording complete coverage rather than repeatedly restarting the whole suite. Reserve closure time; unfinished checks stay unfinished, never silently replaced by focused passes. Preserve dashboard/build requirements too: these snapshots lack dashboard dependencies and traces contain no successful dashboard checks. Use the pinned execution environment consistently; restrict searches to relevant source/test files and inspect large snapshots structurally. Record each command’s status independently—semicolon chains can mask earlier failures. Explicitly reconcile added tests with discovery, and retain candidate/original controls and all failed attempts. These are procedural changes, not task recipes or prompt tuning; the frozen brief’s 900-second intended budget must not be mistaken for the enforced 600 seconds.

**Unresolved:** no completed full importer suite, no completed mandated dashboard checks, no native macOS run, and no universal/all-metric superiority evidence. Relevant checks and correct production changes do not override the plan’s invalid-completion gate. No failed generation was repaired, replaced or resampled.

Evidence root: `/home/leon/.cache/codingSessionV5/reviews/`. `checkResults.json` indexes commands, exits, durations and retained stdout/stderr; `inspectionAttempts.md` retains unsuccessful inspections and scope details. Checks used only harness sandbox functions on disposable copies, each child ≤110 seconds and enclosing command ≤120 seconds. Original/user workspaces were not mutated.
