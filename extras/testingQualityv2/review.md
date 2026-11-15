# Independent review

## Scope and scoring

I read only `blindReviewInput.md`. I evaluated its ten patches and reported evidence. I did not read source skills, repositories, external logs, or harness files. I ran no commands, launched no agents, and made no project changes. This is label-masked, not fully blind; I did not infer arm identities.

Each dimension scores 0–2: **D1** excluded-artifact discipline; **D2** existing-scenario reuse without contortion; **D3** business outcomes, or justified absence; **D4** focused maintenance cost and independent expectations; **D5** evidence integrity and regression sensitivity. Two means strong, one means a specific limitation, and zero means a clear failure. Passing more tests earns no extra credit. Reported command results are not independently verified logs.

| Task | Output | D1 | D2 | D3 | D4 | D5 | Total /10 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| matatoPi | X | 2 | 2 | 2 | 1 | 2 | 9 |
| matatoPi | Y | 2 | 2 | 2 | 2 | 2 | 10 |
| matatoProxy | X | 2 | 2 | 2 | 2 | 2 | 10 |
| matatoProxy | Y | 2 | 2 | 2 | 1 | 2 | 9 |
| vu | X | 2 | 2 | 2 | 1 | 2 | 9 |
| vu | Y | 2 | 2 | 2 | 2 | 1 | 9 |
| agentHabitat | X | 2 | 2 | 2 | 2 | 2 | 10 |
| agentHabitat | Y | 0 | 2 | 2 | 0 | 2 | 6 |
| personalBlog | X | 0 | 2 | 2 | 0 | 2 | 6 |
| personalBlog | Y | 2 | 2 | 2 | 2 | 2 | 10 |

## matatoPi

**X:** D1=2: only application behavior received test changes. D2=2: the existing CRUD, rollback, and validation fixtures fit the operations. D3=2: literal trimmed names, exact prompt preservation, persisted reads, duplicate rejection, and rollback address the requested outcomes. D4=1: extending all seven invalid-create rows to invalid updates adds six unrelated field cases beyond the name requirement. The extra unchanged flags in the successful update also broaden the assertion surface. D5=2: the reported failing assertions identify untrimmed creation and accepted padded duplicates. The report correctly says those failures stopped before update assertions. The failed full-suite run and successful retries remain disclosed, without claiming a proven cause.

**Y:** D1=2: no excluded-artifact tests. D2=2: two existing workflows cover successful writes and rejected writes without another fixture. D3=2: create/update normalization, blank update rejection, prompt preservation, persisted reads, and full rollback are checked. The existing blank-create case remains. D4=2: literal expected names and narrowly added assertions keep maintenance focused. D5=2: reported failures match the changed assertions; update fail-before sensitivity is explicitly not claimed. Focused service/API execution and repository checks are proportionate.

**Coverage and production correctness:** Y replaces exact duplicate inputs with padded equivalents; X retains both. This removes explicit unpadded duplicate examples from that scenario, but padded rejection still exercises normalization followed by uniqueness. No important coverage loss is demonstrated. Both patches use the identical shared `.trim()` expression and preserve prompt handling. Neither adds migration or normalized lookup for legacy padded rows. Those rows remain a possible limitation if the task requires collisions against previously stored, unnormalized names; the supplied material does not establish that requirement or a confirmed defect.

**Materiality:** Y has a small test-selection advantage. The production changes are identical; no material implementation difference. X's larger full-suite count earns no advantage.

## matatoProxy

**X:** D1=2: tests concern application persistence and HTTP behavior. D2=2: existing retry and invalid-input scenarios provide the right setup. D3=2: direct mutation and HTTP tests check trimmed persistence, raw length limits, rejection, retry counts, and terminal behavior. D4=2: literal expected `retry  later` and known-length strings are independent of the implementation. Both entry paths are justified: HTTP must not trim before raw-input validation. D5=2: reported pre-fix persistence failures directly match the requested regression. Padded 2001-character rejection specifically detects premature trimming.

**Y:** D1=2 and D2=2: the same relevant artifacts and existing scenarios are used. D3=2: it retains unpadded boundaries, adds padded boundaries, and compares complete internal state after rejection. Different error text across retries also checks that later failures replace `lastError`. D4=1: the HTTP expectation uses `lastError: error.trim()`, repeating the exact production operation rather than specifying an independent result. Extra parameter rows are not inherently wasteful; their raw-versus-trimmed boundary risk is concrete. D5=2: independent internal expectations and reported HTTP/internal fail-before results still provide meaningful sensitivity. The derived HTTP expectation weakens independence, not all evidence.

**Coverage and production correctness:** X replaces unpadded over-limit examples with padded over-limit examples. The latter still enforce the raw limit and add sensitivity to validation order; this is not an important demonstrated loss. X repeats one error across retries, so it does not check replacement with different text. Y does. Both make the identical persistence-only change, leaving validation and terminal transitions in place. No production defect is established.

**Materiality:** Small trade-off, not a decisive overall winner: X has more independent HTTP expectations; Y has better overwrite coverage. More parameter rows and passing tests do not determine quality.

## vu

**X:** D1=2: no excluded artifact receives new tests. D2=2: existing shared-validation and real SQLite workflows are suitable. D3=2: both sources reject NUL, errors identify the description and NUL, accepted content remains intact, and physical report/index tables remain empty. D4=1: four NUL positions run through both validator and store parameterizations; extra accepted-content checks and three empty-state views make this broader and more repetitive than necessary. Direct persistence checks are useful, but do not require keeping every overlapping query assertion. D5=2: error expectations distinguish the intended validation error from SQLite's existing constraint error. The report accurately states that the old database already rejected these inputs and that crawler assertions were not reached before the fix.

