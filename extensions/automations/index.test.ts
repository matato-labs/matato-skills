import { afterEach, describe, expect, mock, test } from "bun:test";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadAutomations } from "./index.ts";

const originalConfig = process.env.MATATO_PI_CONFIG;
const originalAutomations = process.env.MATATO_PI_AUTOMATIONS_CONFIG;
const directories: Array<string> = [];

afterEach(async () => {
  if (originalConfig === undefined) delete process.env.MATATO_PI_CONFIG;
  else process.env.MATATO_PI_CONFIG = originalConfig;
  if (originalAutomations === undefined)
    delete process.env.MATATO_PI_AUTOMATIONS_CONFIG;
  else process.env.MATATO_PI_AUTOMATIONS_CONFIG = originalAutomations;
  await Promise.all(
    directories.splice(0).map((path) => rm(path, { recursive: true })),
  );
});

async function temporaryDirectory(): Promise<string> {
  const path = await mkdtemp(join(tmpdir(), "matatoAutomationsBrowser"));
  directories.push(path);
  return path;
}

const emptyApi = () =>
  mock(() => Promise.resolve(Response.json({ automations: [] })));

describe("automation browser source", () => {
  test("local jobs do not require the web app", async () => {
    const path = join(await temporaryDirectory(), "config.json");
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = path;
    await writeFile(
      path,
      JSON.stringify({
        automations: [
          {
            jobName: "heartbeat",
            enabled: true,
            schedule: "0 9 * * *",
            userPrompt: "Review work",
            model: "configuredModel",
            thinkingLevel: "low",
            canLaunchSubAgents: false,
          },
        ],
      }),
    );
    const fetchImpl = emptyApi();
    const jobs = await loadAutomations(fetchImpl);
    expect(jobs[0].jobName).toBe("heartbeat");
    expect(jobs[0].useSkill).toBe(true);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test("prefers the default local file over web jobs", async () => {
    delete process.env.MATATO_PI_AUTOMATIONS_CONFIG;
    const directory = await temporaryDirectory();
    process.env.MATATO_PI_CONFIG = directory;
    await mkdir(join(directory, "automations"));
    await writeFile(
      join(directory, "automations", "config.json"),
      '{"automations":[]}',
    );
    const fetchImpl = emptyApi();
    expect(await loadAutomations(fetchImpl)).toEqual([]);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test("an explicit missing config does not fall back to HTTP", async () => {
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = join(
      await temporaryDirectory(),
      "missing.json",
    );
    const fetchImpl = emptyApi();
    expect(await loadAutomations(fetchImpl)).toEqual([]);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test("retains web app browsing when no local config exists", async () => {
    delete process.env.MATATO_PI_AUTOMATIONS_CONFIG;
    process.env.MATATO_PI_CONFIG = await temporaryDirectory();
    const fetchImpl = emptyApi();
    expect(await loadAutomations(fetchImpl)).toEqual([]);
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });

  test("broken local JSON is surfaced instead of falling back to HTTP", async () => {
    const path = join(await temporaryDirectory(), "broken.json");
    process.env.MATATO_PI_AUTOMATIONS_CONFIG = path;
    await writeFile(path, "{");
    const fetchImpl = emptyApi();
    await expect(loadAutomations(fetchImpl)).rejects.toThrow();
    expect(fetchImpl).not.toHaveBeenCalled();
  });
});
