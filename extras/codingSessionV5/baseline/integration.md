# Exact Ponytail baseline

Source: [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail/tree/84740e3d344b69b4a133201fa519eb37a62a2b2a), commit `84740e3d344b69b4a133201fa519eb37a62a2b2a`, package 5.2.0. Retrieved into `/home/leon/.cache/codingSessionV5/upstream` with detached HEAD. Original default skill: 3492 bytes, SHA-256 `ba68ff26239c3c3b05b2a9a47ee0d9a6b93a69639a2555ec87a5d44bffaf2f0c`.

`provenance.json` inventories every copied path, SHA-256, byte count, Git blob and mode. All 49 files under `upstream/` are byte-exact Git blobs, not adaptations. The only authored files are this guide, `provenance.json`, `verifyBaseline.test.mjs`, and `checks.json` (53 additions total). Nothing is installed or auto-activated by placing this directory under `extras/`.

## Actual Pi activation

Paths below are relative to `upstream/`. This is a Pi-focused source subset, not the complete npm/cross-host distribution.

```text
package.json: pi.extensions + pi.skills
  ├─ pi-extension/index.js
  │    ├─ hooks/ponytail-config.js          default/config/command helpers
  │    └─ hooks/ponytail-instructions.js
  │         └─ skills/ponytail/SKILL.md     read and mode-filtered each run
  └─ skills/*/SKILL.md                     six discoverable skills/aliases
```

`package.json:40–43` declares the extension and skills. `pi-extension/index.js:183–260` restores branch mode, handles lifecycle/status, and injects instructions on **every `before_agent_start`**. `hooks/ponytail-instructions.js:9,77–92` locates the skill relative to the hook, removes frontmatter and other levels' rows/examples, and prepends the active-mode header. Missing skill silently uses an embedded fallback: successful loading alone does not prove the exact skill was used.

For a later authorized experiment, load the **package root**, not `pi-extension/` alone. From an isolated task workspace, with `baseline` set to this directory's absolute path:

```sh
# Example only: not executed here; no persistent install needed.
PONYTAIL_DEFAULT_MODE=full pi --offline --no-extensions --no-skills \
  --no-prompt-templates --no-context-files --no-mcp --no-approve \
  -e "$baseline/upstream" --skill "$baseline/upstream/skills"
```

Pi 1.2.0 permits explicit `-e`/`--skill` even when discovery is disabled. The manifest exposes skills too; the explicit skill root makes that requirement visible. Alternatively explicitly load `-e "$baseline/upstream/pi-extension/index.js"` **and** `--skill "$baseline/upstream/skills"`. Use a fresh `PI_CODING_AGENT_DIR` and isolated Ponytail `XDG_CONFIG_HOME`/HOME; do not reuse personal settings or resumed sessions. Supply credentials/model only in a later approved model run. `--offline` suppresses automatic network work, **not model requests or extension network access**.

`/ponytail full|lite|ultra|off` changes session mode; bare `/ponytail` enables the configured default (full if default is off), or reports an already active level. `/ponytail status` reports; `/ponytail default <mode>` **writes config**, not the current session mode. Exact standalone `stop ponytail` / `normal mode` deactivates (case/trailing punctuation ignored); incidental mentions do not. Branch custom entries `ponytail-mode` restore the latest branch mode on startup/navigation. Legacy persisted `review` is honored, but `review` is not a selectable runtime/default level. Off removes future injection; it cannot erase instructions already in conversation history.

`/ponytail-review`, `-audit`, `-gain`, `-debt`, `-help` forward to their `/skill:ponytail-*` commands with `expandPromptTemplates: true`; busy sessions queue follow-ups. The five associated skills must be discoverable. `/skill:ponytail` alone loads raw text, including all level rows; it does **not** establish the extension's mode state or lifecycle.

## Scripts and configuration

