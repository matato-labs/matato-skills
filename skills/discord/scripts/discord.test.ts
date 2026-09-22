import { afterEach, describe, expect, test } from "bun:test";
import {
  getBotIdentity,
  listAllowedChannels,
  readMessages,
  replyToMessage,
  sendMessage,
} from "./discord.ts";

const originalFetch = globalThis.fetch;
const originalToken = process.env.DISCORD_BOT_TOKEN;
const originalGuildId = process.env.DISCORD_GUILD_ID;
const originalChannelIds = process.env.DISCORD_CHANNEL_IDS;

type RequestRecord = {
  url: string;
  options: RequestInit;
};

type FetchHandler = (url: string, options: RequestInit) => Promise<Response>;

const setFetch = (handler: FetchHandler): void => {
  globalThis.fetch = Object.assign(
    async (input: RequestInfo | URL, options: RequestInit = {}) =>
      handler(String(input), options),
    { preconnect: (): void => {} },
  );
};

const configureDiscord = (): void => {
  process.env.DISCORD_BOT_TOKEN = "test-token";
  process.env.DISCORD_GUILD_ID = "guild-1";
  process.env.DISCORD_CHANNEL_IDS = "channel-1, channel-2";
};

const restoreEnvironmentValue = (
  name: string,
  value: string | undefined,
): void => {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
};

afterEach(() => {
  globalThis.fetch = originalFetch;
  restoreEnvironmentValue("DISCORD_BOT_TOKEN", originalToken);
  restoreEnvironmentValue("DISCORD_GUILD_ID", originalGuildId);
  restoreEnvironmentValue("DISCORD_CHANNEL_IDS", originalChannelIds);
});

describe("Discord REST helpers", () => {
  test("identifies the configured bot through Discord's official API", async () => {
    configureDiscord();
    const requests: Array<RequestRecord> = [];
    setFetch(async (url, options) => {
      requests.push({ url, options });
      return new Response(
        JSON.stringify({
          id: "bot-1",
          username: "matato",
          global_name: "Matato",
          bot: true,
        }),
      );
    });

    await expect(getBotIdentity()).resolves.toMatchObject({
      id: "bot-1",
      username: "matato",
    });
    expect(requests).toEqual([
      {
        url: "https://discord.com/api/v10/users/@me",
        options: { headers: { Authorization: "Bot test-token" } },
      },
    ]);
  });

  test("lists only allowlisted channels in the configured guild", async () => {
    configureDiscord();
    setFetch(
      async () =>
        new Response(
          JSON.stringify([
            { id: "channel-1", type: 0, name: "private" },
            { id: "channel-3", type: 0, name: "not-allowed" },
          ]),
        ),
    );

    await expect(listAllowedChannels()).resolves.toEqual([
      { id: "channel-1", type: 0, name: "private" },
    ]);
  });

  test("reads a bounded number of messages only after checking the allowlisted guild channel", async () => {
    configureDiscord();
    const requests: Array<RequestRecord> = [];
    setFetch(async (url, options) => {
      requests.push({ url, options });
      if (url.endsWith("/channels/channel-1"))
        return new Response(
          JSON.stringify({ id: "channel-1", guild_id: "guild-1", type: 0 }),
        );

      return new Response(JSON.stringify([]));
    });

    await expect(readMessages("channel-1", 999)).resolves.toEqual([]);
    expect(requests.map((request) => request.url)).toEqual([
      "https://discord.com/api/v10/channels/channel-1",
      "https://discord.com/api/v10/channels/channel-1/messages?limit=100",
    ]);
    await expect(readMessages("channel-3")).rejects.toThrow(
      "Channel channel-3 is not allowlisted",
    );
  });

  test("rejects reads and writes outside the selected guild before accessing messages", async () => {
    configureDiscord();
    let requestCount = 0;
    setFetch(async () => {
      requestCount += 1;
      return new Response(
        JSON.stringify({ id: "channel-1", guild_id: "other-guild", type: 0 }),
      );
    });

    await expect(readMessages("channel-1")).rejects.toThrow(
      "Channel channel-1 is not in the configured guild",
    );
    await expect(
      sendMessage({ channelId: "channel-1", content: "Hello" }),
    ).rejects.toThrow("Channel channel-1 is not in the configured guild");
    expect(requestCount).toBe(2);
  });

  test("sends a message and reply only through the verified allowlisted channel", async () => {
    configureDiscord();
    const requests: Array<RequestRecord> = [];
    setFetch(async (url, options) => {
      requests.push({ url, options });
      if (url.endsWith("/channels/channel-1"))
        return new Response(
          JSON.stringify({ id: "channel-1", guild_id: "guild-1", type: 0 }),
        );

      return new Response(
        JSON.stringify({
          id: "message-2",
          channel_id: "channel-1",
          content: "Hello",
          author: {
            id: "bot-1",
            username: "matato",
            global_name: null,
            bot: true,
          },
          timestamp: "2026-01-01T00:00:00.000Z",
        }),
      );
    });

    await sendMessage({ channelId: "channel-1", content: "Hello" });
    await replyToMessage({
      channelId: "channel-1",
      messageId: "message-1",
      content: "Hello",
    });
    expect(requests.map((request) => request.url)).toEqual([
      "https://discord.com/api/v10/channels/channel-1",
      "https://discord.com/api/v10/channels/channel-1/messages",
      "https://discord.com/api/v10/channels/channel-1",
      "https://discord.com/api/v10/channels/channel-1/messages",
    ]);
    expect(JSON.parse(String(requests[3]?.options.body))).toEqual({
      content: "Hello",
      message_reference: { message_id: "message-1", fail_if_not_exists: true },
    });
  });

  test("requires configuration without revealing its token", async () => {
    delete process.env.DISCORD_BOT_TOKEN;
    process.env.DISCORD_GUILD_ID = "guild-1";
    process.env.DISCORD_CHANNEL_IDS = "channel-1";

    await expect(getBotIdentity()).rejects.toThrow(
      "DISCORD_BOT_TOKEN is required",
    );
  });
});
