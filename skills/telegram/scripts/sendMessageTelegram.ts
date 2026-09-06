#!/usr/bin/env bun
import { normalizeTelegramText } from "./telegramText.ts";

export {};

type TelegramSendMessageResponse = {
  ok: boolean;
};

const message = normalizeTelegramText(process.argv[2] ?? "");
const chatId = process.argv[3] ?? Bun.env.TELEGRAM_OWNER_ID ?? "";
const telegramBotToken = Bun.env.TELEGRAM_BOT_TOKEN;

if (!telegramBotToken) {
  console.error("TELEGRAM_BOT_TOKEN is missing");
  process.exit(1);
}

if (!chatId) {
  console.error(
    "Telegram chat id is missing. Set TELEGRAM_OWNER_ID or pass a chat id as the second argument.",
  );
  process.exit(1);
}

if (!message) {
  console.error("Telegram message is empty");
  process.exit(1);
}

const response = await fetch(
  `https://api.telegram.org/bot${telegramBotToken}/sendMessage`,
  {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ chat_id: chatId, text: message }),
  },
);

const responseBody = await response.text();

if (!response.ok) {
  console.error(
    `Telegram sendMessage failed with HTTP status ${response.status}`,
  );
  console.error(responseBody);
  process.exit(1);
}

const parsedResponse = JSON.parse(responseBody) as TelegramSendMessageResponse;

if (!parsedResponse.ok) {
  console.error("Telegram sendMessage failed");
  console.error(responseBody);
  process.exit(1);
}

console.log("Telegram message sent");
