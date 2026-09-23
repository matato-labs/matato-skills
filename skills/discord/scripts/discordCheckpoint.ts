import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { storagePath } from "../../../src/storagePath.ts";

export type DiscordCheckpoint = Record<string, string>;
const checkpointPath = (): string =>
  join(storagePath(), "discord", "checkpoint.json");
const pendingPath = (): string => `${checkpointPath()}.pending`;

export const readDiscordCheckpoint =
  async (): Promise<DiscordCheckpoint | null> => {
    try {
      return JSON.parse(
        await readFile(checkpointPath(), "utf8"),
      ) as DiscordCheckpoint;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
      throw new Error("Invalid Discord checkpoint", { cause: error });
    }
  };

const save = async (
  path: string,
  checkpoint: DiscordCheckpoint,
): Promise<void> => {
  await mkdir(dirname(path), { recursive: true });
  const temporaryPath = `${path}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(checkpoint)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
  await rename(temporaryPath, path);
};

export const writeDiscordCheckpoint = (
  checkpoint: DiscordCheckpoint,
): Promise<void> => save(checkpointPath(), checkpoint);

export const writePendingDiscordCheckpoint = (
  checkpoint: DiscordCheckpoint,
): Promise<void> => save(pendingPath(), checkpoint);

export const clearPendingDiscordCheckpoint = (): Promise<void> =>
  rm(pendingPath(), { force: true });

export const commitDiscordCheckpoint = async (): Promise<void> => {
  await rename(pendingPath(), checkpointPath());
};
