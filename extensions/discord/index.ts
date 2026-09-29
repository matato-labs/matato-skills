import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { sendDiscordMessage } from "../../src/discord.ts";

export default function (pi: ExtensionAPI): void {
  pi.registerTool({
    name: "discord_send_message",
    label: "Discord send message",
    description:
      "Send safe public text to an allowlisted Discord guild channel on the owner's request or through an owner-approved automation. Uses DISCORD_BOT_TOKEN, DISCORD_GUILD_ID, and DISCORD_CHANNEL_IDS directly; no web app required. Optional replyTo references a message ID supplied by the owner. Never send private data.",
    parameters: Type.Object({
      channelId: Type.String({
        description: "Allowlisted destination channel ID",
      }),
      text: Type.String({
        minLength: 1,
        description: "Safe public message text",
      }),
      replyTo: Type.Optional(
        Type.String({
          description: "Owner-supplied message ID to reply to",
        }),
      ),
    }),
    async execute(_toolCallId, params) {
      await sendDiscordMessage(params);
      return {
        content: [{ type: "text", text: "Discord message sent." }],
        details: undefined,
      };
    },
  });
}