| Original resource | Behavior / needed configuration | Used by native Pi? |
|---|---|---|
| `hooks/ponytail-config.js` | Default: `PONYTAIL_DEFAULT_MODE` > config `defaultMode` > full. Config: `$XDG_CONFIG_HOME/ponytail/config.json`, else `~/.config/ponytail/config.json`, Windows `%APPDATA%/ponytail/config.json`. Runtime levels off/lite/full/ultra. `PONYTAIL_QUIET_STARTUP`/`quietStartup` silence toast; `PONYTAIL_HIDE_STATUS`/`hideStatus` hide badge, not rules. | Yes |
| `hooks/ponytail-instructions.js` | Builds filtered instructions from original skill; fallback embedded in script. No dependencies beyond Node built-ins. | Yes |
| `hooks/ponytail-activate.js` | SessionStart: resolves mode, writes flags, emits rules, optionally adds map, refreshes statusline copy and may emit setup nudge. Compact trigger preserves live mode. Stdin/error/1-second fallback. | **No** |
| `hooks/ponytail-mode-tracker.js` | UserPromptSubmit: consumes JSON `prompt`, switches flags/default, recognizes off commands; some hosts get replacement instructions. Qoder injects every prompt. | **No** |
| `hooks/ponytail-runtime.js` | Host-specific flag paths/output formats; shared `.ponytail-active` plus SHA-256 project key from `CLAUDE_PROJECT_DIR`. Same-project sessions can collide. Hosts selected via plugin/session env. | **No**; Pi uses branch entries instead |
| `hooks/ponytail-map.js` | Git-listed files or directory walk; regex symbol map, bounded file/character budget; `PONYTAIL_MAP=0` disables activation-hook invocation, `PONYTAIL_MAP_CHARS` defaults to 2000. Activation gives subprocess a 1-second timeout. | **No** automatic map in Pi |
| `hooks/ponytail-subagent.js` | Injects live rules on SubagentStart. Optional `PONYTAIL_SUBAGENT_MATCHER` regex on JSON `agent_type`; timeout/invalid matcher fail open. | **No** native Pi subagent hook |
| `hooks/ponytail-statusline.sh`, `.ps1` | Read first line of shared flag under `CLAUDE_CONFIG_DIR` or `~/.claude`; render level badge. Bash or PowerShell required only for that host path. | **No**; extension uses Pi UI status |
| `hooks/{claude-codex,copilot,cursor,qoder}-hooks.json` | Original external-host event/command wiring and plugin-root placeholders. Preserved, not registered in Pi. | No |
| `scripts/cursor-hooks.js` | Explicit install/uninstall merges/removes Ponytail entries in user or `--project` Cursor hooks. Replaces `PONYTAIL_DIR` with checkout path. | No; do not run for Pi |
| `scripts/uninstall.js` | Destructive cleanup of Ponytail config, flags, copied statuslines and external-host settings/hooks. No automatic install/uninstall lifecycle in root manifest. | No; do not run against live HOME |
| `skills/ponytail-gain/SKILL.md` | Static published **Claude Code** scoreboard; does not measure this repo or Pi. Cites report retained under `benchmarks/results/`. | Text alias only |

There are no third-party runtime imports in the native Pi closure. Root `package.json` is preserved unchanged: its OpenCode `main`/`exports`, some `files` entries and the full upstream test distribution are outside this subset. Do not treat this as a general npm/OpenCode package or call its selected tests the entire upstream suite. Release/publish/build scripts are not needed for Pi and were omitted. Original names and the oversized `benchmarks/agentic/tasks.py` remain unchanged to preserve source rather than apply house naming/splitting rules to third-party code.

**Runtime versus text-only:** preserving/loading the native extension gives the upstream Pi activation mechanism, not Claude Code runtime equivalence. Claude's activation hook adds the map, flag/statusline machinery, and subagent injection; Pi does not invoke these. Pasting or appending SKILL.md is a separately labeled **text-only** arm, not full runtime equivalence to either host. No map/subagent adapter was added. Native tests below exercise the original mocked Pi contract, not a live Pi/provider session. Installed CLI docs are 1.2.0; installed repository SDK dependency is 1.0.4 and was not substituted as evidence for that CLI.

## Every upstream benchmark metric → Pi measurement

