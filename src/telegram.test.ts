import {
  afterAll,
  afterEach,
  beforeEach,
  describe,
  expect,
  spyOn,
  test,
} from "bun:test";
import { getTelegramUpdates, sendTelegramMessage } from "./telegram.ts";

const originalToken = process.env.TELEGRAM_BOT_TOKEN;
const fetchSpy = spyOn(globalThis, "fetch");

beforeEach(() => {
  process.env.TELEGRAM_BOT_TOKEN = "token";
});

afterEach(() => {
  fetchSpy.mockReset();
  if (originalToken === undefined) delete process.env.TELEGRAM_BOT_TOKEN;
  else process.env.TELEGRAM_BOT_TOKEN = originalToken;
});

afterAll(() => fetchSpy.mockRestore());

describe("Telegram API", () => {
  test("sends normalized text", async () => {
    fetchSpy.mockResolvedValue(new Response(JSON.stringify({ ok: true })));

    await sendTelegramMessage({ chatId: "123", text: "hello\\nworld" });

    expect(fetchSpy).toHaveBeenCalledWith(
      "https://api.telegram.org/bottoken/sendMessage",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ chat_id: "123", text: "hello\nworld" }),
      },
    );
  });

  test("maps user text updates and advances past ignored updates", async () => {
    fetchSpy.mockResolvedValue(
      new Response(
        JSON.stringify({
          ok: true,
          result: [
            {
              update_id: 4,
              message: {
                date: 0,
                chat: { id: 1 },
                from: { id: 1, is_bot: true },
                text: "ignore",
              },
            },
            {
              update_id: 5,
              message: {
                date: 1,
                chat: { id: 2 },
                from: { id: 7, username: "leon" },
                text: "hello",
              },
            },
          ],
        }),
      ),
    );

    await expect(getTelegramUpdates({ offset: 4 })).resolves.toEqual({
      nextOffset: 6,
      updates: [
        {
          chatId: "2",
          from: "leon",
          text: "hello",
          sentAt: "1970-01-01T00:00:01.000Z",
        },
      ],
    });
  });

  test("keeps inbound text raw and preserves literal backslash-n", async () => {
    fetchSpy.mockResolvedValue(
      new Response(
        JSON.stringify({
          ok: true,
          result: [
            {
              update_id: 9,
              message: {
                date: 1,
                chat: { id: 2 },
                from: { id: 7, username: "leon" },
                text: "hello\\nworld",
              },
            },
          ],
        }),
      ),
    );

    await expect(getTelegramUpdates({ offset: 9 })).resolves.toEqual({
      nextOffset: 10,
      updates: [
        {
          chatId: "2",
          from: "leon",
          text: "hello\\nworld",
          sentAt: "1970-01-01T00:00:01.000Z",
        },
      ],
    });
  });

  test("forwards the offset and keeps it when no updates arrive", async () => {
    fetchSpy.mockResolvedValue(
      new Response(JSON.stringify({ ok: true, result: [] })),
    );

    await expect(getTelegramUpdates({ offset: 7 })).resolves.toEqual({
      updates: [],
      nextOffset: 7,
    });
    expect(String(fetchSpy.mock.calls[0]?.[0])).toContain("offset=7");
  });

  test("fails clearly when configuration or Telegram rejects a request", async () => {
    delete process.env.TELEGRAM_BOT_TOKEN;
    await expect(getTelegramUpdates({ offset: null })).rejects.toThrow(
      "TELEGRAM_BOT_TOKEN is required",
    );

    process.env.TELEGRAM_BOT_TOKEN = "token";
    fetchSpy.mockResolvedValue(
      new Response("server exploded", { status: 500 }),
    );
    await expect(getTelegramUpdates({ offset: null })).rejects.toThrow(
      "Telegram getUpdates request failed with status 500 and message server exploded",
    );

    fetchSpy.mockResolvedValue(
      new Response(JSON.stringify({ ok: false, description: "blocked" })),
    );
    await expect(
      sendTelegramMessage({ chatId: "1", text: "hello" }),
    ).rejects.toThrow("Telegram sendMessage failed: blocked");

    await expect(
      sendTelegramMessage({ chatId: "", text: "hello" }),
    ).rejects.toThrow("Telegram chatId is required");
    await expect(
      sendTelegramMessage({ chatId: "1", text: "" }),
    ).rejects.toThrow("Telegram message text is required");
  });
});
