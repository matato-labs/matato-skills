---
name: verify-me
description: Use $verify-me everytime you need to test a feature or change.
---

# Verify me

Your task is be a QA for the change the user is providing to you, you need to do a formal verification of the change by trying test the happy path and to provide evidence of no regresion.

Different applications have different testing strategies, some can run locally and have UI/API others only UI or only API, some are CLIs or asynchronous services, regardles the system find the way to it that makes sense for it's sestup.

Sometimes you don't need to test a change but a real system running in a environemnt, you will need to use the tools or skills the user ask you to generate sysntetic data to test the real system.

Only test what is required to prove the feature or change works, anything outside of that is not expected.

Run the testing via sub-agents to save in context. All the sub-agents must return to you what they found

## Fixing the findings

Once the verification is done and all sub-agents gave you the findings, is your turn to fix the, lauch other sub-agents to address every issue found.

## Output

Once everything is done proivde all evidence to the user.
