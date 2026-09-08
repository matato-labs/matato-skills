import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { storagePath } from "./storagePath.ts";

export type TelegramCheckpoint = {
  nextOffset: number | null;
  lastPolledAt: string | null;
};
type LegacyTelegramCheckpoint = { updateId?: number };
type TelegramCheckpointFile = TelegramCheckpoint | LegacyTelegramCheckpoint;

export const telegramCheckpointPath = (): string =>
  join(storagePath(), "telegram", "checkpoint.json");

export async function readTelegramCheckpoint(): Promise<TelegramCheckpoint> {
  try {
    const value = JSON.parse(
      await readFile(telegramCheckpointPath(), "utf8"),
    ) as TelegramCheckpointFile;
    if ("nextOffset" in value) return value;
    return {
      nextOffset: value.updateId === undefined ? null : value.updateId + 1,
      lastPolledAt: null,
    };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT")
      return { nextOffset: null, lastPolledAt: null };
    throw new Error("Invalid Telegram checkpoint", { cause: error });
  }
}

const writeCheckpoint = async (
  path: string,
  nextOffset: number,
): Promise<void> => {
  if (!Number.isInteger(nextOffset) || nextOffset < 0)
    throw new Error("Invalid Telegram checkpoint offset");
  await mkdir(dirname(path), { recursive: true });
  const temporaryPath = `${path}.tmp`;
  await writeFile(
    temporaryPath,
    `${JSON.stringify({ nextOffset, lastPolledAt: new Date().toISOString() })}\n`,
    { encoding: "utf8", mode: 0o600 },
  );
  await rename(temporaryPath, path);
};

export const writeTelegramCheckpoint = (nextOffset: number): Promise<void> =>
  writeCheckpoint(telegramCheckpointPath(), nextOffset);

export const pendingTelegramCheckpointPath = (): string =>
  `${telegramCheckpointPath()}.pending`;

export const writePendingTelegramCheckpoint = (
  nextOffset: number,
): Promise<void> =>
  writeCheckpoint(pendingTelegramCheckpointPath(), nextOffset);

export async function commitTelegramCheckpoint(): Promise<boolean> {
  try {
    await rename(pendingTelegramCheckpointPath(), telegramCheckpointPath());
    return true;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return false;
    throw error;
  }
}
