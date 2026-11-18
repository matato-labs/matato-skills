---
name: break-me
description: Use $break-me everytime you need to test extensebly a code base for cases that are not cover
disable-model-invocation: true
---

# Break me

Your task is be a QA for the change the user is providing to you, you need to do a formal verification of the change by trying to find any scenario that could break the current status cuo of the system on regards to the new change.

Different applications have different testing strategies, some can run locally and have UI/API others only UI or only API, some are CLIs or asynchronous services, regardles the system find the way to it that makes sense for it's sestup.

Sometimes you don't need to test a change but a real system running in a environemnt, you will need to use the tools or skills the user ask you to generate sysntetic data to test the real system.

### How

Launch as many sug-agents asyou need to find all testing paths and start testing in isolation different variations of the input to the system to find uncover edge cases that could cause real issues once the system runs in production.

You must cover all cases possible with your subagents to be 100% the system will not break once exposed to real users.

It's important that the cases are realistic, and not completly crazy scenarios that will never happen.

## Fixing the findings

Once the verification is done and all sub-agents gave you the findings, is your turn to fix the, lauch other sub-agents to address every issue found.

## Output

Don't commit, push, create a branch or PR unless the user tells you to do so.
