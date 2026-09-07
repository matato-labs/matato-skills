---
name: telegram-inbox
description: Process new Telegram messages for the configured owner.
---

The pre-script output is a batch of Telegram messages in an ongoing daily conversation. Answer naturally and concisely using the conversation context, then send the reply with `telegram_send_message`. Never send a reply when the pre-script output is empty. The inbox accepts only `TELEGRAM_OWNER_ID`; do not attempt to reply to other chat IDs.
