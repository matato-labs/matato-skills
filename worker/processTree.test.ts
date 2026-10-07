import { describe, expect, test } from "bun:test";
import { execute } from "./process.ts";

function killProcess(pid: number, group = false): void {
  if (!pid) return;
  try {
    process.kill(group ? -pid : pid, "SIGKILL");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ESRCH") throw error;
  }
}

async function waitForExit(pid: number): Promise<void> {
  const deadline = Date.now() + 2_000;
  while (Date.now() < deadline) {
    try {
      process.kill(pid, 0);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ESRCH") return;
      throw error;
    }
    await Bun.sleep(10);
  }
  throw new Error(`Process ${pid} survived shutdown`);
}

function hookScript(exitLeader: boolean, closePipes: boolean): string {
  const descendantScript = `
    process.on("SIGTERM", () => {});
    setInterval(() => {}, 1000);
    process.send("ready");
  `;
  const pipeMode = JSON.stringify(closePipes ? "ignore" : "inherit");
  return `
    const { spawn } = require("node:child_process");
    console.log("leader " + process.pid);
    const descendant = spawn(process.execPath, ["-e", ${JSON.stringify(descendantScript)}], {
      stdio: ["ignore", ${pipeMode}, ${pipeMode}, "ipc"],
    });
    descendant.once("message", () => {
      descendant.disconnect();
      process.stdout.write("descendant " + descendant.pid + "\\n", () => {
        if (${exitLeader}) process.exit(0);
      });
    });
    setInterval(() => {}, 1000);
  `;
}

describe("worker subprocess tree shutdown", () => {
  test.skipIf(process.platform === "win32").each([
    { name: "running leader", exitLeader: false, closePipes: false },
    { name: "already-exited leader", exitLeader: true, closePipes: false },
    { name: "descendant closes pipes", exitLeader: false, closePipes: true },
  ])(
    "abort cleans up SIGTERM-resistant descendants: $name",
    async ({ exitLeader, closePipes }) => {
      const controller = new AbortController();
      const ready = Promise.withResolvers<void>();
      const timeout = Promise.withResolvers<never>();
      let leaderPid = 0;
      let descendantPid = 0;
      let output = "";
      const timer = setTimeout(
        () => timeout.reject(new Error("Hook execution timed out")),
        8_000,
      );
      const result = execute(
        process.execPath,
        ["-e", hookScript(exitLeader, closePipes)],
        {
          cwd: process.cwd(),
          env: process.env,
          signal: controller.signal,
          onStdout: (chunk) => {
            output += chunk;
            const lines = output.split("\n");
            output = lines.pop() ?? "";
            for (const line of lines) {
              const [name, pid] = line.split(" ");
              if (name === "leader") leaderPid = Number(pid);
              if (name !== "descendant") continue;
              descendantPid = Number(pid);
              ready.resolve();
            }
          },
        },
      ).then(
        () => "completed",
        (error: Error) => {
          ready.reject(error);
          return error.message;
        },
      );
      try {
        await Promise.race([ready.promise, timeout.promise]);
        if (exitLeader) await waitForExit(leaderPid);
        controller.abort();
        expect(await Promise.race([result, timeout.promise])).toBe(
          "Worker stopped",
        );
        await waitForExit(leaderPid);
        await waitForExit(descendantPid);
      } finally {
        clearTimeout(timer);
        controller.abort();
        killProcess(leaderPid, true);
        killProcess(leaderPid);
        killProcess(descendantPid);
        await result;
        if (leaderPid) await waitForExit(leaderPid);
        if (descendantPid) await waitForExit(descendantPid);
      }
    },
    15_000,
  );
});
