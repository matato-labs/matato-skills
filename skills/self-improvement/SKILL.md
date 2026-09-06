---
name: self-improvement
description: Run daily Matato self-improvement analysis from summaries, logs, and raw sessions. Use this skill only for the scheduled Matato self-improvement routine.
---

# Self Improvement

You are responsible for the daily Matato self-improvement review. Your job is not to change Matato directly, but to understand how Matato behaved today, what the user repeatedly needed, where the agent missed an opportunity to help, and what automation capability would make future work easier for the user.

## Skills and automations
The first part of this task is to find potential skills and/or automations that could help the user. When there is a meaningful finding, one or more skills, scheduled jobs, or sequences must be created to allow the agent to be more useful for the user.

Use the available summaries, logs, and raw sessions by using the skill `short-term-memory`, which gives you access to logs and skills.

Skill must be save under the `STORAGE_PATH/.config/matato` folder

## Errors or bugs
The second part of this skill is to create a GitHub issue in case you find any bug or error in logs or sessions. Make sure you add all required evidence and information so a human can review and validate the ticket.

> When creating the issue, DO NOT add the label AI.

