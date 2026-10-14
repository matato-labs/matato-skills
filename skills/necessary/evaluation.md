# Necessary: evaluation record

`SKILL.md` is the only skill. This record is not another workflow and does not
need to be loaded when coding.

## Method

Ran **61 fresh implementation subagents**, making real source and regression-test
changes in disposable Git worktrees. Compared no skill, installed Ponytail
(default/full), and five Necessary versions. Each case began at its recorded
commit. No implementation was manually fixed or cherry-picked into the results.

Every implementation used Pi 1.1.0, `openai-codex/gpt-6.1-sol`, high reasoning,
`read,bash,edit,write`, and a 900-second budget. All completed without timeout.
Each case supplied identical requirements, repository-local conventions,
dependency access and acceptance command to its variants.

Automatic extensions, skills, prompt templates, global context-file discovery,
MCP and parent conversation history were excluded. Only the selected skill was
explicitly loaded/invoked, so the no-skill implementations did not inherit the
global Ponytail skill. Research subagents wrote behavioral acceptance checks
before implementation. Checks execute real production source and assert returned
behavior, not code size, style or skill wording. All nine checks fail on their
starting implementations. Research prompts instructed the holdout selector not
to read earlier outputs or draft skills; final artifacts alone cannot prove that
blindness or the absence of outside edits.

Four requested repositories were already checked out. `sintropy-engine`,
`mini-broker` and `exchange-broker` were absent locally and were cloned from the
owner's GitHub repositories under `/tmp`. Existing checkouts stayed unchanged,
including the blog's pre-existing untracked `PRODUCT.md`. Experiment changes were
not committed or pushed to those projects.

## Cases

[`results.json`](results.json) records exact briefs, commits, profile hashes,
changed files, per-run counts, acceptance exits and evidence checksums.

| Case | Project | Implementation language | Independent check |
| --- | --- | --- | --- |
| `matatoPi` | matato-pi | TypeScript | 18 tests: missing flag values, neighboring options, precedence and preserved values |
| `matato` | matato | TypeScript | 21 tests: shared optional/required flag errors and preserved values |
| `sintropyEngine` | sintropy-engine | Kotlin | 61 assertions: empty names, Kotlin whitespace and unchanged valid characters |
| `miniBroker` | mini-broker | Go | 6 tests: map/byte snapshot isolation, later writes, nil/empty distinctions |
| `exchangeBroker` | exchange-broker | Java | 172 assertions: filename comparison across path separators and null rejection |
| `personalBlog` | personal-blog | TypeScript | 24 JavaScript tests: directory boundaries, extensions and nonmutation |
| `atlas` | atlas | Python | 8 test methods, 39 input subcases: matching quote delimiters and preserved import fallbacks |
| `elixirHoldout` | matato-pi | Elixir | 9 tests: native identity, missed-start recovery, interleaving, precedence and UTF-8 argument caps |
| `atlasHoldout` | atlas | Python | 11 test methods: sparse file limits, validation, inheritance and real check/report callers |

The last two tasks were unseen for V2. Their observed results then informed later
revisions, so they are not an untouched final generalization set.

Kotlin/Java checks compile complete real target source with staged tools. Go
compiles the real cache package in a temporary directory. Other checks import or
require worktree source. No replacement implementations or mock parsers were
used. The Python feature also runs existing CLI callbacks through actual source
discovery, parsing, reporting and checking.

## Learning and revisions

Ponytail's useful mechanisms were scope discovery, existing-code/standard-library
reuse, root-cause fixes, rejecting speculative flexibility, retaining safety and
checking non-trivial behavior. Its answer protocol, levels and session activation
were not added. Neither were audit/review workflows. The installed source declares
MIT; its tested SHA-256 is recorded.

**V1 — seven cases.** Added a counterfactual necessity question for every addition,
while explicitly preserving integration, ownership, errors, empty values and
safety. All seven passed. Go found standard-library cloning and Python reused a
shared helper, but a simple CLI fix still expanded into extra exits.

**V2 — nine cases.** Preferred changing an existing expression before expanding
control flow; focused tests on distinct affected contracts instead of exhaustive
platform behavior. All nine pass the final oracle set. The larger Python feature
still created a parallel representation of an existing schema.

**V3 — nine cases.** Made reuse of types, schemas, validation and defaults explicit
and judged whole-diff churn. All nine pass. Python still added placeholder
defaults and rewrote existing field declarations, despite a smaller total diff.

**V4 — nine cases.** Required one authoritative set of defaults and existing
presence-tracking facilities for sparse updates. Python now shared the original
constraint/default declarations. Initially passed every check, but independent
patch verification found a missing Elixir requirement combination: flattened
identity precedence during native orphan recovery. The expanded oracle exposes
that failure. V4 is therefore rejected despite its low source count.

