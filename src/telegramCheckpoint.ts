import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

export type TelegramCheckpoint = {
  nextOffset: number | null;
  lastPolledAt: string | null;
};

export const telegramCheckpointPath = (): string =>
  join(
    process.env.MATATO_PI_STORAGE_PATH ??
      process.env.STORAGE_PATH ??
      join(homedir(), ".config", "matato-pi"),
    "telegram",
    "checkpoint.json",
  );

export async function readTelegramCheckpoint(): Promise<TelegramCheckpoint> {
  try {
    const value = JSON.parse(
      await readFile(telegramCheckpointPath(), "utf8"),
    ) as Partial<TelegramCheckpoint> & { updateId?: number };
    if (typeof value.nextOffset === "number" || value.nextOffset === null)
      return {
        nextOffset: value.nextOffset,
        lastPolledAt:
          typeof value.lastPolledAt === "string" ? value.lastPolledAt : null,
      };
    return {
      nextOffset:
        typeof value.updateId === "number" ? value.updateId + 1 : null,
      lastPolledAt: null,
    };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT")
      return { nextOffset: null, lastPolledAt: null };
    throw new Error("Invalid Telegram checkpoint", { cause: error });
  }
}

export async function writeTelegramCheckpoint(
  nextOffset: number,
): Promise<void> {
  if (!Number.isInteger(nextOffset) || nextOffset < 0)
    throw new Error("Invalid Telegram checkpoint offset");
  const path = telegramCheckpointPath();
  await mkdir(dirname(path), { recursive: true });
  const temporaryPath = `${path}.tmp`;
  await writeFile(
    temporaryPath,
    `${JSON.stringify({ nextOffset, lastPolledAt: new Date().toISOString() })}\n`,
    { encoding: "utf8", mode: 0o600 },
  );
  await rename(temporaryPath, path);
}