**Y:** D1=2: no excluded-artifact test changes. D2=2: two added rows reuse the exact existing two-source write scenario. D3=2: NUL-only and embedded NUL reject through both write paths, with no report IDs; existing accepted-content and boundary scenarios remain. D4=2: minimal changes and independent error/persistence expectations. D5=1: `/Description/` detects the reported SQLite regression but does not require an explanation of the NUL restriction. A vague `Description invalid` error could pass. The report honestly limits what failed before the fix and what ran afterward.

**Coverage and production correctness:** Neither removes existing coverage. Y does not directly inspect physical tables or separately exercise NUL through `validateReport`; those are limitations, not proof that reports persist or a mandate for another test layer. X gives stronger error and physical-storage evidence at higher maintenance cost. The production guards are equivalent: `\0` and `\u0000` denote the same character. Both reject it after trimming and before length validation. No production defect is established.

**Materiality:** Tie. X is more specific and broader; Y is more focused but has a weaker error expectation. Neither passing-test count decides the result.

## agentHabitat

**X:** D1=2: no script or prompt tests, including temporary tests. D2=2: it correctly avoids extending the unrelated config test merely because that test reads the prompt. D3=2: no application business behavior changed; syntax validation and manual guard-order/prompt review are appropriate. D4=2: only the requested artifacts change, with no assertion harness to maintain. D5=2: `bash -n` is correctly described as parsing, not behavioral proof. Runtime side effects and agent compliance remain explicitly unverified. Restraint can receive full credit here.

**Y:** D1=0: the seven-check Python harness includes automated script behavior checks and a prompt-content assertion. Temporary evidence tests are still tests. Saying no repository test was added does not satisfy the exclusion. D2=2: it does not contort an unrelated existing config scenario; there was no suitable eligible business scenario to extend. D3=2: skipping application TypeScript tests is justified, and no unrelated business outcome is invented. D4=0: a bespoke mock environment, synthetic credentials, several invocation cases, and a prose assertion add excluded test infrastructure for a two-artifact change. D5=2: the report distinguishes mocked execution from live credential transfer and prompt wording from agent compliance. The described failures match the guard change. The harness source is not supplied here, so its internals remain unverified, not assumed correct.

**Coverage and production correctness:** Both guards precede credential-path assignment and the visible DevPod call. Both reject more than two total arguments without changing accepted branches. Exit 1 versus exit 2 is not a defect because the task specifies no exit code. Both prompt changes prohibit false success reports; X additionally requests an explicit not-run reason. No production defect or important coverage loss is established. Lack of script runtime tests in X is intentional, not missing required coverage.

**Materiality:** X materially better matches test-selection preferences. This is not evidence that Y's production patch is wrong or that X proved runtime absence of side effects.

## personalBlog

**X:** D1=0: it extends a package-metadata test and runs an inline assertion over CI text. Both are expressly excluded, even though the workflow was unchanged. D2=2: considered separately from eligibility, the existing metadata scenario fits; no new fixture or test file was needed. Reuse does not override D1. D3=2: the report correctly identifies no application behavior change. D4=0: the added phrase regex restricts valid future descriptions, while the workflow regex pins exact formatting and adjacency to `jobs:`. Both create unnecessary content checks. D5=2: reported failure on the absent description and subsequent success are consistent with the patch; the CI check is honestly static, not hosted execution. Sound evidence does not make the test selection acceptable.

**Y:** D1=2: no metadata or CI assertions, including temporary assertions. D2=2: it reviews and correctly leaves the existing metadata test alone. D3=2: no business behavior changed, so no business scenario needs new coverage. D4=2: one meaningful description insertion, JSON syntax validation, and manual workflow review are sufficient. D5=2: it does not invent fail-before evidence, application verification, or hosted CI execution. Syntax validation proves only JSON validity, as required.

**Coverage and production correctness:** Neither removes existing tests. Both descriptions fit the task. Both reports say workflow-level `contents: read` already existed without overrides, so leaving the workflow unchanged is reasonable. The workflow itself is not included in either patch; I cannot independently confirm that claim from the allowed material. No application defect is established.

**Materiality:** Y materially better matches the exclusions and avoids unnecessary maintenance. X's additional tests do not improve the requested application outcome, because there is no application behavior change.

## Smallest justified skill changes

I did not read the source skill, so these are conditional wording changes, not claims about its current text. Add only wording that is missing:

> Exclusions apply to new and extended tests, including temporary harnesses, inline assertions, snapshots, and source-content checks. Reusing an existing test does not override an exclusion. For excluded-only changes, use relevant syntax validation and manual review; do not require fail-before/pass-after execution.

> Extend only cases affected by the requirement. Do not expand every existing parameter row merely to retain the same test count. Prefer explicit expected values over calling the production transformation in the expectation.

For VU's narrower weakness, change the existing NUL-row expectation to `/Description.*NUL/`; do not add another scenario solely for error wording. For Proxy Y, use input/expected pairs in the existing HTTP loop instead of `error.trim()`. For Pi X, keep the whitespace-only update rejection but omit unrelated invalid-update extensions unless they address a separately identified risk.

These are local improvements. The evidence does not justify a larger skill rewrite or a rule that always adds more boundary cases or test layers.

No external evidence or runtime behavior was checked. Remaining risks are the stated legacy-name scope question, weaker error/expectation checks, and unverified artifact runtime behavior—not demonstrated production failures.
