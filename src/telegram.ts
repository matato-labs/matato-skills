export type TelegramMessage = {
  chatId: string;
  text: string;
  sentAt: string;
  from: string;
};

type TelegramUpdate = {
  update_id: number;
  message?: {
    date: number;
    text?: string;
    chat?: { id: number | string };
    from?: {
      id: number | string;
      first_name?: string;
      username?: string;
      is_bot?: boolean;
    };
  };
};

const apiUrl = "https://api.telegram.org";

const botToken = (): string => {
  const token = process.env.TELEGRAM_BOT_TOKEN?.trim();
  if (!token) throw new Error("TELEGRAM_BOT_TOKEN is required");
  return token;
};

const failOnHttpError = async (
  response: Response,
  action: string,
): Promise<void> => {
  if (response.ok) return;
  throw new Error(
    `Telegram ${action} request failed with status ${response.status} and message ${await response.text()}`,
  );
};

export const normalizeTelegramText = (text: string): string =>
  text.replaceAll("\\n", "\n");

const toMessage = (update: TelegramUpdate): TelegramMessage | null => {
  const message = update.message;
  if (!message?.chat || !message.from || message.from.is_bot) return null;
  const text = message.text ?? "";
  if (!text) return null;
  return {
    chatId: String(message.chat.id),
    text,
    sentAt: new Date(message.date * 1000).toISOString(),
    from:
      message.from.username ??
      message.from.first_name ??
      String(message.from.id),
  };
};

export async function sendTelegramMessage(input: {
  chatId: string;
  text: string;
}): Promise<void> {
  const text = normalizeTelegramText(input.text);
  if (!input.chatId) throw new Error("Telegram chatId is required");
  if (!text) throw new Error("Telegram message text is required");
  const response = await fetch(`${apiUrl}/bot${botToken()}/sendMessage`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ chat_id: input.chatId, text }),
  });
  await failOnHttpError(response, "sendMessage");
  const payload = (await response.json()) as {
    ok?: boolean;
    description?: string;
  };
  if (!payload.ok)
    throw new Error(
      `Telegram sendMessage failed: ${payload.description ?? "Unknown Telegram API error"}`,
    );
}

export async function getTelegramUpdates(input: {
  offset: number | null;
}): Promise<{
  updates: Array<TelegramMessage>;
  nextOffset: number;
}> {
  const query = new URLSearchParams({
    timeout: "0",
    limit: "100",
    allowed_updates: JSON.stringify(["message"]),
  });
  if (input.offset !== null) query.set("offset", String(input.offset));
  const response = await fetch(
    `${apiUrl}/bot${botToken()}/getUpdates?${query}`,
  );
  await failOnHttpError(response, "getUpdates");
  const payload = (await response.json()) as {
    ok?: boolean;
    result?: Array<TelegramUpdate>;
    description?: string;
  };
  if (!payload.ok || !Array.isArray(payload.result))
    throw new Error(
      `Telegram getUpdates failed: ${payload.description ?? "Unknown Telegram API error"}`,
    );
  const lastUpdateId = payload.result.at(-1)?.update_id;
  return {
    updates: payload.result
      .map(toMessage)
      .filter((message): message is TelegramMessage => message !== null),
    nextOffset:
      lastUpdateId === undefined ? (input.offset ?? 0) : lastUpdateId + 1,
  };
}
