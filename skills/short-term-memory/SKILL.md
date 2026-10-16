---
name: short-term-memory
description: Use this skill when you need to analyze previous sessions or web app logs.
---

# Short-Term Memory

Use two sources to access all daily activity. Sessions include all conversations and exchanges between the user and the agent. Logs include every system log the agent prints in the console. Handle any user request that could require analysis of recent system activity.

## Sources

**Sessions**: `~/.pi/agent/sessions/matato/`

**Logs**: `~/.config/matato-pi/logs/web-app.log`. The web app writes every log event to this rotating file. The rotation limit is 10 MB, and the app keeps 5 files. Use `grep '\[error\]'` to find error-level entries. For example, use `grep '\[error\]' ~/.config/matato-pi/logs/web-app.log`.

## Task

Analyze the sources to find anything related to the user's query. Try to limit the search to the last 24 hours. Do not stop after the first match. Analyze the sources thoroughly so that you do not miss an earlier case.

After you find all matches, summarize them in your reply to the user. Keep the explanation concise and simple. Include sources to give the user more details. For example, use `This appears in the logs at xx:xx:xx` or `in the session xxxx it appears that`.

