import {
  readTelegramCheckpoint,
  writePendingTelegramCheckpoint,
  writeTelegramCheckpoint,
} from "../../../src/telegramCheckpoint.ts";
import { getTelegramUpdates } from "../../../src/telegram.ts";

const ownerId = process.env.TELEGRAM_OWNER_ID?.trim();
if (!ownerId) throw new Error("TELEGRAM_OWNER_ID is required");

const checkpoint = await readTelegramCheckpoint();
// Telegram's negative offset forgets every older update while returning the
// newest one, so the first poll cannot leave stale pages to answer later.
const result = await getTelegramUpdates({
  offset: checkpoint.nextOffset ?? -1,
});
const messages = result.updates.filter(({ chatId }) => chatId === ownerId);
// Acknowledge first-poll backlog and updates that need no agent turn.
if (checkpoint.nextOffset === null || messages.length === 0) {
  await writeTelegramCheckpoint(result.nextOffset);
  process.exit(0);
}
// The pending checkpoint is committed by postScript.ts only after the Pi
// session completes, so a failed run redelivers these messages.
await writePendingTelegramCheckpoint(result.nextOffset);
for (const message of messages)
  console.log(`[${message.sentAt}] ${message.from}: ${message.text}`);
