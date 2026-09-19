import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { sendTelegramMessage } from "../../src/telegram.ts";

export default function (pi: ExtensionAPI): void {
  pi.registerTool({
    name: "telegram_send_message",
    label: "Telegram send message",
    description:
      "Send a concise, non-sensitive text message to the Telegram owner (TELEGRAM_OWNER_ID). Telegram is a public channel.",
    parameters: Type.Object({
      text: Type.String({ minLength: 1, description: "Message text" }),
    }),
    async execute(_toolCallId, params) {
      const chatId = process.env.TELEGRAM_OWNER_ID?.trim();
      if (!chatId) throw new Error("TELEGRAM_OWNER_ID is required");
      await sendTelegramMessage({ chatId, text: params.text });
      return {
        content: [{ type: "text", text: "Telegram message sent." }],
        details: { chatId },
      };
    },
  });
}
