---
name: acceptance-criteria-validation
description: Verify acceptance criteria for a change when $change-validation explicitly uses this specialist.
disable-model-invocation: true
---

# Acceptance Criteria Validation

The user will provide the acceptance criteria or a source for them,.

If the user provides neither, ask questions to identify the acceptance criteria. Ask one question at a time. After you have all requirements, list the acceptance criteria that the change must meet.

Validate the code against the acceptance criteria. If the current implementation does not meet them, change the code to meet them, use `$deep-dive`, and `$why` to complement your investigation.

When you finish, send the orchestrator agent a short summary and the status of your work.
