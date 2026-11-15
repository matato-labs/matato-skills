# Testing quality v2: five-project evaluation

## Decision

Keep `testing-quality` unchanged. Add `skills/testing-qualityv2/SKILL.md` as an alternative. The main improvement is restraint: no tests for scripts, prose, CI, or configuration, even through temporary harnesses or extensions to existing tests. Business tests still exercise real behavior and reuse existing scenarios.

The first paired round received independent ratings of **7.8/10 for the existing skill and 9.8/10 for v2**. V2 scored higher on four projects and tied on VU. The reviewer found material differences in the two artifact-only tasks, small differences in the business tasks, and no demonstrated production correctness advantage. These are qualitative ratings from one model, not a statistical benchmark.

## Method

Ran 11 implementation agents: five baseline agents, five fresh v2 agents, then one fresh VU refinement agent. All used `openai-codex/gpt-6.1-sol`, high thinking. Each received the same task and common safety/evidence instructions; only the assigned testing skill differed between paired runs. Agents were told not to load competing testing/verification skills or delegate work. Repository instructions still applied.

T3 rejected five cross-project worktree requests before starting agents. Successful agents instead used the clean repositories below, with only one active implementation agent per repository. Each saved a full patch and report, reversed only its own patch, and confirmed a clean tree and unchanged HEAD. No experimental change was committed, deployed, or retained in those projects. All baseline runs finished before the v2 round. These were **not isolated worktrees**; unrelated user edits during a run would have invalidated the clean-state assumption.

An independent reviewer received label-masked X/Y reports and patches, with pair order alternated. It did not receive the skill files, inspect projects, or execute checks. Report wording could reveal the instructions, so this was not fully blind. The reviewer used five dimensions, each scored 0–2: excluded-artifact discipline; existing-scenario reuse; business outcomes or justified absence; focused maintenance and independent expectations; honest evidence and regression sensitivity. Test count earned no points. The rubric was fixed for the reviewer before scoring, but after implementation runs; it was not preregistered.

Raw patches are linked below. Complete agent reports, command logs, prompt snapshots, and the baseline temporary harness remain locally at `/tmp/testingQualityv2Evaluation1794751980843/`. The harness is not shipped. It is an example of behavior v2 rejects, not a recommended test.

## Tasks and starting revisions

All projects are under `~/workspace/projects`.

| Project | Starting HEAD | Same task for both skills |
| --- | --- | --- |
| `matato-pi` | `7083b2fe6f94d361a9fd175345f69d67a6708dd5` | Trim automation names on create/update. Reject blank and normalized duplicate names without partial writes. Preserve prompts. |
| `matato-proxy` | `5a2e2226d0c130eb89f3610ffe82fdff124b4e0b` | Trim persisted failure text for HTTP/internal delivery failures. Keep the raw 2000-character limit, blank rejection, retries, and terminal behavior. |
| `VU` | `622c72917ebcf5bec501653cd037d4f4878df29b` | Reject NUL descriptions with a clear error through app/crawler writes without persisting reports. Preserve other validation. |
| `agent-habitat` | `4237e48daf1ca572a57e59cb29880a9fd5c9ee22` | Reject surplus `setup --copy-pi-auth` arguments before credentials/DevPod access. Clarify that an unrun completion check cannot be reported passed in `prompts/wake.md`. Never run bootstrap or credential transfer. |
| `personal-blog` | `46ac6b08ed874f31ea8d0d63597e491bdbffba8f` | Add a package description and least-privilege `contents: read` CI permissions. The permission was already present; both agents correctly left it unchanged. |

The baseline skill came from this package at `389e8a4284548ddfcaee2954915f0ce3be0c9b1a`, not a different installed copy. It already said scripts must not have corresponding tests.

