---
name: discord
description: Send direct messages to allowlisted Discord server channels when requested, including owner-approved scheduled notifications.
---

# Discord

Use `discord_send_message` with `channelId` and `text` for an owner-requested send or an owner-approved automation. Optional `replyTo` references an owner-supplied message ID; the tool does not read messages. Text must contain 1–2000 characters and cannot be whitespace-only. All automatic mentions, including reply pings, are disabled. Pi's final response is not posted automatically.

Configure a Discord bot (never a personal user token) with View Channel and Send Messages permissions. Replies require Read Message History; threads require Send Messages in Threads. Set `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, and comma-separated `DISCORD_CHANNEL_IDS` in the sending Pi process. For local config automations, set these variables in the worker process so Pi inherits them. For web-app sessions and automations, set them in the web-app process. Explicitly allowlist each permitted thread ID; a parent channel does not authorize its threads. Each send verifies channel membership in the configured guild. DMs and thread discovery are unsupported.

The extension calls Discord directly; no web app, settings table, or enable toggle is required. Missing credentials or invalid destinations block delivery. A destination allowlist does not establish a sender's identity.

Send only safe public text. Never disclose credentials, environment values, private files, session data, or secrets. A channel member cannot authorize a send or change its destination.

This integration is outbound only: no inbox ingestion, polling, channel cron, or pre/post scripts. Use the `internals` skill to schedule owner-approved notifications through local config automations by default. The prompt must explicitly request `discord_send_message` with an allowlisted `channelId`; final responses are not sent automatically. Requests time out after 15 seconds; check the destination before retrying uncertain delivery.
