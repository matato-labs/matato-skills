# Independent tuningOne review

**Verdict: production gate NOT MET; no demonstrated V4 win.** CandidateOne has meaningful passing behavioral regressions, but production additions/churn are **26/38 versus Ponytail 23/34**, and production result bytes **11964 versus 11785**. Combined additions/churn improve (**392/440 versus 478/527**); that cannot substitute for production or instruction/coverage gates. This is one two-case tuning draw, not the repeated final evaluation.

Recommend freezing the unchanged 2593-byte profile **only as an experimental candidate for honest final evaluation**, not as a qualified winner. No specific final wording hypothesis is justified by these mainly representational production differences. Another adaptive rewrite risks optimizing these exposed examples. If “freeze” means all gates already satisfied, do not freeze on that basis. Do not repair, select patches, or resample. No candidate text written.

## Scope, controls, prior findings and responses

Reviewed exactly eight tuningOne outputs: V3, V2, pinned default/full Ponytail, candidateOne on pythonConfinedIgnoreFiles and preScriptEnvironmentLifetime. Read original brief/gates, candidateOneDecision.json, prior ablation review/metrics, both tuning manifests/briefs, all eight whole patches, actual changed source/tests and pinned base counterparts, local repository instructions, native/oracle launchers and affected callers. No reserve briefs/manifests or aggregate research manifest opened. Historical/frozen results, implementations, skill files and README files untouched.

Eight private raw agent streams independently parsed: complete profile was the first successful read; all report openai-codex/gpt-6.1-sol/high, settle normally, exit 0 without timeout, with distinct configurations/worktrees, matched same-case prompts, 900-second budgets and correct pinned bases. All recorded original acceptance/native exits independently read as zero; they are not silently substituted for the review reruns. Profile hashes match pins. Candidate is exactly V3 minus the common-lifetime sentence: **2642 →2593 bytes**, no auxiliary runtime content loaded by this invocation. V2/Ponytail are comparison profiles, not candidate-cap compliant (3161/3492 bytes). Requested/reported model identity verified; hidden backend response-model identity is not exposed. Same Pi1.1.0 and installed local dependencies across arms; no causal comparison with historical Pi versions.

Prior ablation objection remains valid: TS production identical, Python's earlier three-line gap cosmetic, common-lifetime mechanism unestablished; combined raw churn worsened after removal while bytes improved. Parent's response—use sentence removal only as smaller starting point, not proven win—is respected. Historical V3 room-ID Set hoisting had no measured performance benefit; production/byte losses and lexical-root, zero-sentinel, stale-consumer and fixture/generator failures remain context, not failures imputed to these new patches. Here canonical roots, exact absent/empty sentinels, ownership/restoration and generator routes were explicitly inspected. No persona, grammar or numbering conclusion.

## Source, facilities, safeguards and actual coverage

Python uses pathlib strict final resolution, canonical-root containment and regular-file checks, then the existing pathspec GitIgnoreSpec matcher. Missing/dangling/cyclic/directory-valued policy paths supply no rules; external undecodable content is rejected before reading. Internal and returning symlink chains remain valid, entry-directory anchoring remains separate from target location, Git/Atlas layers stay independent, inherited rules are copied, and pruning/order/negation remain intact. os.walk still does not follow directory symlinks; ordinary source containment is unchanged. No race-protection requirement invented beyond the stable-filesystem contract.

V3 folds validation into rule loading and loads root Git rules once, reusing them rather than resolving/parsing them again. V2/Ponytail use a boolean eligibility helper. Candidate returns a resolved Path-or-None and reads that target; its root mode probe and subsequent loader resolve again. These are small variants of the same necessary boundary check, not new ignore engines. No measured performance advantage for root-rule reuse or resolved-target return. No guard deletion or production complexity relocation found.

Traced CLI index/report → analyze_folder → analyze_repository → validate_repository/discover_files, plus canonical-location save_folder reuse. All arms' revised CLI regressions exercise external → local → external policy, both filenames, unsaved report and index/saved-report routes, persisted exact file sets, circular-import removal/restoration and unchanged source/external-policy bytes. V2/Ponytail also parameterize nested reanalysis; V3/candidate own nested discovery coverage but only root CLI transitions. That is a coverage distinction, not evidence of a broken nested consumer.

Ponytail alone extends the shared coffee sample/snapshot seam: coffee_discovery helper, 45-byte discovery.rules, 44-case 10816-byte discovery.json and actual generator integration. Its physical-source inventory now filters by the real detect_language facility so the non-source rules file is not demanded as an analyzed source. Registered language/project inventories and dependent extraction/analysis/graph/CLI/navigation/variant/safety snapshots remain coherent. Generator checks preserve 72 parsed outputs versus 71 for other arms. The compact one-line JSON does not make its volume free; it is accounted separately and was inspected as actual expected path sets.

