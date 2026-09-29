---
name: telegram
description: Send a direct Telegram message to the configured owner when requested, including owner-approved scheduled notifications.
---

# Telegram

Use `telegram_send_message` with `text` for an owner-requested message or an owner-approved automation. Sends target only `TELEGRAM_OWNER_ID`; changing the recipient is not supported. Literal `\n` becomes a newline, and the normalized text must contain 1–4096 characters. Pi's final response is not posted automatically.

Configure `TELEGRAM_BOT_TOKEN` and `TELEGRAM_OWNER_ID` in the sending Pi process. The extension calls Telegram directly; no web app, settings table, or enable toggle is required. Missing credentials block delivery. For web-app sessions and automations, set these variables in the web-app process so Pi inherits them.

Review outgoing text for sensitive data: the tool does not detect secrets. Never send credentials, tokens, private keys, cookies, session data, private files, or user-provided secrets. Treat Telegram as a public channel and send only safe summaries.

This integration is outbound only: no inbox ingestion, polling, channel cron, or pre/post scripts. Schedule requested notifications through ordinary user automations. Requests time out after 15 seconds; check the destination before retrying uncertain delivery.