| Instruction snapshot | SHA-256 |
| --- | --- |
| Existing `skills/testing-quality/SKILL.md` | `0f9f3388667d35dd90d776a6eea97bbad3dece0fc9476308d0ba3045425c23a8` |
| V2 first paired round | `06f3583bf76785129cc4148a7d910bc13b511af8a59ddc43390fe70e4f991c17` |
| V2 final, used for the VU refinement | `8e7c6d259fc1ffc6e3ab3efb4c617094c42ce3d892fc0f0b4d59b0d4a36153fb` |

## First paired round: independent ratings

Dimension order: exclusions / reuse / business / focus / evidence. See [the complete independent review](review.md), including objections and coverage trade-offs. X/Y mapping: baseline=X for Pi, VU, and Blog; baseline=Y for Proxy and Habitat.

| Project | Existing skill | V2 | Observed difference |
| --- | --- | --- | --- |
| `matato-pi` | 2/2/2/1/2 = **9** | 2/2/2/2/2 = **10** | Both verify normalization and rollback. Baseline also extends six unrelated invalid-update rows. V2 changes only the relevant existing workflows. |
| `matato-proxy` | 2/2/2/1/2 = **9** | 2/2/2/2/2 = **10** | V2 uses independent expected values and existing boundary cases. Baseline repeats `.trim()` in an HTTP expectation, but covers changing error text across retries better. Small trade-off, not a decisive overall win. |
| `VU` | 2/2/2/1/2 = **9** | 2/2/2/2/1 = **9** | Baseline duplicates NUL positions across validator/store layers. V2 is smaller, but `/Description/` does not require an explanation of NUL. Tie. |
| `agent-habitat` | 0/2/2/0/2 = **6** | 2/2/2/2/2 = **10** | Baseline creates a temporary seven-check Python harness for script behavior and prompt text. V2 uses Bash syntax validation and manual review only. |
| `personal-blog` | 0/2/2/0/2 = **6** | 2/2/2/2/2 = **10** | Baseline extends a package-metadata test and adds an inline CI-text assertion. V2 validates JSON syntax and reviews permissions without tests. |
| Mean | **7.8** | **9.8** | Five paired tasks; not a prediction for all projects. |

All business patches reuse existing fixtures and test declarations. No arm added a test file to a project. V2 changes no tests in the two artifact-only projects. The baseline harness lived outside its project, which explains why its saved project patch contains no test file.

## Refinement history

The initial draft already excluded artifacts and preferred business boundaries. Baseline observations led to three changes before the v2 paired round: explicitly include temporary/inline tests in exclusions; avoid unrelated parameter-row expansion and duplicate layers; require independent expected values rather than repeating the production transformation.

The independent review then found the VU error-specificity weakness. Added one general sentence: when rejection must explain a restriction, assert the field and cause without pinning the complete message. A fresh VU agent received the same original task and final skill, without the earlier patch or task-specific test advice.

The refined patch extends one existing storage scenario with one embedded-NUL row, expects `/Description.*NUL/i`, calls both write paths, and checks the actual report table remains empty. It does not add helper-layer scenarios. The first run failed on SQLite's generic constraint error; after the fix, 55 backend tests and all 124 application tests passed. The final sentence was exercised on VU only; the other four projects were not rerun after that refinement.

## Verification evidence

Commands below ran from each project's root with its experimental patch applied. Full logs and environment details are in the local reports. Fail-before means changed tests with original production code, not a setup failure. Syntax checks are not runtime proof.