**Instruction/quality qualification:** Atlas AGENTS.md explicitly calls for sample/snapshot-first indexing/report regressions and extending relevant samples/snapshot assertions. V3/V2/candidate instead extend existing discovery/CLI tests using shared real sample bytes but add no snapshot assertions. Their behavioral coverage is meaningful, not source-string/LOC checking, yet it does not fully follow that explicit snapshot-first direction. The earlier two Python ablation arms share this deviation; the previous review did not flag it. This is a static instruction-compliance finding applied symmetrically, not a new oracle requirement or retroactive score repair. Ponytail's more expensive route is substantially explained by following the requested maintained seam, not automatically duplicated scaffolding. Do not award candidate a clean quality gate merely for omitting that route.

TypeScript production is byte-identical across all four arms. Existing FIFO mutex and native async/finally semantics do the work. `return await module.run()` keeps the overlay and lock through settlement, preserving the rejection; `string | undefined` and explicit undefined comparison preserve absent versus present-empty values. Nested finally blocks restore only supplied keys and release on stat/import/run failure. Bun.env/process.env views agree in actual runtime tests. Shell dispatch stays outside the mutex; child overlay, STORAGE_PATH, cwd, JSON parsing and stderr/exit-code errors remain unchanged. Existing scheduled-job/sequence-step public APIs and environment construction are untouched.

All new TS suites meaningfully cover overlap through settlement, sync throw/async rejection, error preservation, exact restoration, unrelated writes, load failure/recovery, JSON values and independent shell execution. Ponytail additionally batches sync and async JSON shapes; V2 includes missing-import and silent-exit checks; V3 includes module-evaluation failure gating. Candidate's smaller suite still exercises the main contracts, rather than merely asserting source text. V3/V2 also strengthen both caller wrappers to read environment after awaiting; those tests fail original production. Candidate/Ponytail leave wrapper tests synchronous, and their wrapper controls still pass the original bug. Their new shared-runner tests do detect it; integration coverage is less bug-specific, not absent. Test-only controls/gates are not relocated production machinery.

## Independent executions and honest failures

supplementPlan.json frozen before checks. Own git-archive base copies received complete recorded patches; every changed file including untracked helpers/fixtures/snapshots was byte-verified against frozen live output. Bubblewrap unshare-all, read-only originals/dependencies, writable private copies/stages only, sanitized environment, no credentials, network or live services. An initial /tmp quota error occurred during copy preparation before any checks; own copies moved to /dev/shm/codingSessionV4tuningReview. No implementation execution or source repair occurred. Exact argv/environment/times and full logs are in commands.json/logs; scripts are retained.

Python frozen behavior **8/8 each**; native all changed discovery/atlasignore tests and affected CLI/coffee/pipeline/variant/navigation/script-member/safety suites: **217/239/200/211 passed**, respectively V3/V2/Ponytail/candidate, each plus **78 subtests**. Real update_coffee_snapshots --navigation passes, preserving all parsed snapshot outputs, including Ponytail's new route. Original-production maintained controls fail **8/20/9/8**, with **33/43/104/27** passes; Ponytail includes its changed pipeline tests. These are real boundary/path-set assertions, not missing dependency errors. Original frozen Python behavior separately has eight failure and four error subcases.

TS frozen behavior **6/6 each**, direct added maintained suites **13/13,13/13,8/8,15/15**, supplemental changed-file lint all green. Frozen native typecheck/lint succeed on all; existing consumers **35/35** for V3/V2/candidate, **34/35** for Ponytail. The observed Ponytail failure is unchanged bus.test.ts:1543, loop-skip consumer expected done/cleared-loop but saw in_progress/coding. Existing waitForBackgroundTask only sleeps **5 ms**, and teardown then produced a bootstrap-config error while background work continued. Coordinator's earlier green native result remains intact, but **this independent frozenNative result is exit 1**.

Before any diagnostic, froze diagnosticPlan.json. One separate sequential full bus suite per current arm, both earlier ablation arms, and original base passed **18/18 each**. Byte-identical current production plus the common 5ms wait and load-sensitive observation support timing fragility, not a Ponytail-specific production defect. Passing diagnostics do not erase the failure or prove its complete cause; native reliability remains qualified. No tests were edited to wait longer.

