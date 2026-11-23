# Skill comparison protocol

Compare `coding`, `review`, and `audit` with the matching Ponytail skills at Ultra. Run each pair on the same pinned local project snapshot and with the same task, model, thinking setting, and tools. Let a separate agent score the answers and patches without treatment labels.

## Isolation

Use a fresh Pi process in a separate disposable copy of the project for every trial. Do not use an existing Pi session or change the user's settings. Both arms use these common options:

```text
--offline --no-extensions --no-skills --no-context-files --no-mcp
--no-approve --no-prompt-templates --no-session --mode json
--model openai-codex/gpt-6.2-sol --thinking medium -p
```

If the project has a root `AGENTS.md`, explicitly include it in both arms. The Matato arm sets `PONYTAIL_DEFAULT_MODE=off`, loads only the skill under test with `--skill`, and invokes `/skill:coding`, `/skill:review`, or `/skill:audit`. The Ponytail arm sets `PONYTAIL_DEFAULT_MODE=ultra` and explicitly loads the installed `pi-extension/index.js` with `-e`. For review and audit it also loads and invokes the corresponding Ponytail skill. Do not load the Matato skills for the baseline. Verify explicit skill expansion in the Pi events. Give the judge the final answer and any code diff, not the raw events.

## Triage and rating

Score each dimension from 0 to 2: 0 is deficient, 1 is adequate with a specific limitation, and 2 is fully supported. Judge the artifacts independently. Use a case key prepared before the runs, but accept other valid findings and equally small solutions.

| Dimension | Coding | Review and audit |
| --- | --- | --- |
| Correctness | Delivers the requested behavior and preserves existing contracts. | Findings trace to real behavior and fixes preserve contracts. |
| Scope | Changes only what delivers or verifies the request. | Covers material issues without false positives, duplicates, or out-of-scope findings. |
| Idioms | Follows language and framework patterns. | Remedies fit the language and framework used by the project. |
| Reuse and simplicity | Reuses matching code, native features, or installed dependencies instead of adding needless concepts. | Proposes the smallest fix and names verified removal or reuse when available. |
| Evidence and triage | Verifies the changed behavior and reports checks accurately. | Ranks by actual impact and gives a location, trigger, consequence, and fix. |

A material contract regression, critical false alarm, or missed proven ship blocker prevents a win. Ties stay ties. The initial success rule is a higher total for each skill over its two cases with no candidate gate failures. If these cases guide a revision, use fresh matched cases to assess that revision on unseen tasks. A small sample cannot establish general superiority.

## Initial cases

Pi version: `1.6.0`. Ponytail revision: `96608e078b2d5ea607c5c3b8b5a54d1c1fba6846`.

| Case | Project | Pinned revision | Task |
| --- | --- | --- | --- |
| `tsCoding` | Matato Pi Mobile | `ae5175ce140b10d5392552a69f1f2d6eed06a581` | Accept HTTPS shorthand in Connect without relaxing stored or WebView URL checks. |
| `rsCoding` | Matato Testing | `a252a51744b15ee415b7f901032a216850ed1352` | Add a read-only `show-report` CLI command using the existing report contract. |
| `rsReview` | Matato Testing | `a252a51744b15ee415b7f901032a216850ed1352` | Review a synthetic Markdown scenario-heading patch against the documented preflight contract. |
| `exReview` | Beer Game | `141c8d40764677e3df348183491fdebe3f5ff3e4` | Review a synthetic session-store patch that suppresses duplicate updates. |
| `tsAudit` | Matato Skills | `af26aeb35febe110247b4add4261141c21aeecb1` | Audit the browser-test runner against its documented behavior. |
| `exAudit` | Beer Game | `141c8d40764677e3df348183491fdebe3f5ff3e4` | Audit the outgoing-order flow from demand creation through delivery. |

| Initial case | Matato / 10 | Ponytail / 10 | Blind triage |
| --- | ---: | ---: | --- |
| `tsCoding` | 9 | 9 | Tie. Both reused the strict parser and passed the contract cases. Each had a different narrow edge case in the URL suffix. |
| `rsCoding` | 9 | 9 | Tie. Both reused the report reader and output path. Neither added a test that distinguishes the aggregate verdict from the first scenario's verdict. |
| `rsReview` | 10 | 10 | Tie. Both caught the Markdown fence, duplicate heading, and bare CR regressions. |
| `exReview` | 10 | 10 | Tie. Both caught the lost expiry renewal and missing notification on the first explicit `nil`. |
| `tsAudit` | 9 | 9 | Ponytail wins the gate. Matato missed that snapshot metadata could make a nonempty visibility check falsely pass. |
| `exAudit` | 9 | 10 | Ponytail wins. Both found the scheduling and hidden-order blockers; only Ponytail followed the separate manual order path from two open views. |

