# Independent masked comparison

## Scope and scoring

Read only `maskedComparison.md`. No source skills, repositories, other evidence, or earlier reviews were read. No commands or tests were rerun. Reports are agent evidence, not independently verified execution logs. Patch excerpts support the code comparison; unchanged tests and helper implementations are not fully visible.

Each dimension uses 0–2: 0 = absent or violated; 1 = partial evidence or a meaningful gap; 2 = strong observed support, including justified absence of tests. Totals do not measure test count or prove statistical equivalence.

| Task | Output | Excluded-artifact discipline | Existing-scenario reuse without contortion | Business outcomes or justified absence | Focused maintenance and independent expectations | Honest evidence and regression sensitivity | Total /10 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| matatoPi | X | 2 | 2 | 2 | 2 | 2 | 10 |
| matatoPi | Y | 2 | 2 | 2 | 2 | 1 | 9 |
| matatoProxy | X | 2 | 2 | 2 | 2 | 2 | 10 |
| matatoProxy | Y | 2 | 2 | 2 | 2 | 2 | 10 |
| vu | X | 2 | 2 | 2 | 2 | 2 | 10 |
| vu | Y | 2 | 2 | 1 | 2 | 2 | 9 |
| agentHabitat | X | 2 | 2 | 2 | 2 | 2 | 10 |
| agentHabitat | Y | 2 | 2 | 2 | 2 | 2 | 10 |
| personalBlog | X | 2 | 2 | 2 | 2 | 2 | 10 |
| personalBlog | Y | 2 | 2 | 2 | 2 | 2 | 10 |

## matatoPi

Both patches make the same shared production change. Both extend existing SQLite business scenarios, preserve prompt whitespace, assert duplicate/blank error causes, and retain job/session rollback assertions. Existing blank-create coverage is reused. Unchanged API tests check callers without adding duplicate normalization assertions at another layer.

X adds explicit create and update read-back checks and uses `Daily review`, which also protects an internal name space. Y explicitly reads back the update, but not the create, and uses a single-word name. Its rejected duplicate update also changes `enabled`, slightly broadening atomicity coverage. X pins exact error text; Y checks the field and cause with less message coupling. Both expectations remain independent of production trimming.

X reports the full repository check, including architecture checks. Y reports typechecking and targeted lint/format checks, but explicitly omits the full repository check and architecture tests. This verification gap accounts for Y's evidence score; it is not a false pass claim. Both disclose that fail-before execution stopped before update assertions. Neither runs the full application suite. The supplied evidence does not establish every repository-mandated check, so omitted checks must not be called passed.

**Material quality loss:** none demonstrated in either direction. X has stronger create/internal-space evidence and broader static verification; Y retains the core business protections. Global uniqueness and legacy padded records remain unchanged in both. No production difference or unsafe change is shown.

## matatoProxy

Both use the same shared persistence change after existing raw validation. Both prove stored text, retry counts, terminal state, and rejection without partial writes. HTTP and internal tests address an explicit bypass risk, not gratuitous duplicate-layer coverage. Existing fixtures and literal expectations are reused.

X retains the unpadded 2001-character rejection and adds a padded-over-limit input. Y replaces the former with the latter. Y therefore loses that exact fixture, but retains the required raw-limit outcome with a more discriminating input: raw 2001, trimmed 1999 detects validation after trimming. This is not an important coverage loss on the shown artifacts. X snapshots all deliveries for internal rejection; Y snapshots the affected delivery. X's scope is stronger, but Y still proves the relevant record is unchanged.

Both report fail-before stored-text failures, full-suite success, type checks, and `matis` checks. First-retry failures do not independently establish fail-before sensitivity for later terminal assertions; neither needs that claim. Worker/live deployment checks remain unrun and disclosed.

**Material quality loss:** none observed in either direction. Different parameter counts do not determine quality. Required outcomes and production behavior are preserved.

## vu

Both add the same NUL rejection in shared validation and extend the existing two-source rejection scenario. Both assert description/NUL cause rather than accepting an opaque database CHECK error. They retain existing invalid inputs and reuse accepted-description, length, and coordinate coverage without adding duplicate helper/UI tests.

X replaces report discovery with `SELECT * FROM locations` and requires an empty table. Y retains `reportIds(store)`. X therefore directly proves no persisted report after both calls; Y proves only the existing helper returns no report IDs. The helper implementation is not shown. X's report describes the old check as spatial-index based, so Y's check cannot safely be treated as equivalent proof of table emptiness. A stored row omitted by report discovery could escape Y's assertion. This is a gap in an explicit task outcome, not evidence that Y actually persists invalid data.

Both honestly report that the fail-before app assertion stopped the crawler assertion. Both report backend/full-suite checks, build, and repository-required checks. Unchanged Python tests ran under repository requirements; neither adds tests for excluded scripts. X discloses an installation vulnerability warning; Y used `--no-audit`, which is not evidence that the vulnerability was absent.

**Material quality loss:** Y loses material persistence-proof strength relative to X. No reverse loss or production correctness difference is shown. Both implement the clear rejection; only X supplies direct empty-table evidence.

## agentHabitat

Both restrict the patch to the script guard and prompt clarification. Both reject more than two total arguments before credential-path assignment and the DevPod call, print usage to stderr, and exit 2. The Bash condition forms and usage-placeholder capitalization do not change the required behavior. Both prompt edits explicitly prohibit reporting an unrun completion check as passed.

No tests, temporary harnesses, inline assertions, or prose-content assertions were added. Parse-only `bash -n`, whitespace checks, and manual control-flow review fit the exclusions. No credential transfer or bootstrap is reported. Both separate syntax success from unverified runtime rejection and agent compliance. ShellCheck was unavailable, not passed.

**Material quality loss:** none observed in either direction. Absence of behavioral tests is justified, not missing business-test work under these exclusions. Runtime behavior remains unverified in both.

## personalBlog

Both add a meaningful blog description and leave already-correct workflow-level `contents: read` unchanged. No application behavior, dependency, or lockfile changes are shown. Neither adds metadata/CI tests or runs the unrelated metadata test.

X uses JSON syntax validation and manual workflow review. Y uses npm manifest parsing and an existing YAML parser, explicitly distinguishing YAML syntax from GitHub Actions semantics. These are allowed existing-tool checks, not custom assertion harnesses. Y's product-specific wording and extra parser evidence do not establish a material quality advantage. Both disclose that build, application tests, and hosted CI were not run; none is shown to be required for this metadata-only patch.

**Material quality loss:** none observed in either direction. The requested outcomes are supported, with hosted token permissions reviewed rather than exercised.

## Conclusion and limits

The material difference is VU's direct no-persistence proof: X is stronger than Y. matatoPi also shows a smaller verification and assertion-strength gap favoring X. The other pairs preserve the observed required outcomes without material loss. No shown production patch introduces unsafe behavior.

These findings concern this single masked sample. They do not establish statistical equivalence, instruction quality, or independently confirmed test results. No projects or other evidence were edited; only this review was written.
