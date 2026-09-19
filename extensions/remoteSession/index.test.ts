import { afterEach, describe, expect, mock, test } from "bun:test";
import { join } from "node:path";
import {
  registerRemoteSession,
  registrationError,
  relativeProject,
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
