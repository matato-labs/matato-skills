import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readTelegramCheckpoint } from "../../src/telegramCheckpoint.ts";
import { sendTelegramMessage } from "../../src/telegram.ts";

export default function (pi: ExtensionAPI): void {
  pi.registerTool({
    name: "telegram_send_message",
    label: "Telegram send message",
    description:
      "Send a concise text message to Telegram. Defaults to TELEGRAM_OWNER_ID.",
    parameters: Type.Object({
      text: Type.String({ minLength: 1, description: "Message text" }),
      chatId: Type.Optional(
        Type.String({
          minLength: 1,
          description: "Telegram chat id; defaults to TELEGRAM_OWNER_ID",
        }),
      ),
    }),
    async execute(_toolCallId, params) {
      const chatId = params.chatId ?? process.env.TELEGRAM_OWNER_ID;
      if (!chatId)
        throw new Error(
          "TELEGRAM_OWNER_ID is required when chatId is not provided",
        );
      await sendTelegramMessage({ chatId, text: params.text });
      return {
        content: [{ type: "text", text: "Telegram message sent." }],
        details: { chatId },
      };
    },
  });

  pi.registerCommand("telegram", {
    description: "Show Telegram integration configuration and polling status",
    handler: async (_args, ctx) => {
      const checkpoint = await readTelegramCheckpoint();
      const token = process.env.TELEGRAM_BOT_TOKEN?.trim()
        ? "configured"
        : "missing";
      const owner = process.env.TELEGRAM_OWNER_ID?.trim()
        ? "configured"
        : "missing";
      ctx.ui.notify(
        `Telegram token: ${token}; owner: ${owner}; last poll: ${checkpoint.lastPolledAt ?? "never"}.`,
        token === "configured" && owner === "configured" ? "info" : "warning",
      );
    },
  });
}
