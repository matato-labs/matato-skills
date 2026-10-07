import { spawn, type ChildProcess } from "node:child_process";

export type ExecutionOptions = {
  cwd: string;
  env: NodeJS.ProcessEnv;
  signal?: AbortSignal;
  onStdout?: (chunk: string) => void;
};
export type Execute = (
  command: string,
  args: Array<string>,
  options: ExecutionOptions,
) => Promise<string>;

function stopProcess(child: ChildProcess, signal: NodeJS.Signals): void {
  if (!child.pid) return;
  try {
    if (process.platform === "win32") child.kill(signal);
    else process.kill(-child.pid, signal);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ESRCH") throw error;
  }
}

export const execute: Execute = (command, args, options) => {
  if (options.signal?.aborted)
    return Promise.reject(new Error("Worker stopped"));
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env,
      stdio: ["ignore", "pipe", "pipe"],
      detached: process.platform !== "win32",
    });
    let stdout = "";
    let stderr = "";
    let finished = false;
    let killTimer: ReturnType<typeof setTimeout> | undefined;
    const finish = (error?: Error): void => {
      if (finished) return;
      finished = true;
      if (killTimer) clearTimeout(killTimer);
      options.signal?.removeEventListener("abort", abort);
      if (error) reject(error);
      else resolve(stdout);
    };
    const terminate = (signal: NodeJS.Signals): void => {
      try {
        stopProcess(child, signal);
      } catch (error) {
        finish(error as Error);
      }
    };
    const abort = (): void => {
      if (finished || killTimer) return;
      terminate("SIGTERM");
      if (finished) return;
      killTimer = setTimeout(() => terminate("SIGKILL"), 5_000);
      killTimer.unref();
    };
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      if (options.onStdout) options.onStdout(chunk);
      else stdout += chunk;
    });
    child.stderr.on("data", (chunk: string) => {
      stderr = (stderr + chunk).slice(-8_192);
    });
    child.once("error", finish);
    child.once("close", (code, signal) => {
      if (options.signal?.aborted) {
        // The leader can exit before descendants, even after closing their pipes.
        terminate("SIGKILL");
        return finish(new Error("Worker stopped"));
      }
      if (code !== 0)
        return finish(
          new Error(stderr.trim() || `${command} exited: ${signal ?? code}`),
        );
      finish();
    });
    options.signal?.addEventListener("abort", abort, { once: true });
    if (options.signal?.aborted) abort();
  });
};
