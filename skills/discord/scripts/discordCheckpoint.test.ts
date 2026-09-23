import { afterEach, expect, test } from "bun:test";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  clearPendingDiscordCheckpoint,
  commitDiscordCheckpoint,
  readDiscordCheckpoint,
  writeDiscordCheckpoint,
  writePendingDiscordCheckpoint,
} from "./discordCheckpoint.ts";

const originalStorage = process.env.MATATO_PI_CONFIG;
const directories: Array<string> = [];
afterEach(async () => {
  if (originalStorage === undefined) delete process.env.MATATO_PI_CONFIG;
  else process.env.MATATO_PI_CONFIG = originalStorage;
  for (const directory of directories.splice(0))
    await rm(directory, { recursive: true, force: true });
});

const useTemporaryStorage = async (): Promise<string> => {
  const directory = await mkdtemp(join(tmpdir(), "discordCheckpoint"));
  directories.push(directory);
  process.env.MATATO_PI_CONFIG = directory;
  return directory;
};

test("stages a cursor and commits only after a successful run", async () => {
  const directory = await useTemporaryStorage();
  expect(await readDiscordCheckpoint()).toBeNull();
  await writeDiscordCheckpoint({ "channel-1": "10" });
  await writePendingDiscordCheckpoint({ "channel-1": "11", "thread-1": "12" });
  expect(await readDiscordCheckpoint()).toEqual({ "channel-1": "10" });
  await commitDiscordCheckpoint();
  expect(await readDiscordCheckpoint()).toEqual({
    "channel-1": "11",
    "thread-1": "12",
  });
  expect(
    await readFile(join(directory, "discord", "checkpoint.json"), "utf8"),
  ).toContain("thread-1");
});

test("clears stale pending work without committing it", async () => {
  await useTemporaryStorage();
  await writePendingDiscordCheckpoint({ "channel-1": "11" });
  await clearPendingDiscordCheckpoint();
  expect(await readDiscordCheckpoint()).toBeNull();
});
