# V5 revisionOne mutation evidence

**Tie on this selected sample:** candidateOne **2 killed / 2 executed**, exact Ponytail **2 / 2**. Combined: **4 assertion kills, 0 survived, 0 invalid, 0 timeout, 0 inconclusive**. Selected-but-skipped: 0. Score means `killed / (killed + survived)`: **4/4**, separately **2/2 per arm**. Invalid/syntax/compile failures are not counted as kills. No superiority, equivalence, full-coverage or all-metric conclusion follows.

Only the two development projects below were evaluated, from **revisionOne**, not initial runs or HEAD alone. No holdout, model calls, installs, raw private/auth access, test changes or original-evidence metadata rewrite.

## Exact targets and isolation

candidateOne profile SHA-256: `7f02836af76a1594bf8e22fcdbc951915998b77d30d7e86e304072dab5809a47`; exact Ponytail: `ba68ff26239c3c3b05b2a9a47ee0d9a6b93a69639a2555ec87a5d44bffaf2f0c`.

Source: owned `harness/runs/revisionOne/SKILL.{7f02836af76a,ba68ff26239c}.native.{b6950eb46f87,9d07b1e583f4}/{workspaceCheckoutRoots,navigationUnseenEdgeBudget}/workspace` under `/home/leon/.cache/codingSessionV5/`. Exact absolute paths and hashes are in `mutations.json`.

TypeScript base: `7754bba086197ba0acce343dc62c560e6fcede0d`. Python base: `d403b16a2b68a07a11cc22679677bb2fd00dc8a4`. Copied all tracked/nonignored untracked paths with current uncommitted production edits, maintained tests and snapshots; preserved bytes, modes and dependency-symlink spelling. Inventories and `target.patch` live outside each disposable project. No ignored environments copied.

Existing `sandboxTrial.py` bubblewrap harness provided private network/PID namespaces, allowlisted read-only offline dependencies, no auth mounts and writable disposable source/runtime only. Every baseline and mutant command had **120 seconds**; process groups were stopped in finally cleanup. Budget: **at most four mutants total**, fully used.

```text
exact patched target → verified disposable copy → fresh whole-project Atlas scan
                     → passing maintained tests → one byte edit → same tests → verified restore
```

## Tool and selection

Used active `/home/leon/.t3/worktrees/atlas/t3-969945f4/atlas`, not installed Atlas main. Read skill, target instructions, catalog and `atlas/MUTATIONS.md`. Fresh generation used:

```sh
uv run --no-sync --offline --project /home/leon/.t3/worktrees/atlas/t3-969945f4/atlas atlas mutations -f PROJECT
```

Only disposable `atlas.json` received `mutations.rules`: `comparison.strict-not-equal-to-strict-equal`, `comparison.greater-equal-to-greater`, `arithmetic.add-to-subtract`; existing settings preserved. No saved index/database. Configs restored afterward. First scanner attempts failed on an unmounted interpreter alias against read-only tooling; `scan.*` retain failures. Corrected alias mounts and explicit offline/no-sync flags yielded successful `scanTwo.*` whole-project scans: candidateOne TS/Python **60/347**, Ponytail **60/348** manifests.

Selected four Atlas-issued manifests at the same two behavioral sites. Each full source SHA-256, canonical manifest identity, base64 original bytes and half-open byte span was verified; only the exact replacement bytes were applied. Diffs were inspected before execution. Manifest IDs, candidate IDs, full hashes, byte coordinates, commands and restoration hashes are in `mutations.json` and cache logs.

Of **815 generated manifests**, **4 selected/executed**, **811 unselected**; unselected is not a test outcome or an exhaustive relevance judgment. Test/fixture code and unrelated operators were excluded. Two recognized relevant Python `maxEdges` cutoff `>= → >` alternatives remain unexecuted because the budget favored the changed adjacency expression. Other traversal depth/node/distance/list-concatenation operators were not substituted. **Bash omitted:** catalog has no Bash mappings, hence no supported relevant candidates; no hand edits invented.

