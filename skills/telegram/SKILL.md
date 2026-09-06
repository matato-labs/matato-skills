---
name: telegram
description: Use this skill when the agent must send a short message to the user through the Telegram Bot HTTP API.
---

# Telegram Skill

## When to Use

- User asks the agent to send them a Telegram message.
- Another skill or workflow needs to notify the user directly.
- A long-running routine needs to report a concise result to the user.

## Tool inventory

- bash

## Core Rules

- Use the Telegram HTTP API directly through `bun sendMessageTelegram.ts`.
- Do not use project source code, SDKs, or wrappers.
- Read the bot token from `TELEGRAM_BOT_TOKEN`.
- Send to `TELEGRAM_OWNER_ID` by default.
- If the user provides an explicit Telegram chat id, pass it as the second script argument.
- Never print `TELEGRAM_BOT_TOKEN`.
- Keep messages concise.
- Do not send empty messages.
- Send plain text only by default.
- Do not use Markdown syntax such as headings, bullet lists, emphasis markers, or code fences unless the user explicitly asks for formatting.
- Do not use parse mode unless the user explicitly asks for formatting.
- Treat script exit code `0` as sent and any other exit code as failed.

## Required Environment Variables

- `TELEGRAM_BOT_TOKEN`: Telegram bot token used in the API URL.
- `TELEGRAM_OWNER_ID`: default chat id for the user when no explicit chat id is provided. This is not required when passing a chat id as the second script argument.

## Send Message

Run the TypeScript script from this skill directory using `bash`.

```bash
bun sendMessageTelegram.ts "message text to send"
```

## Send Message To Explicit Chat

Use this only when the user gives a specific chat id.

```bash
bun sendMessageTelegram.ts "message text to send" "telegram chat id from the user request"
```

## Expected Successful Output

```text
Telegram message sent
```

## Output

- If the send succeeds, say the Telegram message was sent.
- If the send fails, say it failed and include the short Telegram error description when available.
