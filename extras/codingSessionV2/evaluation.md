# Coding-session vs Ponytail: experiment V2

## Outcome

**The requested overall advantage was not established.** The delivered skill is smaller and more explicit about precise reuse, but produces larger production and combined patches in both final pairs. This PR is a skill refinement and an unsuccessful comparative experiment, not a superiority claim.

`skills/coding-session/SKILL.md` shrinks from **5,121 to 3,161 UTF-8 bytes** (38.3%), **740 to 422 words**, and **36 to 21 lines**. Evidence lives here, outside the runtime skill; its existing report and pre-script are unchanged. No experiment implementation is shipped to another project.

## Method

Produced **70 case implementations in 14 fresh implementation agents**, with five fresh third-agent review rounds and two independent research agents. Each implementation agent handled its arm's cases sequentially; 70 outputs do not mean 70 independent agents. Paired arms received identical briefs, pinned clean bases, dependency access and immutable acceptance commands, changing only the explicitly selected skill. No output was manually repaired or cherry-picked. Every case used its own detached worktree; original project source remained unchanged.

The harness was Pi 1.2.0, `openai-codex/gpt-6.1-sol`, high reasoning. Native subagents used fresh contexts without parent conversation history. Prompts instructed arms not to read rival profiles/results, research rationales or prior reviews. Unlike V1, global discovery/context was not independently disabled or exhaustively audited. Shared global instructions, same-agent case carryover, common dependencies and concurrent load remain possible confounders. Artifacts cannot independently prove historical blindness or profile causality.

Research agents wrote behavioral oracles before implementation and confirmed expected failures on clean bases. Oracles execute real production code through domain ports, Go overlays and real temporary pre-script inputs. Additional independent reviews froze supplementary checks without relaxing originals. The final reviewer reran all seven original/additional negative controls.

Ponytail was tested at upstream commit `84740e3d344b69b4a133201fa519eb37a62a2b2a`, default/full, using `skills/ponytail/SKILL.md`, SHA-256 `ba68ff26239c3c3b05b2a9a47ee0d9a6b93a69639a2555ec87a5d44bffaf2f0c` (MIT). It was loaded explicitly from a temporary profile, not installed globally. Source/profile copies were excluded from the evidence archive and removed afterward. Upstream: https://github.com/DietrichGebert/ponytail.

## Cases

| Case | Project / language | Required reuse or behavior |
| --- | --- | --- |
| sourceBatchReads | Atlas / Python | Request-local verification sharing; independent excerpts, statuses, safety and freshness |
| isinCsvRecords | mini-broker / Go | Correct bounded CSV records, quoting, large fields, errors and whitespace |
| scheduleTimeZones | matato-pi / TypeScript | Installed Croner zones, DST, rollback, injected factories and existing overlap policy |
| pathEarlyExit | Atlas / Python | Reuse bounded BFS; finish on admitted target without breaking context traversal |
| pollProcessContract | mini-broker / Go | Configured receiver, exact IDs and cause-preserving error composition |
| preScriptIsolation | matato / TypeScript | Existing mutex through async settlement; exact environment restoration and recovery |

Starting commits: Atlas `64017b798a75fccff7d6d545172251851fcef615`; mini-broker `4b1e143abc40f4582d90bfcdc7c55b06d787a934`; matato-pi `92ec28467170bb8b520ebe53dea234b7623dec46`; matato `4f2b75f73087b5f2c60995629c591dc91a591567`. Exact briefs, setup and check hashes are archived.

Traversal was initially reserved; two new cases were unseen in the frozen six-case phase. Later reuse makes these tuning/replication cases, not untouched final generalization tests. One earlier review accidentally emitted holdout metadata; its report discloses that blinding imperfection.

## Iterations and rejected conclusions

Churn is added plus removed physical lines, including comments/whitespace. Tests include snapshots/config fixtures. Net growth is reported separately in `results.json`; neither metric alone measures complexity.

| Phase | Cases per arm | Ponytail source / combined churn | Coding source / combined churn |
| --- | ---: | ---: | ---: |
| Original skill | 3 | 77 / 256 | 80 / 332 |
| Contract/resource rewrite | 4 | 100 / 337 | 115 / 344 |
| Reusable-result rewrite | 4 | 93 / 372 | 112 / 365 |
| Production-call/extension-point rewrite | 6 | 117 / 380 | 136 / 546 |
| Same-profile replication | 6 | 118 / 388 | 123 / 441 |
| Compact delivered skill | 6 | 120 / 612 | 137 / 636 |
| Compact same-profile repeat | 6 | 125 / 507 | 135 / 739 |

Three-case totals must not be compared with six-case totals. Different Ponytail draws show substantial sampling variability.

The third phase's seven-line combined advantage was rejected: production was larger, and cross-testing exposed invalid-zone acceptance through an injected factory. The shared bad-zone requirement was clarified for both arms, an independent supplemental check enforced it, and all later arms passed. Earlier profiles/candidates remain archived, not silently replaced by later fixes.

