import {
  readTelegramCheckpoint,
  writePendingTelegramCheckpoint,
} from "../../../src/telegramCheckpoint.ts";
import { getTelegramUpdates } from "../../../src/telegram.ts";

const ownerId = process.env.TELEGRAM_OWNER_ID?.trim();
if (!ownerId) throw new Error("TELEGRAM_OWNER_ID is required");

const checkpoint = await readTelegramCheckpoint();
const result = await getTelegramUpdates({ offset: checkpoint.nextOffset });
// The pending checkpoint is committed by postScript.ts only after the Pi
// session completes, so a failed run redelivers these messages.
await writePendingTelegramCheckpoint(result.nextOffset);
// First poll: acknowledge the backlog without dumping stale history into a
// fresh session.
if (checkpoint.nextOffset === null) process.exit(0);
for (const message of result.updates)
  if (message.chatId === ownerId)
    console.log(`[${message.sentAt}] ${message.from}: ${message.text}`);