## Executed baselines

| Arm | Maintained command | Actual execution | Exit; elapsed |
|---|---|---|---|
| candidateOne | `bun test src/workspaceRepos.test.ts` | 5 passed, no skips | 0; 0.114s |
| exact Ponytail | same | 6 passed, no skips | 0; 0.114s |
| candidateOne | Python command below | 59 passed, no skips | 0; 40.675s |
| exact Ponytail | same | 59 passed, no skips | 0; 42.764s |

Python: exported disposable `PYTHONPATH="$PWD/atlas/src:$PWD/atlas"` and pinned tree-sitter library cache, then `cd atlas && /home/leon/workspace/projects/atlas/atlas/.venv/bin/python -B -m pytest -v -p no:cacheprovider --tb=short tests/test_graph_navigation.py tests/test_coffee_navigation_snapshots.py`. The same command/environment and dependencies were used for each corresponding mutant. Durations include sandbox setup and are descriptive, not comparative performance evidence.

## Per-mutant evidence

Cache root **`/home/leon/.cache/codingSessionV5/mutations/`**. Paths below are relative to it; exact commands/cwd/exits/durations are retained in each `baseline.json` and `mutant.json`.

| Arm; file/line | Rule/edit and changed behavior | Executed result | Semantic evidence/log |
|---|---|---|---|
| candidateOne; `src/workspaceRepos.ts:65` | `comparison.strict-not-equal-to-strict-equal`, `!== → ===`; reverses physical checkout-root guard | **Killed**; exit 1; 0.114s; 4 failed/1 passed | New real-Git checkout/symlink assertions at test line 90 receive ordinary folder + parent origin instead of child checkout; linked-worktree assertion also fails. `candidateOne/ts/mutant.stderr` |
| exact Ponytail; same file/line | Same matched guard regression | **Killed**; exit 1; 0.114s; 5 failed/1 passed | New checkout/nested/symlink assertions at test line 96 expose inherited parent origin; linked-checkout assertion also fails. `ponytail/ts/mutant.stderr` |
| candidateOne; `atlas/src/atlas/services/navigation_walk.py:46` | `arithmetic.add-to-subtract`, `max_edges + 1 → max_edges - 1`; loses finite lookahead and underfetches graph evidence | **Killed**; exit 1; 40.522s; 2 failed/57 passed | `test_coffee_navigation_matches_snapshot[python]` reaches new `inheritance_budget(1)`, `coffee_navigation.py:308`: expected edge count/path evidence assertion fails. Existing `test_context_cutoffs[maxEdges]` also incorrectly reports `truncated=false`. `candidateOne/py/mutant.stdout` |
| exact Ponytail; same file/line | Same matched adjacency-boundary regression | **Killed**; exit 1; 61.720s; 2 failed/57 passed | Same coffee test reaches new `exact_import_budgets()`, `coffee_navigation.py:334`: omitted-edge truncation/count assertion fails. Existing cutoff test also fails. `ponytail/py/mutant.stdout` |

These are behavioral assertion failures, not merely nonzero exits or snapshot regeneration. Newly authored regressions demonstrably reject plausible faulty production behavior **in both arms**. Existing tests also kill both operators, so this does not isolate incremental added-test value. A failing coffee assertion stops that scenario before all later assertions run.

## Restoration and limits

Every mutated source restored in finally; full hashes and complete target inventories verified before proceeding. Temporary `atlas.json` removed/restored; final disposable inventories/modes match original patched targets exactly. Original harness workspace inventories, Git status, patch hashes and original evidence-patch hashes remain unchanged. See cache `restoration.json`; no resets, staging, commits, source fixes or production configuration changes.

This is two selected sites per arm, not broad fault coverage. No full importer/dashboard, static type/lint/policy or acceptance rerun; no repeated flakiness study or holdout exposure. Original study validity/completion gates and all other metrics remain untouched. Atlas generated manifests only: results are this experiment’s files, not Atlas dashboard/session records.
