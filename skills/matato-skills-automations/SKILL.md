---
name: matato-skills-automations
description: Create, read, update, and delete Matato Skills automations. Use when managing scheduled jobs, prompts, or enabled states.
---

# Matato Skills automations

Resolve paths from this skill directory, not the working directory.

1. Read the config at `$MATATO_SKILLS_AUTOMATIONS_CONFIG`, or `../../config/config.json` when unset. Do not edit the package-root `config.json` or use T3 scheduler tools.
2. List jobs or find a job by its unique `jobName`. Ask if the target is unclear.
3. Create by appending to `automations`; update only requested fields; delete only the requested job. Preserve other jobs and fields. To pause a job, set `enabled: false`.
4. Read `../../src/automation.ts` for fields and allowed values. For new jobs, get the schedule, prompt, and model from the user or an agreed existing job. Use this shape:

```json
{"jobName":"example","enabled":false,"schedule":"*/5 * * * *","userPrompt":"Do the task","dailySession":false,"canOverlap":false,"model":"MODEL","thinkingLevel":"medium","canLaunchSubAgents":false,"useSkill":false}
```

Use Croner cron syntax. Keep names unique. Set `useSkill: true` only when `jobName` names an available skill. Do not set `monitor: true`; the standalone worker does not support it. Enable new jobs only when requested.

5. Check JSON syntax, unique job names, and cron expressions before saving. Read back the saved config and report the path and change. A running worker reloads changes about every five seconds; saving does not start the worker.