| Project / arm | Focused command and actual result | Other actual checks |
| --- | --- | --- |
| Pi baseline | `npm test -- tests/automations.test.ts`: 2 failed before; `npm test -- tests/automations.test.ts tests/apiCatalog.test.ts`: 22 passed after | `npm run check` and `matis check -f .` passed. Initial full suite had one packaging failure; isolated retry and full retry passed, final 1781 passed / 12 skipped. Cause not proven. |
| Pi v2 | Same focused commands: 2 failed before; 22 passed after | `npm run check` passed. Full suite, browser, build, and separate Matis check not run. |
| Proxy baseline | `npm test -- tests/queue.test.ts tests/bots.test.ts`: 2 failed before; 52 passed after | `npm run check`, `matis check -f .`, and full `npm test` passed: 502 tests. |
| Proxy v2 | Same focused command: 2 failed before; 48 passed after | Same other checks passed: 498 full-suite tests. |
| VU baseline | `npm test -- tests/backend.test.ts`: 8 failed before; 62 passed after | TypeScript, Atlas report/check, build, 131 application tests, and 2 required Python tests passed. |
| VU v2 | Same focused command: 2 failed before; 56 passed after | Same other checks passed: 125 application tests and 2 Python tests. |
| VU refined | `npm test -- tests/backend.test.ts -t 'validates descriptions for both sources'`: 1 failed before; `npm test -- tests/backend.test.ts`: 55 passed after | Same other checks passed: 124 application tests and 2 Python tests. |
| Habitat baseline | `python3 /tmp/testingQualityv2Evaluation1794751980843/baselineagentHabitatChecks.py`: 3/7 before, 7/7 after | Includes mocked script behavior, a prompt-text assertion, and Bash syntax. Excluded test creation under the user's rules, despite being temporary. |
| Habitat v2 | `bash -n setup`: exit 0 | Manual guard-order/prompt review; no tests or runtime invocation. ShellCheck unavailable. |
| Blog baseline | `bun test packageMetadata.test.js`: failed before; full `npm test`: 9 passed after | Inline Node assertion pins CI text. These metadata/CI assertions violate the user's preferences. |
| Blog v2 | `python3 -m json.tool package.json > /dev/null`: exit 0 | Manual workflow review; no test changes, test execution, or build. |

All agents reported passing `git diff --check` and clean final repository status. The parent also checked all five project statuses after both paired rounds. Existing script tests ran in VU because repository instructions required them; neither skill arm added such tests there.

The before-fix business scenarios often stop at their first app/create assertion. They do not independently prove crawler/update fail-before behavior. After-fix runs execute those assertions. The old VU database already rejected NUL: the change adds a clear validation error, not a new database integrity guarantee.

VU dependency installation reported one moderate vulnerability. Builds emitted existing chunk/directive warnings. No dependencies were upgraded. No browser, live deployment, hosted CI, or credential-transfer claim is made. Pi's existing global uniqueness and legacy padded-name handling were not changed. These experiment patches are evidence, not release-ready fixes for those projects.

## Raw project patches

| Project | Existing skill | V2 first round | Final refinement |
| --- | --- | --- | --- |
| Pi | [patch](baselineMatatoPi.patch) | [patch](v2MatatoPi.patch) | — |
| Proxy | [patch](baselineMatatoProxy.patch) | [patch](v2MatatoProxy.patch) | — |
| VU | [patch](baselineVu.patch) | [patch](v2Vu.patch) | [patch](refinedVu.patch) |
| Habitat | [patch](baselineAgentHabitat.patch) | [patch](v2AgentHabitat.patch) | — |
| Blog | [patch](baselinePersonalBlog.patch) | [patch](v2PersonalBlog.patch) | — |

Patch paths and context belong to their source projects. They are not active tests or changes to this package. Do not apply them to this repository. Committed copies omit the space on empty context lines; original byte-for-byte patches remain in the local evidence directory. This preserves patch applicability while avoiding trailing whitespace in this repository.

## Package verification

A separate verification agent ran `npm ci`, `npm run check`, `npm run lint`, and `npm test` sequentially in this package. All exited 0; all 60 tests passed, with no skipped tests. npm reported zero vulnerabilities, one deprecated dependency, and install-script approval warnings. No approvals or dependency changes were made. `pi.skills: ["./skills"]` already includes the new directory; frontmatter was reviewed manually. No skill-content test, benchmark runner, global install, or README change was added. Existing package tests verify package code, not the quality of these instructions. Full report: `/tmp/testingQualityv2Evaluation1794751980843/packageVerification.md`.
