---
name: ui-change-verification
description: Verify meaningful pull-request UI changes with browser screenshots as a specialist used by $change-gate.
disable-model-invocation: true
---

# UI Change Verification

Use the supplied pull-request and repository data. Inspect the diff first. If it has no meaningful, demonstrable user-visible UI change, do not test and do not comment on the PR. Reply that visual verification was skipped.

For meaningful UI changes, invoke `$browser-testing` and test only the changed UI paths. Run the application on a free port other than `4000`. Capture only screenshots that prove the changed UI looks correct.

Before browser-testing removes its artifacts, upload only the selected screenshots and embed them in exactly one PR comment with a short verification note identifying the changed path. Do not claim to have verified a state you did not inspect. Reply to the change-gate agent with the comment URL, evidence, and any limitation.
