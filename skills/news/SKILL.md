---
name: news
description: Research the previous day's news, decide if the digest should be sent, track sent items, and send it through Telegram.
---

# News Skill

## When to Use

- A scheduled workflow asks you to evaluate the daily news digest.
- The digest must be based on current web results, not memory.
- You must decide whether to skip or send it.

## Related skills

- telegram
- web-search

## Tool inventory

- execute_command

## Topics

- Germany/Berlin
- Technology
- International news

## Rules

- The state file is `$STORAGE_PATH/agent/newsDigest.json`.
- Read the state file before doing any research.
- If the state file does not exist, create it with:

```json
{
  "lastSentDate": "",
  "sentItems": []
}
```

- `sentItems` contains objects with `url` and `sentOn`.
- Use the local time from the runtime context.
- If `lastSentDate` is already today, stop.
- Research only the previous local day.
- Use the `web-search` skill for the research.
- Prefer fresh, direct, linkable news items.
- Keep the digest under 10 items total.
- Do not repeat URLs already present in the state file.
- Keep every summary short.
- Every digest item must include the original source URL.
- Send the digest with the `telegram` skill.
- Update the state file only after a successful Telegram send.

## Workflow

1. Read `$STORAGE_PATH/agent/newsDigest.json`.
2. Determine the current local date and time from the runtime context and the user timezone already provided in the system prompt.
3. If the digest was already sent today, stop quietly.
4. Determine the previous local day.
5. Search the three topics with focused queries for that previous day.
6. Select the best distinct items across the topics.
7. Keep at most 9 items total.
8. Build a concise Telegram message with a short overall summary and then one short note plus the original source link per item.
9. Send the message with the `telegram` skill.
10. Write the updated state file back to `$STORAGE_PATH/agent/newsDigest.json`.

## State File Format

Use this JSON shape:

```json
{
  "lastSentDate": "2026-05-15",
  "sentItems": [
    {
      "url": "https://example.com/article",
      "sentOn": "2026-05-15"
    }
  ]
}
```

## Digest Format

- Start with a short title for the previous day.
- Add a short overall summary.
- For each item include topic, headline, short summary, and the original source link.
- Use plain, directly clickable URLs.
- Keep the total under 10 items.

## If You Skip

- If it was already sent today, stop quietly.
- Do not send a Telegram message when skipping.
