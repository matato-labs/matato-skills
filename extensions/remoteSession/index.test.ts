import { afterEach, describe, expect, mock, test } from "bun:test";
import { join } from "node:path";
import {
  registerRemoteSession,
  registrationError,
  relativeProject,
  type CommandRunner,
  type FetchLike,
  type RemoteSessionContext,
} from "./index.ts";

const workspace = process.env.WORKSPACE;

afterEach(() => {
  if (workspace === undefined) delete process.env.WORKSPACE;
  else process.env.WORKSPACE = workspace;
});

function context(
  overrides: Partial<{
    cwd: string;
    sessionFile: string | undefined;
    sessionId: string;
  }> = {},
) {
  const notifications: Array<{ message: string; type?: string }> = [];
  const ctx: RemoteSessionContext = {
    cwd: overrides.cwd ?? join(process.env.WORKSPACE ?? "/workspace", "alpha"),
    sessionManager: {
      getSessionFile: () =>
        "sessionFile" in overrides
          ? overrides.sessionFile
          : "/sessions/abc.jsonl",
      getSessionId: () => overrides.sessionId ?? "pi-123",
    },
    ui: {
      notify: (message, type) => notifications.push({ message, type }),
    },
  };
  return { ctx, notifications };
}

function okFetch(): FetchLike {
  return mock(() =>
    Promise.resolve(
      new Response(JSON.stringify({ session: { id: "remote-id-1" } }), {
        status: 201,
      }),
    ),
  );
}

describe("registerRemoteSession", () => {
  test("rejects an ephemeral session without calling the web app", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const { ctx, notifications } = context({ sessionFile: undefined });

    await registerRemoteSession("", ctx, fetchImpl);

    expect(fetchImpl).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      { message: expect.stringContaining("ephemeral"), type: "error" },
    ]);
  });

  test("rejects when WORKSPACE is not set", async () => {
    delete process.env.WORKSPACE;
    const fetchImpl = okFetch();
    const { ctx, notifications } = context({ cwd: "/somewhere" });

    await registerRemoteSession("", ctx, fetchImpl);

    expect(fetchImpl).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      {
        message: expect.stringContaining("WORKSPACE is not set"),
        type: "error",
      },
    ]);
  });

  test("rejects when the session runs outside WORKSPACE", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const { ctx, notifications } = context({ cwd: "/elsewhere/alpha" });

    await registerRemoteSession("", ctx, fetchImpl);

    expect(fetchImpl).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      { message: expect.stringContaining("outside WORKSPACE"), type: "error" },
    ]);
  });

  test("registers the session with the given name", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const { ctx, notifications } = context({ cwd: "/workspace/alpha" });

    await registerRemoteSession("My session", ctx, fetchImpl);

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [url, init] = (fetchImpl as ReturnType<typeof mock>).mock.calls[0];
    expect(url).toBe("http://localhost:4000/api/sessions");
    expect(JSON.parse(String(init?.body))).toEqual({
      name: "My session",
      relative_project: "alpha",
      session_file: "/sessions/abc.jsonl",
      pi_session_id: "pi-123",
    });
    expect(notifications).toEqual([
      {
        message:
          'Registered remote session "My session". Open it at http://localhost:4000/sessions/remote-id-1',
        type: "info",
      },
    ]);
  });

  test("copies and registers the session through an SSH-config host", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const commandRunner: CommandRunner = mock((command: string) =>
      Promise.resolve(
        command === "ssh"
          ? { stdout: "/home/pi\n", stderr: "" }
          : { stdout: "", stderr: "" },
      ),
    );
    const { ctx, notifications } = context({ cwd: "/workspace/alpha" });

    await registerRemoteSession(
      "My session --host piServer",
      ctx,
      fetchImpl,
      commandRunner,
    );

    expect(commandRunner).toHaveBeenNthCalledWith(1, "ssh", [
      "piServer",
      "mkdir -p .pi/agent/sessions && pwd",
    ]);
    expect(commandRunner).toHaveBeenNthCalledWith(2, "scp", [
      "/sessions/abc.jsonl",
      "piServer:.pi/agent/sessions/abc.jsonl",
    ]);
    const [url, init] = (fetchImpl as ReturnType<typeof mock>).mock.calls[0];
    expect(url).toBe("http://piServer:4000/api/sessions");
    expect(JSON.parse(String(init?.body))).toEqual({
      name: "My session",
      relative_project: "alpha",
      session_file: "/home/pi/.pi/agent/sessions/abc.jsonl",
      pi_session_id: "pi-123",
    });
    expect(notifications).toEqual([
      {
        message:
          'Registered remote session "My session". Open it at http://piServer:4000/sessions/remote-id-1',
        type: "info",
      },
    ]);
  });

  test("shows an error without registering when SSH storage preparation fails", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const commandRunner: CommandRunner = mock(() =>
      Promise.reject(new Error("connection refused")),
    );
    const { ctx, notifications } = context();

    await registerRemoteSession(
      "--host piServer",
      ctx,
      fetchImpl,
      commandRunner,
    );

    expect(fetchImpl).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      {
        message:
          "Could not prepare Pi session storage on piServer via SSH: connection refused",
        type: "error",
      },
    ]);
  });

  test("shows an error without registering when SCP fails", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const commandRunner: CommandRunner = mock((command: string) =>
      command === "ssh"
        ? Promise.resolve({ stdout: "/home/pi\n", stderr: "" })
        : Promise.reject(new Error("disk full")),
    );
    const { ctx, notifications } = context();

    await registerRemoteSession(
      "--host piServer",
      ctx,
      fetchImpl,
      commandRunner,
    );

    expect(fetchImpl).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      {
        message:
          "Could not copy the session file to piServer via SCP: disk full",
        type: "error",
      },
    ]);
  });

  test("shows the remote API error without a success notification", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl: FetchLike = mock(() =>
      Promise.resolve(
        new Response(JSON.stringify({ error: "Invalid session path" }), {
          status: 422,
        }),
      ),
    );
    const commandRunner: CommandRunner = mock(() =>
      Promise.resolve({ stdout: "/home/pi\n", stderr: "" }),
    );
    const { ctx, notifications } = context();

    await registerRemoteSession(
      "--host piServer",
      ctx,
      fetchImpl,
      commandRunner,
    );

    expect(notifications).toEqual([
      { message: "Registration failed: Invalid session path", type: "error" },
    ]);
  });

  test("rejects invalid SSH host syntax without transferring or registering", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const commandRunner: CommandRunner = mock(() =>
      Promise.resolve({ stdout: "", stderr: "" }),
    );
    const { ctx, notifications } = context();

    await registerRemoteSession(
      "My session --host -oProxyCommand",
      ctx,
      fetchImpl,
      commandRunner,
    );

    expect(fetchImpl).not.toHaveBeenCalled();
    expect(commandRunner).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      { message: expect.stringContaining("Invalid SSH host"), type: "error" },
    ]);
  });

  test("rejects repeated SSH host options without transferring or registering", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const commandRunner: CommandRunner = mock(() =>
      Promise.resolve({ stdout: "", stderr: "" }),
    );
    const { ctx, notifications } = context();

    await registerRemoteSession(
      "My session --host piServer --host anotherServer",
      ctx,
      fetchImpl,
      commandRunner,
    );

    expect(fetchImpl).not.toHaveBeenCalled();
    expect(commandRunner).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      {
        message: expect.stringContaining("Invalid --host syntax"),
        type: "error",
      },
    ]);
  });

  test("defaults the name to the project directory", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const { ctx } = context({ cwd: "/workspace/alpha" });

    await registerRemoteSession("  ", ctx, fetchImpl);

    const [, init] = (fetchImpl as ReturnType<typeof mock>).mock.calls[0];
    expect(JSON.parse(String(init?.body)).name).toBe("alpha");
  });

  test("shows a clear error when the web app is down", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl: FetchLike = mock(() =>
      Promise.reject(new Error("connection refused")),
    );
    const { ctx, notifications } = context();

    await registerRemoteSession("", ctx, fetchImpl);

    expect(notifications).toEqual([
      {
        message:
          "Could not reach the Matato web app at http://localhost:4000. Is it running?",
        type: "error",
      },
    ]);
  });

  test("shows the server error when registration fails", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl: FetchLike = mock(() =>
      Promise.resolve(
        new Response(JSON.stringify({ error: "Invalid session path" }), {
          status: 422,
        }),
      ),
    );
    const { ctx, notifications } = context();

    await registerRemoteSession("", ctx, fetchImpl);

    expect(notifications).toEqual([
      { message: "Registration failed: Invalid session path", type: "error" },
    ]);
  });
});

