---
name: break-me
description: Use $break-me everytime you need to test extensebly a code base for cases that are not cover
disable-model-invocation: true
---

# Break me

The user may ask you to test a change or existing feature, the code maybe running in an environment or locally, either case you need to find the way to run the application locally or access the environment.

You resposablitiy is to break the feature or change the user is asking, find different test verification strategies and start using the application to break the targe. The application maybe include HTTP endpoints, UI, messages, object storage etc, find what you have to test and find things to break.

It's important that the cases are realistic, and not completly crazy scenarios that will never happen.

Run the testing via sub-agents to save in context. All the sub-agents must return to you what they found

## Fixing the findings

Once the verification is done and all sub-agents gave you the findings, is your turn to fix the, lauch other sub-agents to address every issue found.

## Output

Don't commit, push, create a branch or PR unless the user tells you to do so.
