import { isAbsolute, basename, relative, resolve, sep } from "node:path";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

const webUrl = process.env.MATATO_PI_WEB_URL ?? "http://localhost:4000";

type SessionInfo = {
  getSessionFile(): string | undefined;
  getSessionId(): string;
};

export type RemoteSessionContext = {
  cwd: string;
  sessionManager: SessionInfo;
  ui: { notify(message: string, type?: "info" | "warning" | "error"): void };
};

export type FetchLike = (url: string, init?: RequestInit) => Promise<Response>;

type RegistrationResponse = { session: { id: string } };
type ErrorResponse = { error?: string; errors?: Record<string, Array<string>> };

export function relativeProject(cwd: string, workspace: string): string {
  const relativePath = relative(resolve(workspace), cwd);
  if (isAbsolute(relativePath) || relativePath.split(sep)[0] === "..")
    throw new Error(
      "The current directory is outside WORKSPACE; the session cannot be registered.",
    );
  return relativePath === "" ? "." : relativePath;
}

export function registrationError(status: number, body: ErrorResponse): string {
  const detail =
    body.error ??
    Object.values(body.errors ?? {})
      .flat()
      .join(", ");
  return detail
    ? `Registration failed: ${detail}`
    : `Registration failed with status ${status}.`;
}

export async function registerRemoteSession(
  args: string,
  ctx: RemoteSessionContext,
  fetchImpl: FetchLike = fetch,
): Promise<void> {
  const sessionFile = ctx.sessionManager.getSessionFile();
  if (!sessionFile) {
    ctx.ui.notify(
      "Cannot register an ephemeral session. Only sessions persisted to a file can be opened remotely.",
      "error",
    );
    return;
  }

  const workspace = process.env.WORKSPACE;
  if (!workspace) {
    ctx.ui.notify(
      "WORKSPACE is not set; the session cannot be registered.",
      "error",
    );
    return;
  }

  let project: string;
  try {
    project = relativeProject(ctx.cwd, workspace);
  } catch (error) {
    ctx.ui.notify(
      error instanceof Error ? error.message : "Invalid project directory.",
      "error",
    );
    return;
  }

  const name = args.trim() || basename(ctx.cwd);

  let response: Response;
  try {
    response = await fetchImpl(`${webUrl}/api/sessions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        name,
        relative_project: project,
        session_file: sessionFile,
        pi_session_id: ctx.sessionManager.getSessionId(),
      }),
    });
  } catch {
    ctx.ui.notify(
      `Could not reach the Matato web app at ${webUrl}. Is it running?`,
      "error",
    );
    return;
  }

  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as ErrorResponse;
    ctx.ui.notify(registrationError(response.status, body), "error");
    return;
  }

  const body = (await response.json()) as RegistrationResponse;
  ctx.ui.notify(
    `Registered remote session "${name}". Open it at ${webUrl}/sessions/${body.session.id}`,
    "info",
  );
}

export default function (pi: ExtensionAPI): void {
  pi.registerCommand("remote", {
    description:
      "Register this session in the Matato web app to open it from another device. Usage: /remote [name]",
    handler: async (args, ctx: ExtensionCommandContext) =>
      registerRemoteSession(args, ctx),
  });
}
