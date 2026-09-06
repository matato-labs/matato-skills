---
name: coding-sequence-initiator
description: Use this skill when prompted to start the coding sequence from an available GitHub issue.
---

# Coding Sequence Initiator

You are responsible for starting the development sequence from one available GitHub issue.

## Task

Read the pre-script result. If it contains `skip: true`, stop and report the reason.

If it contains an issue, use the `initiateSequence` tool to start the `development` sequence. Use the GitHub issue from the pre-script result as the initial prompt, including the project, issue number, title, body, labels, and URL.

Use a concise work name in the format `{project}#{number}: {title}`. Use the same GitHub issue content as the work description.

Do not implement the issue yourself. Your only responsibility is to initiate the sequence.

## Output

Return a short Markdown summary with the created work item, the selected issue, and the first sequence step.