The initial drafts did not beat Ponytail: `coding` tied 18–18, `review` tied 20–20, and `audit` lost 18–19 and failed one gate. The TypeScript baseline launcher did not retain the process exit codes. Both Pi logs ended with a normal `agent_end` event and an assistant stop.

## Holdout

The first round led to two skill edits. `coding` now asks for one test that distinguishes a likely wrong implementation from the correct one. `audit` now asks for a negative probe of reported success and a check for alternate callers or repeated actions at shared operations. `review` was unchanged because both initial reviews earned full scores.

| Case | Project | Pinned revision | Task |
| --- | --- | --- | --- |
| `hoCoding` | Beer Game | `141c8d40764677e3df348183491fdebe3f5ff3e4` | Add a batch update path to the session store. |
| `hoReview` | Quick Note | `af7afa61e6180b11edf18123fc57a010d16aabe2` | Review a date handling patch. |
| `hoAudit` | Matato Testing | `a252a51744b15ee415b7f901032a216850ed1352` | Audit managed local runtime startup and cleanup. |

| Holdout case | Matato / 10 | Ponytail / 10 | Blind triage |
| --- | ---: | ---: | --- |
| `hoCoding` | 10 | 9 | Both reused the session store path. Matato's Quit test starts with an active order turn, so it can catch a missing reset. Standalone store checks passed; Phoenix integration did not run. |
| `hoReview` | 10 | 8 | Both caught the date regressions. Matato grouped symptoms by cause and ranked reachable regressions above malformed drafts without a traced UI producer. |
| `hoAudit` | 9 | 7 | Both caught short-deadline and preflight defects. Matato also found cleanup without a start attempt. Ponytail treated documented stdout-draining behavior as a blocker. |

All three skills won on this holdout, with no gate failures. No full browser, native app, or Phoenix integration ran.

## Second holdout

The skills were not changed between the first and second holdouts. The criterion was a higher total for each skill without any candidate gate failure. Keep the initial results separate because they informed the revisions.

| Case | Project | Pinned revision | Task |
| --- | --- | --- | --- |
| `validateCoding` | Matato Testing | `a252a51744b15ee415b7f901032a216850ed1352` | Add a single-scenario diagnostic command without publishing results. |
| `validateReview` | Beer Game | `141c8d40764677e3df348183491fdebe3f5ff3e4` | Review a synthetic session batching patch for compatibility with existing callers. |
| `validateAudit` | Doc Gen | `14c4eae6b6d4bf43b66959c574a87235dafcdc0c` | Audit cycle projection from an architecture artifact to scoped views. |

| Second holdout case | Matato / 10 | Ponytail / 10 | Blind triage |
| --- | ---: | ---: | --- |
| `validateCoding` | 10 | 9 | Both reused the CLI lifecycle and met the contract. Matato verified non-first selection, unique-prefix rejection, and full-suite preflight and provenance. |
| `validateReview` | 9 | 9 | Both found stale keys and revived expired data. Neither traced the existing quit test through same-session reentry. |
| `validateAudit` | 6 | 8 | Both found empty highlights and repeated map construction. Matato missed the legacy `null` input and proposed a raw-edge check that would reject valid exports. |

Over the two holdouts, `coding` won 20–18 and `review` won 19–17. `audit` tied 15–15. No candidate failed a gate in either holdout.

## Audit compatibility revision

The second holdout exposed unsafe remedies and missed supported input. `audit` now asks for a producer-to-consumer format check, a valid control for the proposed remedy, and a narrower caller-level fix if the shared path serves different needs. A diagnostic rerun on `validateAudit` found the legacy `null` case and no longer proposed raw-edge validation. It is not an independent score. Test this revision with the same rubric: a higher total out of 20 with no candidate gate failures. The earlier audit scores remain separate.

| Case | Project | Pinned revision | Task |
| --- | --- | --- | --- |
| `auditBoundary` | Matato Testing | `a252a51744b15ee415b7f901032a216850ed1352` | Audit whether saved run reports and baseline publication agree on valid outcomes. |
| `auditWorkflow` | Beer Game | `141c8d40764677e3df348183491fdebe3f5ff3e4` | Audit the joined player's live board, including customer demand, factory production, and delivery. |
| `auditIndependent` | Matis | `b70ed9d7bd58ff04d75c0c1dccf914b647db76f8` | Audit ignore patterns and how they interact with the dependency fan-out checks. |

`auditWorkflow` uses a new prompt and scoring key but overlaps the outgoing-order flow from `exAudit`. Record it separately. Use `auditBoundary` and `auditIndependent` for the two-case score against the same gate.

