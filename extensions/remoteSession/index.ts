import { spawn } from "node:child_process";
import { isAbsolute, basename, posix, relative, resolve, sep } from "node:path";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

const webUrl = process.env.MATATO_SKILLS_WEB_URL ?? "http://localhost:4000";
const remoteSessionDirectory = ".pi/agent/sessions";
const sshHostPattern = /^[A-Za-z0-9][A-Za-z0-9.-]*$/;

type SessionInfo = {
  getSessionFile(): string | undefined;
  getSessionId(): string;
};

type CommandResult = { stdout: string; stderr: string };

export type RemoteSessionContext = {
  cwd: string;
  sessionManager: SessionInfo;
  ui: { notify(message: string, type?: "info" | "warning" | "error"): void };
};

export type FetchLike = (url: string, init?: RequestInit) => Promise<Response>;
export type CommandRunner = (
  command: string,
  args: Array<string>,
) => Promise<CommandResult>;

type RegistrationResponse = { session: { id: string } };
type ErrorResponse = { error?: string; errors?: Record<string, Array<string>> };
type RemoteCommand = { name: string; host?: string };
type SessionRegistration = {
  name: string;
  project: string;
  sessionFile: string;
  sessionId: string;
};

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

export function remoteCommand(args: string): RemoteCommand {
  const hostOption = /(?:^|\s)--host(?:\s+(\S+))?\s*$/.exec(args);
  const hasHostOption = /(?:^|\s)--host(?:\s|$)/.test(args);
  if (!hostOption) {
    if (hasHostOption)
      throw new Error(
        "Invalid --host syntax. Use /remote [name] --host <sshHost>.",
      );
    return { name: args.trim() };
  }
  if (/(?:^|\s)--host(?:\s|$)/.test(args.slice(0, hostOption.index)))
    throw new Error(
      "Invalid --host syntax. Use /remote [name] --host <sshHost>.",
    );

  const host = hostOption[1];
  if (!host || !sshHostPattern.test(host))
    throw new Error(
      "Invalid SSH host. Use an SSH config host name, for example: --host piServer.",
    );

  return { name: args.slice(0, hostOption.index).trim(), host };
}

export function runCommand(
  command: string,
  args: Array<string>,
): Promise<CommandResult> {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {
      shell: false,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk: Buffer) => (stdout += chunk.toString()));
    child.stderr.on("data", (chunk: Buffer) => (stderr += chunk.toString()));
    child.once("error", reject);
    child.once("close", (code) => {
      if (code === 0) return resolvePromise({ stdout, stderr });
      reject(
        new Error(stderr.trim() || `${command} exited with status ${code}.`),
      );
    });
  });
}

async function copySessionFile(
  host: string,
  sessionFile: string,
  commandRunner: CommandRunner,
): Promise<string> {
  let homeDirectory: string;
  try {
    const result = await commandRunner("ssh", [
      host,
      `mkdir -p ${remoteSessionDirectory} && pwd`,
    ]);
    homeDirectory = result.stdout.trim();
  } catch (error) {
    const detail = error instanceof Error ? `: ${error.message}` : "";
    throw new Error(
      `Could not prepare Pi session storage on ${host} via SSH${detail}`,
      { cause: error },
    );
  }

  const remoteFile = posix.join(
    homeDirectory,
    remoteSessionDirectory,
    basename(sessionFile),
  );
  try {
    await commandRunner("scp", [
      sessionFile,
      `${host}:${remoteSessionDirectory}/${basename(sessionFile)}`,
    ]);
  } catch (error) {
    const detail = error instanceof Error ? `: ${error.message}` : "";
    throw new Error(
      `Could not copy the session file to ${host} via SCP${detail}`,
      { cause: error },
    );
  }

  return remoteFile;
}

async function registerSession(
  registration: SessionRegistration,
  targetWebUrl: string,
  fetchImpl: FetchLike,
): Promise<RegistrationResponse> {
  const response = await fetchImpl(`${targetWebUrl}/api/sessions`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      name: registration.name,
      relative_project: registration.project,
      session_file: registration.sessionFile,
      pi_session_id: registration.sessionId,
    }),
  });

  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as ErrorResponse;
    throw new Error(registrationError(response.status, body));
  }

  return (await response.json()) as RegistrationResponse;
}

function sessionRegistration(
  name: string,
  ctx: RemoteSessionContext,
): Omit<SessionRegistration, "sessionId"> | undefined {
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

  return {
    name,
    project,
    sessionFile,
  };
}

type RegistrationTarget = { sessionFile: string; webUrl: string };

async function registrationTarget(
  { host, sessionFile }: { host?: string; sessionFile: string },
  ctx: RemoteSessionContext,
  commandRunner: CommandRunner,
): Promise<RegistrationTarget | undefined> {
  if (!host) return { sessionFile, webUrl };
  try {
    return {
      sessionFile: await copySessionFile(host, sessionFile, commandRunner),
      webUrl: `http://${host}:4000`,
    };
  } catch (error) {
    ctx.ui.notify(
      error instanceof Error ? error.message : "Could not copy session file.",
      "error",
    );
    return undefined;
  }
}

async function submitRegistration(
  {
    webUrl: targetWebUrl,
    ...registration
  }: Omit<SessionRegistration, "sessionId"> & RegistrationTarget,
  ctx: RemoteSessionContext,
  fetchImpl: FetchLike,
): Promise<void> {
  let body: RegistrationResponse;
  try {
    body = await registerSession(
      { ...registration, sessionId: ctx.sessionManager.getSessionId() },
      targetWebUrl,
      fetchImpl,
    );
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : `Could not reach the Matato web app at ${targetWebUrl}. Is it running?`;
    ctx.ui.notify(
      message.startsWith("Registration failed:") ||
        message.startsWith("Registration failed with status")
        ? message
        : `Could not reach the Matato web app at ${targetWebUrl}. Is it running?`,
      "error",
    );
    return;
  }

  ctx.ui.notify(
    `Registered remote session "${registration.name}". Open it at ${targetWebUrl}/sessions/${body.session.id}`,
    "info",
  );
}

export async function registerRemoteSession(
  args: string,
  ctx: RemoteSessionContext,
  {
    fetchImpl = fetch,
    commandRunner = runCommand,
  }: { fetchImpl?: FetchLike; commandRunner?: CommandRunner } = {},
): Promise<void> {
  let command: RemoteCommand;
  try {
    command = remoteCommand(args);
  } catch (error) {
    ctx.ui.notify(
      error instanceof Error ? error.message : "Invalid command.",
      "error",
    );
    return;
  }

  const registration = sessionRegistration(
    command.name || basename(ctx.cwd),
    ctx,
  );
  if (!registration) return;
  const target = await registrationTarget(
    { host: command.host, sessionFile: registration.sessionFile },
    ctx,
    commandRunner,
  );
  if (!target) return;
  await submitRegistration(
    {
      ...registration,
      ...target,
    },
    ctx,
    fetchImpl,
  );
}

export default function (pi: ExtensionAPI): void {
  pi.registerCommand("remote", {
    description:
      "Register this session in the Matato web app. Usage: /remote [name] [--host <sshHost>]",
    handler: async (args, ctx: ExtensionCommandContext) =>
      registerRemoteSession(args, ctx),
  });
}