The source-batch brief was clarified before the four-case pair to mean one `reader.file` **verification-port lookup**, not all file-related SQL. Both arms still repeat node-enrichment SQL. This bounds the claim; it does not establish global query deduplication.

Some early smaller CSV native suites still passed when restored to the buggy original parser. External acceptance proved current parsing correctness but did not provide durable repository regressions. All four final compact arms add maintained tests for the actual parsing failures. More test code is not automatically waste.

After the failed frozen replication, the reviewer proposed condensation rather than additional checklists. The compact skill retains authoritative schemas/defaults, sparse presence, real-call-shape probes, shared extension-point policy, safety, ownership, precedence, necessary regressions and honest resource claims. Final checks found no substantive guard weakened; unrelated schema, frontend and distributed behavior was not re-evaluated.

## Final complete-pair results

| Case | Ponytail first source / tests | Coding first source / tests | Ponytail repeat source / tests | Coding repeat source / tests |
| --- | ---: | ---: | ---: | ---: |
| sourceBatchReads | 26 / 34 | 43 / 55 | 30 / 28 | 42 / 48 |
| isinCsvRecords | 39 / 44 | 38 / 55 | 40 / 46 | 39 / 50 |
| scheduleTimeZones | 14 / 93 | 15 / 72 | 14 / 45 | 14 / 83 |
| pathEarlyExit | 13 / 40 | 13 / 58 | 13 / 38 | 13 / 90 |
| pollProcessContract | 14 / 111 | 14 / 115 | 14 / 95 | 14 / 163 |
| preScriptIsolation | 14 / 170 | 14 / 144 | 14 / 130 | 13 / 170 |
| **Total churn** | **120 / 492** | **137 / 499** | **125 / 382** | **135 / 604** |
| **Combined churn** | **612** | **636** | **507** | **739** |
| Production net growth | +32 | +39 | +35 | +29 |
| Combined net growth | +504 | +522 | +397 | +609 |

All 24 final candidates pass frozen acceptance, relevant supplements and focused native checks. Each review's runner records exact commands, environments and individual exits; its 96 entries include observations, not 96 independent test suites. Cross-tests have explained non-passes: private Go helper naming mismatches and extra coding-source assertions requiring one decode. They are retained, not relabelled all-pass.

## Resource evidence, not a blanket efficiency score

For 100 same-file nodes, both final coding arms perform **one full decode/split instead of Ponytail's 100**; verification/read/hash counts are one in both. Unsupported encoding is shared too, without cross-request staleness. This replicated reduction comes from sharing the reusable decoded result, not merely adding a native decorator.

The tradeoff is retained decoded data: eight distinct approximately 1 MiB files peak at **22,317,955 traced bytes versus 15,857,529** for Ponytail, about 41% higher. Repeating one file has the same traced peak in both. Whole-file caches do not survive the call. These are synthetic CPython `tracemalloc` observations, not RSS or a measured latency speedup. Total SQL remains 42 SELECTs for ten repeated keys, including ten enrichment queries and one verification query.

Both approaches ultimately use Go's CSV reader and `errors.Join`, existing HTTP methods, the existing async mutex, Croner date logic and existing bounded BFS. Final polling source is byte-identical across arms; most pre-script source is too. No new production dependency or runtime module hides complexity. Larger test patches often add distinct contract assertions; shortening them blindly would defeat the experiment.

## Evidence and replay

`evidence.tar.gz` (about 1.4 MiB) contains all 70 whole-case patches, 14 implementation reports, five reviews, profile history for coding-session, exact briefs, immutable checks, metrics, negative controls and logs. `evidence.sha256` verifies the archive. It contains no Ponytail checkout/profile, dependency binaries, Git worktrees, credentials or raw chat sessions. Inspect before executing archived scripts; these are historical evidence, not a new automatically loaded workflow.

Extract to `/tmp/codingSessionV2`, recreate worktrees/dependencies from the archived manifests, retrieve Ponytail only if replaying its arm, and apply whole-arm patches. Scripts use recorded absolute paths and some existing local test environments; this is **not a hermetic benchmark distribution**. Final review entry points are `research/reviewCompactChecks.py`, `research/reviewCompactControls.py` and `research/reviewCompactSummary.py`. Inspect individual cross/control JSON exits; a successful driver exit is not necessarily all-pass. Archive provenance/member hashes are included.

Independent checks cover real source safety, lifecycle, error identity, budget interactions and maintained regressions. Full-project suites/typecheck/lint were not uniformly available; Go has unrelated vet/build failures and some TypeScript dependencies were absent. Implementers' broader passes/blockers remain in their reports, separate from reviewer-executed checks. No live broker/endurance run, combined multi-patch integration, frontend/hardware, distributed concurrency, representative latency or RSS benchmark was performed.

One model, three implementation languages, six adaptively developed tasks and two final repeated draws provide no significance or universal-superiority claim. Continued sampling until a favorable result would be optional stopping. **The experiment stops with its negative overall result visible.**
