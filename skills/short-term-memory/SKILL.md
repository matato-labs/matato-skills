---
name: short-term-memory
description: Search recent Matato sessions and deploy logs for recall. Use this skill for short-term retrieval and daily brief generation, not for durable semantic storage.
---

# Short-Term Memory

You have access to all daily activity via two sources: sessions, which include all conversations and exchanges between the user and the agent, and logs, which include every system log the agent prints in the console. Your responsibility is to handle any user request that could require analyzing what has happened in the system recently.

## Sources

- `$MATATO_PI_CONFIG/agent/sessions/matato/`
- `$MATATO_PI_CONFIG/agent/deploy.log`

## Task

Analyze the sources to find anything related to the user's query. When looking at the data, try to make sure you limit the search to the last 24 hours. Don't stop after you get a first match; the analysis has to be deep to make sure you don't miss an earlier case.

Once you have all matches, make a summary for the user and reply back. Be to the point, don't overcomplicate the explanation, and add sources, like for example `This appears in the logs at xx:xx:xx` or `in the session xxxx it appears that`, to give the user more details.

## Sessions

`$MATATO_PI_CONFIG/agent/sessions/matato/` is a folder that contains all the different sessions between the user and agent, or scheduled job sessions, and they are organized by day or date time.

## Systems logs

`$MATATO_PI_CONFIG/agent/deploy.log` contains the system logs written by the worker startup path.