| Audit revision case | Matato / 10 | Ponytail / 10 | Blind triage |
| --- | ---: | ---: | --- |
| `auditBoundary` | 7 | 8 | Both caught both publication blockers. Ponytail showed a lease-contention trigger that survives the clean-main provenance check; Matato's unreadable-file example fails earlier. |
| `auditWorkflow` (overlap) | 8 | 7 | Matato kept the bounded ten-order summary and reused the existing delivery action. Both proposed scheduler changes that would alter disconnected-player behavior. |
| `auditIndependent` | 9 | 8 | Matato preserved the flat `fanExclude` caller and tested a directory exclusion control. Ponytail found one more allowlist bug, but its fix would reopen an excluded nested directory. |

The two independent cases tied 16–16 with no gate failures. The overlapping case does not break the tie.

## Audit trigger revision

`audit` now checks realistic triggers through upstream guards and requires a control most likely to break under each suggested fix. Apply the same two-case gate to new scopes. Do not combine scores from earlier revisions with these results.

| Case | Project | Pinned revision | Task |
| --- | --- | --- | --- |
| `finalTsAudit` | Matato | `4f2b75f73087b5f2c60995629c591dc91a591567` | Audit Chat turn completion, result cards, and workspace selection across turns. |
| `finalRustAudit` | Matis | `b70ed9d7bd58ff04d75c0c1dccf914b647db76f8` | Audit graph traversal and the resulting analysis output. |
| `finalOtherAudit` (overlap) | Beer Game | `141c8d40764677e3df348183491fdebe3f5ff3e4` | Audit manual order placement and delivery across rounds. |

The Chat baseline shell runner did not retain the Pi exit code. Pi logged `agent_end` with assistant stop and `agent_settled`, and the saved answer was complete.

| Trigger revision case | Matato / 10 | Ponytail / 10 | Blind triage |
| --- | ---: | ---: | --- |
| `finalTsAudit` | 9 | 10 | Both caught both wrong-workspace paths. Ponytail ranked both first and separated active replay failure from completed history loss. |
| `finalRustAudit` | 9 | 10 | Both caught the traversal defects. Ponytail traced the production adjacency limit and gave a control for a real cutoff hidden by removing lookahead. |
| `finalOtherAudit` (overlap) | 10 | 9 | Both caught reversed inventory transfer and stranded pending orders. Matato also traced a reconnect that hides a valid ordering window. |

The trigger revision lost 18–20 on the two independent cases. No gate failed.

## Audit evidence and ranking revision

The latest revision adds a second evidence pass over the top findings: verify the producer and consumer rules the finding relies on, record exact offline probe results, and rank wrong targets, wrong saved state, and false success above continuity loss. Score this revision on a new two-case set. Earlier results remain visible and separate.

| Case | Project | Pinned revision | Task |
| --- | --- | --- | --- |
| `evidenceDataAudit` | VU | `622c72917ebcf5bec501653cd037d4f4878df29b` | Audit Python ZIP-to-manifest conversion and trace affected data into downstream TypeScript. |
| `evidenceAppAudit` | Matato Pi | `72c3394f2a09886f82ca70b86eab0c713010873e` | Audit edits to recurring automations from save through scheduled execution. |

| Evidence revision case | Matato / 10 | Ponytail / 10 | Blind triage |
| --- | ---: | ---: | --- |
| `evidenceDataAudit` | 10 | 9 | Both found both data defects. Matato proposed a narrower CSV fix that preserves omitted optional values and traced the downstream distance error. |
| `evidenceAppAudit` | 8 | 7 | Matato gave stronger evidence and found that the editor accepts a cron expression that never fires. Both missed an edit to a paused job that can cancel the tick of an unchanged job. |

## Final results

| Evaluated skill revision | Cases | Matato / 20 | Ponytail Ultra / 20 |
| --- | --- | ---: | ---: |
| `coding` | `hoCoding`, `validateCoding` | 20 | 18 |
| `review` | `hoReview`, `validateReview` | 19 | 17 |
| `audit` | `evidenceDataAudit`, `evidenceAppAudit` | 18 | 16 |

All three evaluated revisions met the two-case score criterion without a gate failure. The scores use one run per arm and case, one model (`openai-codex/gpt-6.2-sol`), and one thinking setting (`medium`). They show an advantage on these tasks, not general superiority. The earlier audit losses and ties are part of the result. Later read-only safety and test-scope clarifications were not benchmarked. The experiment used disposable Pi processes and did not change the user's Ponytail settings. Full local records are in `/tmp/matatoSkillEval.K9fti6/` while that directory remains available.