Authoritative retained definitions: `benchmarks/{loc,correctness,behavior}.js`, four YAML task/probe configs, `benchmarks/agentic/{run,tasks,compare,judge,complete,answer}.py`, and four reports in `benchmarks/results/`. Other upstream documentation is referenced with hashes in provenance rather than copying READMEs or the entire benchmark. These definitions can be applied to preserved Pi outputs; **the original runner invokes `claude`, not Pi**. No Pi benchmark runner/adapters or new results are supplied here.

Collect a fresh isolated workspace, initial Git snapshot, final files/diff, complete Pi JSONL and final assistant reply for each task × arm × repetition. Keep failures/timeouts as failures with their actual spend. Obtain usage once from each finalized assistant `message_end`, not streaming snapshots plus `agent_end` duplicates. Preserve compaction/cache-warming/nested-tool usage separately when applicable so total session cost is not understated. Measure wall time with a monotonic clock through `agent_settled` (not the first `agent_end`).

| Original metric(s) | How to measure on Pi / original qualification |
|---|---|
| Single-shot `code_loc` (`loc` in older prose) | Feed final response to `loc.js`: fenced blocks, or entire unfenced response; remove block comments and blank/comment lines. Always-passing measurement, not correctness. Bare prose can be counted. |
| Single-shot `correct` | Feed final response and original task to `correctness.js`. Email/debounce/CSV execute Python/Node; CSV good-reference test needs pandas. React countdown and FastAPI rate limiting are **structural regex only**, not runtime proof. Unknown task is skipped/pass, so preserve denominators. |
| Single-shot tokens, USD cost, latency | Sum finalized provider usage/cost for that one call; record elapsed request time. Original API telemetry and 10-repeat per-cell medians (30-repeat cost recheck) are not multi-turn session totals. |
| `behavior`: hardware, explanation, onecheck | Apply `behavior.js` with each `behavior.yaml` probe. Hardware checks actionable calibration/drift wording; explanation checks ≥45 prose words plus structure/reason wording; onecheck finds assert/test/demo syntax. Heuristics do **not** prove calibration or executable tests. |
| Agentic `correct`, `safe`; `pass`, hidden-check pass rate | Run each `tasks.py` scorer on delivered workspace. Pass = correct AND safe. The 18 surgical tasks have hidden checks; `safe` also carries root-cause/reuse/scope/convention quality, not security alone. Six security/cache cases are also reported as their own denominator. Template pass only means nonzero added code; vibe pass means Python compiles; open examples unconditionally pass: do not claim quality for those 21 headline tasks. |
| Root-cause-fix / reuse / scope / convention rates | Report named task scorer axes separately: `trace-*` checks unnamed sibling callers; `reuse-*` checks distinctive project-helper behavior; `scope-*` checks callers/CLI/fixtures/tests/privacy; `conv-*` checks services/provider seam/house dialog. `conv-ui` is static, not a browser test. |
| `files`, `src_files`, `total_loc`, `src_loc`, `test_files`, `test_loc` | Apply `run.py` `code_stats` or `git_diff_stats`. Source/test separated; surgical Python main/demo self-check tails move to test LOC. Whole-file `total_loc` = nonblank source incl comments/docstrings, `src_loc` excludes comment-prefix lines (not a parser). Snapshot tasks count **added** source lines incl comments, not net churn, and changed source/test files; generated/lockfiles skipped. Preserve seeded-file exclusion and code extensions. |
| `gz_code` / “code information (gzip)” | Exact `run.py:gz`: UTF-8 **raw DEFLATE**, level 9, window -15, byte length, not a `.gz` archive. Compress delivered source (added source lines for diff tasks); original whole-file mode still includes in-file self-checks in compressed source. |
| Chat-delivered source LOC | If open task has no source LOC, `chat_code_loc` counts fenced reply code and marks source file count 1 when nonempty. Preserve original limitation: this fallback does not recompute `gz_code`, so chat gzip can stay zero. |
| `in_tokens`, `out_tokens`, `cache_tokens`, total tokens | Map Pi finalized usage `input`, `output`, `cacheRead + cacheWrite`; total = all four components. Record provider/cache accounting and reasoning-token convention; do not add provider `totalTokens` again. Missing telemetry is unavailable, not free. |
| `cost`, mean cost/session, `cost_per_pass` | Sum recorded Pi USD `usage.cost.total` including cache components; report rate-card/version and missing prices. Mean is arithmetic mean; cost/pass = **all** cell spend / cells passing both gates (undefined if none). Preserve unsuccessful spend. |
| `duration_ms` / time / latency / speedup; `turns`; `denials` | Record monotonic whole-run duration, count Pi `turn_end` events (one assistant/tool batch, not one session), and actual blocked/permission-denied operations. Pi and Claude have different turn/permission semantics; never manufacture CLI `num_turns` or `permission_denials`. Zero shell availability is not a denial. |
| `reply_words`, `reply_density` (`words`, `density`) | Final reply whitespace word count; raw-deflate bytes / max(1, UTF-8 bytes), rounded to 3 places. Reported, **not inherently better lower/higher**; density is not a quality grade. |
| `safe_rate`, `correct_rate`, `wrote_file_rate`, `wrote_tests_rate` | Use original `aggregate` denominators including failed cells. `wrote_file_rate` actually means `total_loc > 0`, including chat fallback; `wrote_tests_rate` means `test_files > 0`, so embedded self-checks alone do not raise it. |
| Original summary statistics | `aggregate`: nonzero-delivery LOC median/max, source-file median, reply-word median; arithmetic cost/output-token/total-token/time means and cost/pass. `compare.py`: per-task medians or mean rates/quality, task wins/losses/ties, two-sided binomial sign-test p, **median** B/A ratio. It does not produce the report's geometric means or bootstrap intervals. |
| Headline % savings, geometric means, 95% bootstrap CI, cheaper/better task counts | The October report takes each task's 5-run median ratio, geometric mean over eligible tasks and a task-bootstrap 95% interval; report task sign tests too. Explicitly preserve exclusions (zero/timeouts), bootstrap method/seed/resamples, and denominators; original headline uses 39 tasks, some cost comparisons 38. Pin these choices before a Pi experiment; no bootstrap implementation ships at this pin. |
| `over_engineering` | `judge.py` published 0–3 rubric, lower better, source-only intent, cited unnecessary construct; validate minimal < overbuilt references before judging. Original source collector is filename-based and does not universally exclude nested tests or seeded repo code: audit actual submissions, do not overstate isolation. Judge model defaults Sonnet 4.6, temperature 0 API. |
| `completeness` / fully implements (3/3) rate | `complete.py` rubric 0 stub → 3 complete, higher better, for `vibe-*`, `open-*`, `tmpl-*`. Judge actual diff for fixture tasks or source/chat otherwise; neutralize Ponytail markers, separate timeouts, live reference gate first. Report excluded cells and any manual overrides (October report overrides one alleged missing-import finding). |
| Reply `accuracy`, `coverage`, `clarity` | `answer.py` blind reader sees task/reply only, grader sees reader notes plus real diff; each axis 0–3, higher better. Require good reply to outrank false/terse/essay references respectively. Preserve rubric, judge model/version and truncation limit (20,000 diff characters). |
| Reply preference wins/losses/ties, pairwise p; real-run and same-code comparisons | `answer.py` pairwise rubric, seeded shuffled order, matched task/repetition; validate good beats bad in both positions. Report two-sided sign p excluding ties. It supports own-diff pairs; **same-code reply generation is absent** and requires a separately frozen protocol, not reuse of independently generated diffs. |
| Tests needed / not needed; runnable tests; bugs caught overall / where tests exist | October report classifies 22 need / 11 don't / 6 borderline tasks, checks test presence/execution (90 surgical cells), then runs authored tests against isolated realistic mutants. Preserve separate necessity classes, runnable counts, overall and conditional mutation denominators; syntax failures/timeouts are not assertion kills. **Classification matrix and mutation tools are absent**, despite report saying they ship. Proposed Pi measurement needs frozen labels, runnable commands, mutants and eligibility rules before claims. Do not substitute `wrote_tests_rate` for the 98% necessity metric. |
| Review planted-problem recall; outside-diff problem recall | Root README image text advertises 100% vs 87%, outside-diff 100% vs 78%. On Pi explicitly activate `/ponytail-review` on frozen seeded defective changes and score verified findings/all planted defects, separately for unchanged callers. **Fixtures/graders/denominators absent** at pin; these are unreplicated claims, not established Pi baselines. |
| Audit ranked findings / lean lines & dependencies; debt markers/no-trigger count | Audit example/skill reports ranked concrete problems and estimated removable lines/dependencies; debt counts marker comments and missing upgrade triggers. Pi aliases load exact skills; independently confirm cases, line/dependency estimates and grep ledger. No published numeric audit benchmark or grader at pin; do not invent one. |
| Historical A–F build/extension/reviewability metrics | June hardening report: nonblank Python LOC/files, extension insertions + new-file LOC, files touched, post-extension correctness/demo exits, 8 security + 6 concurrency probe passes, runnable checks, and shortcut ceiling/upgrade-path presence. On Pi preserve phase-1 snapshot and surprise extension ticket, run demos/probes, inspect comments. Original reconstructed specs, scorer and probes live outside pinned repo: **exact reproduction blocked**, not equivalent to current tasks. |
| Historical weak-model robustness / validator accuracy | June audit: per-task edge-case pass fractions, email/URL/card/IPv4 acceptance checks, API-error denominator exclusions and return-type artifacts. Apply original known-good/bad checks to Pi single-shot output only after recovering them: scripts removed at pin; report identifies older ref `08e952d7a8057a57ce561ff1330d093fd92eec67`. Not retrieved or run here. |

