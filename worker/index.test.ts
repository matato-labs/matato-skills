import { expect, test } from "bun:test";
import { spawn } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

for (const signal of ["SIGTERM", "SIGINT"] as const) {
  test(`worker remains alive without jobs and shuts down on ${signal}`, async () => {
    const root = await mkdtemp(join(tmpdir(), "workerEntryTest"));
    const config = join(root, "config.json");
    if (signal === "SIGINT") await writeFile(config, '{"automations":[]}');
    const child = spawn(
      process.execPath,
      [fileURLToPath(new URL("./index.ts", import.meta.url))],
      {
        env: { ...process.env, MATATO_PI_AUTOMATIONS_CONFIG: config },
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    let output = "";
    let errors = "";
    const exited = new Promise<number | null>((resolve, reject) => {
      child.once("error", reject);
      child.once("close", resolve);
    });
    const ready = new Promise<void>((resolve, reject) => {
      child.once("error", reject);
      child.once("exit", () =>
        reject(new Error(`Worker exited before startup: ${errors}`)),
      );
      child.stdout.on("data", (chunk: Buffer) => {
        output += chunk.toString();
        if (output.includes("Watching")) resolve();
      });
      child.stderr.on("data", (chunk: Buffer) => {
        errors += chunk.toString();
      });
    });
    try {
      await ready;
      await Bun.sleep(40);
      expect(child.exitCode).toBeNull();
      expect(child.signalCode).toBeNull();
      child.kill(signal);
      expect(await exited).toBe(0);
      expect(output).toContain("Stopped");
      expect(errors).toBe("");
      expect(output).toContain("Scheduled: none");
    } finally {
      child.kill("SIGKILL");
      await rm(root, { recursive: true, force: true });
    }
  });
}
