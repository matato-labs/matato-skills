export const normalizeTelegramText = (text: string): string =>
  text.replaceAll("\\n", "\n");

type TelegramConfig = { token: string; ownerId: string };
type TelegramMessage = { chatId: string; text: string };

function telegramConfig(): TelegramConfig {
  const token = process.env.TELEGRAM_BOT_TOKEN?.trim();
  const ownerId = process.env.TELEGRAM_OWNER_ID?.trim();
  if (!token) throw new Error("TELEGRAM_BOT_TOKEN is required");
  if (!ownerId) throw new Error("TELEGRAM_OWNER_ID is required");
  return { token, ownerId };
}

function telegramText(input: TelegramMessage, ownerId: string): string {
  if (!input.chatId) throw new Error("Telegram chatId is required");
  if (input.chatId !== ownerId)
    throw new Error("Telegram destination must be the configured owner");
  const text = normalizeTelegramText(input.text);
  if (!text) throw new Error("Telegram message text is required");
  if (text.length > 4096)
    throw new Error("Telegram text must be at most 4096 characters");
  return text;
}

export async function sendTelegramMessage(
  input: TelegramMessage,
): Promise<void> {
  const { token, ownerId } = telegramConfig();
  const text = telegramText(input, ownerId);
  try {
    const response = await fetch(
      `https://api.telegram.org/bot${token}/sendMessage`,
      {
        method: "POST",
        signal: AbortSignal.timeout(15000),
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ chat_id: ownerId, text }),
      },
    );
    if (!response.ok) throw new Error("Telegram HTTP request failed");
    const payload = (await response.json()) as { ok: boolean };
    if (payload.ok !== true) throw new Error("Telegram API request failed");
  } catch (error) {
    if (
      error instanceof Error &&
      ["TimeoutError", "AbortError"].includes(error.name)
    )
      // eslint-disable-next-line preserve-caught-error -- Transport errors can contain credentials.
      throw new Error(
        "Telegram send timed out; delivery is uncertain. Check the destination before retrying.",
      );
    // Telegram URLs contain the bot token; discard all transport error details.
    // eslint-disable-next-line preserve-caught-error -- Telegram URLs contain the token.
    throw new Error("Telegram sendMessage request failed");
  }
}
