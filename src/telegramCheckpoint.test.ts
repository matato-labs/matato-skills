import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  readTelegramCheckpoint,
  telegramCheckpointPath,
  writeTelegramCheckpoint,
} from "./telegramCheckpoint.ts";

let directory: string;
const originalStoragePath = process.env.MATATO_PI_STORAGE_PATH;

beforeEach(async () => {
  directory = await mkdtemp(join(tmpdir(), "matato-pi-telegram-"));
  process.env.MATATO_PI_STORAGE_PATH = directory;
});

afterEach(async () => {
  await rm(directory, { recursive: true, force: true });
  if (originalStoragePath === undefined)
    delete process.env.MATATO_PI_STORAGE_PATH;
  else process.env.MATATO_PI_STORAGE_PATH = originalStoragePath;
});

describe("Telegram checkpoint", () => {
  test("starts empty and persists the next Telegram offset", async () => {
    await expect(readTelegramCheckpoint()).resolves.toEqual({
      nextOffset: null,
      lastPolledAt: null,
    });

    await writeTelegramCheckpoint(42);

    expect(telegramCheckpointPath()).toBe(
      join(directory, "telegram", "checkpoint.json"),
    );
    await expect(readTelegramCheckpoint()).resolves.toMatchObject({
      nextOffset: 42,
    });
  });

  test("rejects invalid offsets", async () => {
    await expect(writeTelegramCheckpoint(-1)).rejects.toThrow(
      "Invalid Telegram checkpoint offset",
    );
  });
});
