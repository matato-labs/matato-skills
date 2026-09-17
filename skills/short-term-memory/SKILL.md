---
name: short-term-memory
description: Use this skill when you need to analyse previous sessions or web app logs.
---

# Short-Term Memory

You have access to all daily activity via two sources: sessions, which include all conversations and exchanges between the user and the agent, and logs, which include every system log the agent prints in the console. Your responsibility is to handle any user request that could require analyzing what has happened in the system recently.

## Sources

**Sessions**: `~/.pi/agent/sessions/matato/`

**Logs**: `~/.config/matato-pi/logs/web-app.log` — the web app writes every log event to this rotating file (10 MB, 5 files kept). Use `grep '\[error\]'` to find error-level entries, e.g. `grep '\[error\]' ~/.config/matato-pi/logs/web-app.log`.

## Task

Analyze the sources to find anything related to the user's query. When looking at the data, try to make sure you limit the search to the last 24 hours. Don't stop after you get a first match; the analysis has to be deep to make sure you don't miss an earlier case.

Once you have all matches, make a summary for the user and reply. Be concise, don't overcomplicate the explanation, and add sources, for example, `This appears in the logs at xx:xx:xx` or `in the session xxxx it appears that`, to give the user more details.