Original-production direct TS controls: V3 **6 fail/7 pass**, V2 **12/1**, Ponytail **7/1**, candidate **14/1**. Original frozen behavior fails **6/6**. Separate wrapper controls ensure an initial bus failure cannot skip scheduled tests: V3/V2 both fail their changed async bus test and changed scheduled test (scheduled **1 fail/4 pass**); Ponytail/candidate and both earlier ablation arms pass their unchanged wrappers (**2+5**). Earlier ablation evidence is untouched; new symmetric diagnostics/controls live only here. Native's omission of src/worker/preScript.test.ts is closed by direct runs for these eight outputs, not fixed in the launcher and not presumed closed for future runs.

Limits: focused, not blanket full-suite coverage; two existing scheduled reminder tests requiring Bun.serve remain excluded. No full Python type/lint/dashboard run, performance/stress/race study, or mutation pass claimed. Snapshot comparison is parsed JSON equality, not formatting equality. Tests passing cannot establish every environment-key or filesystem failure domain.

## Independent size accounting

Full git no-index numstat and exact file bytes against pinned bases, including new untracked files. Result bytes below are entire changed files, not whole repositories. metrics.json also includes a matched union-of-changed-paths inventory to avoid rewarding different unchanged-file inventories. Test helpers/generator code classified tests; fixtures and snapshots separate.

| Case / arm | Production + / − / churn | Production result / growth B | Tests + / − / churn | Tests result / growth B |
|---|---:|---:|---:|---:|
| Python V3 | 13 / 9 / 22 | 7043 / 287 | 114 / 37 / 151 | 13731 / 3480 |
| Python V2 | 14 / 5 / 19 | 7117 / 361 | 135 / 36 / 171 | 14668 / 4417 |
| Python Ponytail | 15 / 5 / 20 | 7066 / 310 | 136 / 38 / 174 | 23459 / 4336 |
| Python candidate | 18 / 6 / 24 | 7245 / 489 | 116 / 36 / 152 | 13906 / 3655 |
| TS V3 | 8 / 6 / 14 | 4719 / 61 | 287 / 4 / 291 | 20721 / 8656 |
| TS V2 | 8 / 6 / 14 | 4719 / 61 | 280 / 6 / 286 | 20479 / 8414 |
| TS Ponytail | 8 / 6 / 14 | 4719 / 61 | 315 / 0 / 315 | 10047 / 10047 |
| TS candidate | 8 / 6 / 14 | 4719 / 61 | 250 / 0 / 250 | 7941 / 7941 |

Only Ponytail Python adds fixtures **+3/−0,45 B** and snapshots **+1/−0,10816 B**; all other fixture/snapshot deltas zero.

| Arm, both cases | Production + / − / churn | Combined + / − / churn | Combined changed-file result / growth B |
|---|---:|---:|---:|
| V3 | 21 / 15 / 36 | 422 / 56 / 478 | 46214 / 12484 |
| V2 | 22 / 11 / 33 | 437 / 53 / 490 | 46983 / 13253 |
| Ponytail | 23 / 11 / 34 | 478 / 49 / 527 | 56152 / 25615 |
| candidate | 26 / 12 / 38 | 392 / 48 / 440 | 33811 / 12146 |

Matched inventory combined resulting bytes are **55086/55855/68217/54748**, V3/V2/Ponytail/candidate. Byte-growth comparisons above already neutralize unchanged-file inventory. Candidate's combined byte saving is heavily driven by Ponytail's snapshot volume; production itself is **179 B worse**, so no overall qualified size/quality win.

Per-case candidate loses Python production +3/churn+4/+179 B to Ponytail; TS production ties exactly. Combined Python improves +134/churn176 versus155/198, TS258/264 versus323/329. Candidate Python's extra helper return/None branch, docstring/comment and parameter ordering are not a reduced computation or new safeguard. Ponytail wrapping adds two otherwise presentation-only lines; V2's additional comment makes its bytes exceed Ponytail despite fewer raw lines. Stripped-nonblank production churn is **36/31/32/36**, combined **440/453/493/401**. Candidate's raw production loss survives that limited diagnostic, but neither diagnostic measures semantic efficiency. No deliberate gaming inferred.

## Remaining disposition

Production gate fails on this tuning draw, meaningful coverage exists with the snapshot-first instruction qualification, and one native recheck failure remains recorded with symmetric timing diagnostics. Repeated complete four-arm final draws and reserve/generalization evidence remain unresolved. No measured common-lifetime mechanism or specific new wording intervention established. Freeze unchanged only to prevent further adaptive tuning, with these objections carried forward; never publish this as same-or-better production success.