Independent external benchmark figures linked upstream are corroboration, not additional defined instruments in this source: statements/code size, correctness/security, bad-input handling, tool calls/tokens/process cost and completion/blocked-task behavior need their own pinned tasks/graders. On Pi count top-level tool-call IDs separately from nested calls, record bad-input regressions and completion status; do not claim those external results were reproduced. No external benchmark/tool was fetched.

## Experiment and evidence boundary

For a later Pi comparison, hold task bases, instructions, provider/model, thinking, tools, time/token caps, dependencies and verification policy identical, randomize/interleave arms, and retain per-cell artifacts. Original headline Claude runs disabled Bash/MCP and added `NO_RUN`; normal Pi with Bash/tests enabled is a different experiment. Declare that difference rather than silently matching a headline. Disable personal/project/context contamination equally; for baseline enable the native package, for control/candidate do not discover Ponytail's skills/hooks/AGENTS. Verify the actual injected filtered body and alias expansion before spending. Never use a shorter diff to compensate for failed correctness/safety/completeness.

**Checks performed:** `checks.json` retains commands, exit codes and output. Node 25.9.0 / Python 3.14.7: 3 inventory tests, 30 native Pi mock tests, 31 selected grader/map tests, 34 good/bad reference evaluations for 17 surgical tasks plus four runner checks; completeness/reply offline gate logic. One pandas-dependent test excluded without installing anything; `todo-null` local HTTP references excluded to honor source-retrieval-only network policy. No models, live Pi session, external hooks, judges or benchmark runs executed. Offline judge gates only validate gate logic, not model judging quality.

Recheck exact bytes and native integration contracts from this directory:

```sh
node --test verifyBaseline.test.mjs upstream/pi-extension/test/*.test.js
```

A plausible integration regression is copying only SKILL.md or losing relative hooks/skill paths: inventory/native tests detect missing bytes, filtered-body regressions, off/branch restoration and alias forwarding. They cannot prove a particular Pi binary actually sends that context to a provider; that requires the later authorized host smoke check.

**License/risks:** MIT copyright and permission notice retained verbatim in `upstream/LICENSE`; keep it with copies/derivatives. No Caveman source or external fixture was vendored, so no additional third-party license bundle was introduced. The source pin is content identity, not a signed security audit. Extensions execute with host permissions; cleanup/activation scripts can write outside the checkout if run. README files, live skills, runtime code, settings and all other V5 paths remain untouched. This preparation makes no performance, superiority or cross-host runtime-equivalence claim.