describe("registration preparation", () => {
  test("invalid command is reported before missing session or workspace", async () => {
    delete process.env.WORKSPACE;
    const fetchImpl = okFetch();
    const { ctx, notifications } = context({ sessionFile: undefined });
    await registerRemoteSession("--host", ctx, fetchImpl);
    expect(fetchImpl).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      { message: expect.stringContaining("Invalid SSH host"), type: "error" },
    ]);
  });

  test("reads the session ID after copying and preserves lookup failure handling", async () => {
    process.env.WORKSPACE = "/workspace";
    const fetchImpl = okFetch();
    const { ctx, notifications } = context();
    const commandRunner = mock<CommandRunner>(() =>
      Promise.resolve({ stdout: "/home/pi\n", stderr: "" }),
    );
    ctx.sessionManager.getSessionId = () => {
      expect(commandRunner).toHaveBeenCalledTimes(2);
      throw new Error("session ID unavailable");
    };
    await registerRemoteSession(
      "--host piServer",
      ctx,
      fetchImpl,
      commandRunner,
    );
    expect(fetchImpl).not.toHaveBeenCalled();
    expect(notifications).toEqual([
      {
        message:
          "Could not reach the Matato web app at http://piServer:4000. Is it running?",
        type: "error",
      },
    ]);
  });

  test("non-Error API failures retain the connectivity fallback", async () => {
    process.env.WORKSPACE = "/workspace";
    const { ctx, notifications } = context();
    const fetchImpl: FetchLike = () => Promise.reject("offline");
    await registerRemoteSession("", ctx, fetchImpl);
    expect(notifications).toEqual([
      {
        message:
          "Could not reach the Matato web app at http://localhost:4000. Is it running?",
        type: "error",
      },
    ]);
  });
});

describe("relativeProject", () => {
  test("resolves nested directories", () => {
    expect(relativeProject("/workspace/alpha/sub", "/workspace")).toBe(
      join("alpha", "sub"),
    );
  });

  test("resolves the workspace root", () => {
    expect(relativeProject("/workspace", "/workspace")).toBe(".");
  });

  test("rejects paths outside the workspace", () => {
    expect(() => relativeProject("/other", "/workspace")).toThrow(
      "outside WORKSPACE",
    );
  });
});

describe("registrationError", () => {
  test("prefers the top-level error message", () => {
    expect(registrationError(422, { error: "Invalid project" })).toBe(
      "Registration failed: Invalid project",
    );
  });

  test("flattens changeset errors", () => {
    expect(registrationError(422, { errors: { name: ["is invalid"] } })).toBe(
      "Registration failed: is invalid",
    );
  });

  test("falls back to the status code", () => {
    expect(registrationError(500, {})).toBe(
      "Registration failed with status 500.",
    );
  });
});