**V5 — nine cases, final.** Required recovery/fallback paths to share normal-path
precedence and error policy; tested interacting requirements in combination.
Also made a tiny executable self-check acceptable where no test framework exists,
and clarified the necessity argument for explanatory comments/helpers. All nine
pass, including the independently uncovered recovery case. The final skill has
no programming-language examples, repository names or evaluator instructions.

## Shared oracle changes

The first Python-feature oracle failed all three variants on two test mistakes:
its generated-directory fixture was excluded by existing discovery policy, and
it assumed a parameter finding was first despite other enabled rules having
unavailable measurements. The task forbids changing either behavior.

Added an empty root `.gitignore` to enable the existing discovery policy, and
selected the parameter finding by rule rather than list position. No source
changed. The corrected oracle still fails the base commit and passes the same
baseline, Ponytail and V2 implementations. Original oracle/failures are retained.

Independent patch verification later reproduced an Elixir bug missed by the
oracle: a native orphan delta carrying both valid identity formats must honor
flattened-ID precedence, just as a start does. Added those assertions, including
subsequent execution reusing that ID, inside the existing precedence test.
Reran **every existing Elixir variant without source changes**: no skill and V4
fail; Ponytail, V2 and V3 pass. V5 passes the expanded check. This adds coverage of
an existing requirement rather than changing the brief or relaxing acceptance.

Recorded current exits use these shared checks. Historical exits remain in
`results.json`; original logs/oracles remain in the raw evidence. Neither change
favored Necessary, and the V4 failure is not concealed by selecting another
iteration's implementation.

## Results

Correctness and contracts come first. **Diff churn** is added plus removed lines
from `git diff --numstat`, including whitespace/comments. Source and tests are
separate; dependency/venv links are excluded. Counts are not final file sizes,
cyclomatic-complexity scores or quality scores.

| Variant | Cases passed under final checks | Source churn | Test churn | Combined churn |
| --- | --- | ---: | ---: | ---: |
| No skill | 8/9 | 119 | 900 | 1,019 |
| Ponytail | 9/9 | 118 | 759 | 877 |
| Necessary V1 | 7/7 | 39 | 364 | 403 |
| Necessary V2 | 9/9 | 139 | 701 | 840 |
| Necessary V3 | 9/9 | 135 | 688 | 823 |
| Necessary V4 | 8/9 | 95 | 742 | 837 |
| Necessary V5 | **9/9** | **103** | **688** | **791** |

V1 has only seven cases; its total is not comparable with nine-case totals. V5 is
the complete final version, not each iteration's best patch combined.

| Case | No-skill source churn | Ponytail source churn | Final source churn |
| --- | ---: | ---: | ---: |
| matatoPi | 8 | 6 | 5 |
| matato | 6 | 6 | 2 |
| sintropyEngine | 2 | 2 | 2 |
| miniBroker | 17 | 16 | 12 |
| exchangeBroker | 4 | 4 | 4 |
| personalBlog | 5 | 5 | 2 |
| atlas | 11 | 6 | 6 |
| elixirHoldout | 44 | 57 | 57 |
| atlasHoldout | 22 | 16 | 13 |

Final source churn is about **12.7% below Ponytail**, with five cases smaller and
four equal. Combined churn is about **9.8% below Ponytail** and **22.4% below the
no-skill implementation**, which also fails one requirement. Net source growth is
45 lines versus Ponytail's 54; net growth and churn are different measures.
Some final test diffs are larger than Ponytail's when protecting distinct
contracts. The blog's source-churn reduction is formatting only; it is not a
semantic-complexity improvement.

Patch verification found shared fixes, retained copying/locking and boundary
validation, no new application dependencies and no unrelated production features.
Line counts alone cannot establish lower semantic complexity. The Elixir example
is direct evidence that a smaller patch can be wrong and must be rejected.

## Evidence and limits

Prompts, CLI invocations, patches, profile snapshots, independent oracles,
compiler metadata, logs and worktrees remain under `/tmp/necessaryEvaluation`.
The compact archive is `/tmp/necessaryEvaluation/archive/evidence.tar.gz`, excluding
cloned repositories, worktrees and compiler/dependency binaries. `results.json`
records archive, original-oracle, current-oracle, source-diff and current-log
checksums. Raw logs/oracles are not embedded in the PR and must be retained locally
for replay; checksums alone are not independent proof of the reported outcomes.

Locally, `runVariant.py <case> <variant>` creates a worktree, invokes the selected
profile and runs its oracle. Existing experiment worktree paths must be moved or
removed before replay. The compact PR record avoids shipping another runtime,
benchmark framework or coding skill.

One model, one sampling run per case/profile, six implementation languages and
nine bounded backend tasks do not establish statistical significance or universal
superiority. Larger cases became tuning cases; frontend, real hardware,
distributed/service integration and other providers were not evaluated. Some full
application checks were unavailable: Elixir Mix precommit lacked dependencies,
while reducer ExUnit and independent acceptance checks passed. These limitations
do not become language/environment-specific rules in the delivered skill.
