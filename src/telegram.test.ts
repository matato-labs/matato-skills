import { afterEach, beforeEach, expect, spyOn, test } from "bun:test";
import { sendTelegramMessage } from "./telegram.ts";

const envKeys = [
  "TELEGRAM_BOT_TOKEN",
  "TELEGRAM_OWNER_ID",
  "MATATO_SKILLS_WEB_URL",
];
const originalEnv = envKeys.map((key) => [key, process.env[key]] as const);
let fetchSpy = spyOn(globalThis, "fetch");
const send = (text = "hello", chatId = "123") =>
  sendTelegramMessage({ chatId, text });

beforeEach(() => {
  process.env.TELEGRAM_BOT_TOKEN = "private-token";
  process.env.TELEGRAM_OWNER_ID = "123";
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

test("sends normalized text directly to the owner without contacting the web app", async () => {
  fetchSpy.mockResolvedValueOnce(Response.json({ ok: true }));
  await send("hello\\nworld");
  expect(fetchSpy).toHaveBeenCalledTimes(1);
  expect(fetchSpy.mock.calls[0]).toEqual([
    "https://api.telegram.org/botprivate-token/sendMessage",
    {
      method: "POST",
      signal: expect.any(AbortSignal),
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ chat_id: "123", text: "hello\nworld" }),
    },
  ]);
});

test("requires both credentials and rejects non-owner destinations before network access", async () => {
  delete process.env.TELEGRAM_BOT_TOKEN;
  await expect(send()).rejects.toThrow("TELEGRAM_BOT_TOKEN is required");
  process.env.TELEGRAM_BOT_TOKEN = "private-token";
  delete process.env.TELEGRAM_OWNER_ID;
  await expect(send()).rejects.toThrow("TELEGRAM_OWNER_ID is required");
  process.env.TELEGRAM_OWNER_ID = "123";
  await expect(send("hello", "456")).rejects.toThrow("configured owner");
  await expect(send("hello", "")).rejects.toThrow("chatId is required");
  expect(fetchSpy).not.toHaveBeenCalled();
});

test("enforces the 4096 limit after newline normalization", async () => {
  await expect(send("")).rejects.toThrow("text is required");
  await expect(send("a".repeat(4097))).rejects.toThrow("4096");
  expect(fetchSpy).not.toHaveBeenCalled();
  fetchSpy.mockResolvedValueOnce(Response.json({ ok: true }));
  await send("\\n".repeat(4096));
  expect(fetchSpy.mock.calls[0]?.[1]?.body).toBe(
    JSON.stringify({ chat_id: "123", text: "\n".repeat(4096) }),
  );
});

test.each(["TimeoutError", "AbortError"])(
  "%s bounds sends without retrying uncertain delivery",
  async (name) => {
    fetchSpy.mockRejectedValueOnce(new DOMException("secret", name));
    await expect(send()).rejects.toThrow("delivery is uncertain");
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(fetchSpy.mock.calls[0]?.[1]?.signal).toBeInstanceOf(AbortSignal);
  },
);

test("sanitizes HTTP, API, JSON and network errors", async () => {
  const failures = [
    new Response("private-token", { status: 401 }),
    Response.json({ ok: false, description: "private-token" }),
    new Response("private-token"),
  ];
  for (const failure of failures) {
    fetchSpy.mockResolvedValueOnce(failure);
    await expect(send()).rejects.toThrow(
      /^Telegram sendMessage request failed$/,
    );
  }
  fetchSpy.mockRejectedValueOnce(
    new Error("https://api.telegram.org/botprivate-token/sendMessage"),
  );
  await expect(send()).rejects.toThrow(/^Telegram sendMessage request failed$/);
});
