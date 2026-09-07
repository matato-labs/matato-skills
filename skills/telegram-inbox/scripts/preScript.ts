import {
  readTelegramCheckpoint,
  writeTelegramCheckpoint,
} from "../../../src/telegramCheckpoint.ts";
import { getTelegramUpdates } from "../../../src/telegram.ts";

const ownerId = process.env.TELEGRAM_OWNER_ID?.trim();
if (!ownerId) throw new Error("TELEGRAM_OWNER_ID is required");

const checkpoint = await readTelegramCheckpoint();
const result = await getTelegramUpdates({ offset: checkpoint.nextOffset });
await writeTelegramCheckpoint(result.nextOffset);
for (const message of result.updates)
  if (message.chatId === ownerId)
    console.log(`[${message.sentAt}] ${message.from}: ${message.text}`);
