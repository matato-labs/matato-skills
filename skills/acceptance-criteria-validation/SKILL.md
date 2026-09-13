---
name: acceptance-criteria-validation
description: Verify acceptance criteria for a change as an explicit specialist used by $change-validation.
disable-model-invocation: true
---

# Acceptance Criteria Validation

The user will provide you with the acceptance criteria or a source for them.

If nothing is provided, interview the user to extract them, asking each question one by one. Once you have all requirements, create a list of acceptance criteria that the change needs to meet, and ask the user to validate and approve it before moving forward.

Once you have the acceptance criteria, either from a source or from interviewing the user, validate the code to make sure they are fulfilled in the change. If the current implementation doesn't meet the ACs, you can change the code to fulfil expectations.

When you are done, reply to the orchestrator agent with a small summary and the state of your work.
