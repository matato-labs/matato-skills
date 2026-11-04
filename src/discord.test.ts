import { afterEach, beforeEach, expect, spyOn, test } from "bun:test";
import { discordConfig, sendDiscordMessage } from "./discord.ts";

const envKeys = [
  "DISCORD_BOT_TOKEN",
  "DISCORD_GUILD_ID",
  "DISCORD_CHANNEL_IDS",
  "MATATO_SKILLS_WEB_URL",
];
const originalEnv = envKeys.map((key) => [key, process.env[key]] as const);
let fetchSpy = spyOn(globalThis, "fetch");
const channel = { id: "123", guild_id: "555" };
const send = () => sendDiscordMessage({ channelId: "123", text: "hello" });

beforeEach(() => {
  process.env.DISCORD_BOT_TOKEN = "private-token";
  process.env.DISCORD_GUILD_ID = "555";
  process.env.DISCORD_CHANNEL_IDS = "123,456";
  process.env.MATATO_SKILLS_WEB_URL = "http://127.0.0.1:1";
  fetchSpy = spyOn(globalThis, "fetch");
});
afterEach(() => {
  fetchSpy.mockRestore();
  for (const [key, value] of originalEnv) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
});

test("requires explicit bot and guild/channel configuration", async () => {
  expect(discordConfig().channelIds).toEqual(["123", "456"]);
  delete process.env.DISCORD_BOT_TOKEN;
  await expect(send()).rejects.toThrow("DISCORD_BOT_TOKEN is required");
  process.env.DISCORD_BOT_TOKEN = "private-token";
  delete process.env.DISCORD_GUILD_ID;
  await expect(send()).rejects.toThrow("DISCORD_GUILD_ID");
  process.env.DISCORD_GUILD_ID = "555";
  process.env.DISCORD_CHANNEL_IDS = "123,https://evil/";
  await expect(send()).rejects.toThrow("DISCORD_CHANNEL_IDS");
  delete process.env.DISCORD_CHANNEL_IDS;
  await expect(send()).rejects.toThrow("DISCORD_CHANNEL_IDS");
  expect(fetchSpy).not.toHaveBeenCalled();
});

test("checks exact allowlisted destination and server before sending", async () => {
  await expect(
    sendDiscordMessage({ channelId: "789", text: "hello" }),
  ).rejects.toThrow("not allowlisted");
  expect(fetchSpy).not.toHaveBeenCalled();
  for (const destination of [
    { ...channel, guild_id: "999" },
    { ...channel, id: "456" },
    { id: "123" },
  ]) {
    fetchSpy.mockResolvedValueOnce(Response.json(destination));
    await expect(send()).rejects.toThrow("not in the configured server");
  }
  expect(fetchSpy).toHaveBeenCalledTimes(3);
  expect(fetchSpy.mock.calls.every(([, init]) => init?.method !== "POST")).toBe(
    true,
  );
});

test("sends directly with bot authorization and no mentions without contacting the web app", async () => {
  fetchSpy
    .mockResolvedValueOnce(Response.json(channel))
    .mockResolvedValueOnce(Response.json({ id: "21" }));
  await sendDiscordMessage({
    channelId: "123",
    text: "hello @everyone",
    replyTo: "20",
  });
  expect(fetchSpy).toHaveBeenCalledTimes(2);
  expect(fetchSpy.mock.calls[0]).toEqual([
    "https://discord.com/api/v10/channels/123",
    {
      method: "GET",
      signal: expect.any(AbortSignal),
      headers: { Authorization: "Bot private-token" },
    },
  ]);
  expect(fetchSpy.mock.calls[1]).toEqual([
    "https://discord.com/api/v10/channels/123/messages",
    {
      method: "POST",
      signal: expect.any(AbortSignal),
      headers: {
        Authorization: "Bot private-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        content: "hello @everyone",
        allowed_mentions: { parse: [], replied_user: false },
        message_reference: {
          message_id: "20",
          channel_id: "123",
          fail_if_not_exists: true,
        },
      }),
    },
  ]);
  fetchSpy
    .mockResolvedValueOnce(Response.json(channel))
    .mockResolvedValueOnce(Response.json({ id: "22" }));
  await send();
  expect(fetchSpy.mock.calls[3]?.[1]?.body).toBe(
    JSON.stringify({
      content: "hello",
      allowed_mentions: { parse: [], replied_user: false },
    }),
  );
});

test("rejects invalid text and reply IDs without network access", async () => {
  for (const text of [" ", "a".repeat(2001)])
    await expect(
      sendDiscordMessage({ channelId: "123", text }),
    ).rejects.toThrow("1–2000");
  await expect(
    sendDiscordMessage({
      channelId: "123",
      text: "hello",
      replyTo: "../secret",
    }),
  ).rejects.toThrow("Invalid Discord reply ID");
  expect(fetchSpy).not.toHaveBeenCalled();
});

test.each(["TimeoutError", "AbortError"])(
  "%s bounds sends without retrying uncertain delivery",
  async (name) => {
    fetchSpy
      .mockResolvedValueOnce(Response.json(channel))
      .mockRejectedValueOnce(new DOMException("secret", name));
    await expect(send()).rejects.toThrow("delivery is uncertain");
    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect(fetchSpy.mock.calls[0]?.[1]?.signal).toBeInstanceOf(AbortSignal);
    expect(fetchSpy.mock.calls[1]?.[1]?.signal).toBeInstanceOf(AbortSignal);
  },
);

test.each(["TimeoutError", "AbortError"])(
  "%s during channel verification prevents sending",
  async (name) => {
    fetchSpy.mockRejectedValueOnce(new DOMException("private-token", name));
    await expect(send()).rejects.toThrow(/^Discord request failed$/);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(fetchSpy.mock.calls[0]?.[1]?.method).toBe("GET");
  },
);

test("never exposes token, API response body or fetch URL in errors", async () => {
  fetchSpy.mockResolvedValueOnce(
    new Response("private-token", { status: 401 }),
  );
  await expect(send()).rejects.toThrow(/^Discord request failed$/);
  fetchSpy
    .mockResolvedValueOnce(Response.json(channel))
    .mockRejectedValueOnce(
      new Error("private-token https://discord.com/api/v10"),
    );
  await expect(send()).rejects.toThrow(/^Discord request failed$/);
  fetchSpy
    .mockResolvedValueOnce(Response.json(channel))
    .mockResolvedValueOnce(new Response("private-token"));
  await expect(send()).rejects.toThrow(/^Discord request failed$/);
});
