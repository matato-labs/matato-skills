import { expect, test } from "bun:test";

type CommandResult = {
  exitCode: number;
  stderr: string;
  stdout: string;
};

const runCli = async (argumentsList: Array<string>): Promise<CommandResult> => {
  const child = Bun.spawn(
    [process.execPath, "discordCli.ts", ...argumentsList],
    {
      cwd: import.meta.dir,
      env: {
        ...process.env,
        DISCORD_BOT_TOKEN: undefined,
        DISCORD_GUILD_ID: undefined,
        DISCORD_CHANNEL_IDS: undefined,
      },
      stdout: "pipe",
      stderr: "pipe",
    },
  );
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  return { exitCode, stderr, stdout };
};

test("requires confirmation before replying to Discord", async () => {
  const result = await runCli([
    "reply",
    "--channelId",
    "channel-1",
    "--messageId",
    "message-1",
    "--content",
    "Acknowledged",
  ]);

  expect(result).toEqual({
    exitCode: 0,
    stderr: "",
    stdout:
      "Write not sent: confirmation is required.\nDestination: Discord channel channel-1\nReplying to: Discord message message-1\nContent:\nAcknowledged\nAfter the user confirms, rerun this command with --confirm.\n",
  });
});
