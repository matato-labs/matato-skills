---
name: telegram-inbox
description: Process new Telegram messages for the configured owner.
---

The pre-script output is a batch of Telegram messages in an ongoing daily conversation. Answer naturally and concisely using the conversation context, then send the reply with `telegram_send_message`. Never send a reply when the pre-script output is empty. The inbox accepts only `TELEGRAM_OWNER_ID`; do not attempt to reply to other chat IDs.

Delivery is at-least-once: the pre-script records a pending checkpoint that `postScript.ts` commits only after the session completes successfully, so a failed run may redeliver messages. The first poll acknowledges the existing backlog without emitting it, so stale history is never answered.
