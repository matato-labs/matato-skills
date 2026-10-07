import { describe, expect, test } from "bun:test";
import { execute } from "./process.ts";

describe("worker subprocess execution", () => {
  test("drains stdout and inherits explicitly supplied env", async () => {
    const stdout = await execute(
      process.execPath,
      ["-e", "console.log(process.env.MATATO_PI_CONFIG)"],
      {
        cwd: process.cwd(),
        env: { ...process.env, MATATO_PI_CONFIG: "testStorage" },
      },
    );
    expect(stdout.trim()).toBe("testStorage");
  });

  test("streams output without retaining it", async () => {
    let streamed = "";
    const stdout = await execute(
      process.execPath,
      ["-e", 'console.log("streamed")'],
      {
        cwd: process.cwd(),
        env: process.env,
        onStdout: (chunk) => {
          streamed += chunk;
        },
      },
    );
    expect(stdout).toBe("");
    expect(streamed.trim()).toBe("streamed");
  });

  test("captures failure diagnostics and missing executables", async () => {
    const options = { cwd: process.cwd(), env: process.env };
    await expect(
      execute(
        process.execPath,
        ["-e", 'console.error("failed");process.exit(2)'],
        options,
      ),
    ).rejects.toThrow("failed");
    await expect(
      execute("/nonexistentWorkerTestExecutable", [], options),
    ).rejects.toThrow();
  });

  test("abort tolerates a child that failed to spawn", async () => {
    const controller = new AbortController();
    const child = execute("/nonexistentWorkerTestExecutable", [], {
      cwd: process.cwd(),
      env: process.env,
      signal: controller.signal,
    });
    controller.abort();
    await expect(child).rejects.toThrow();
  });

  test("abort stops running children and forbids subsequent launches", async () => {
    const controller = new AbortController();
    const child = execute(
      process.execPath,
      ["-e", 'console.log("ready");setInterval(()=>{},1000)'],
      {
        cwd: process.cwd(),
        env: process.env,
        signal: controller.signal,
        onStdout: () => controller.abort(),
      },
    );
    await expect(child).rejects.toThrow("Worker stopped");
    await expect(
      execute(process.execPath, ["-e", "process.exit(0)"], {
        cwd: process.cwd(),
        env: process.env,
        signal: controller.signal,
      }),
    ).rejects.toThrow("Worker stopped");
  });
});
