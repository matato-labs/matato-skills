const apiBase = "https://discord.com/api/v10";
type DiscordChannel = { id: string; guild_id?: string };
type DiscordSendBody = {
  content: string;
  allowed_mentions: { parse: Array<never>; replied_user: false };
  message_reference?: {
    message_id: string;
    channel_id: string;
    fail_if_not_exists: true;
  };
};
type DiscordConfig = {
  token: string;
  guildId: string;
  channelIds: Array<string>;
};

const snowflake = (value: string): boolean => /^\d{1,20}$/.test(value);

export function discordConfig(): DiscordConfig {
  const token = process.env.DISCORD_BOT_TOKEN?.trim();
  const guildId = process.env.DISCORD_GUILD_ID?.trim();
  const channelIds =
    process.env.DISCORD_CHANNEL_IDS?.split(",").map((id) => id.trim()) ?? [];
  if (!token) throw new Error("DISCORD_BOT_TOKEN is required");
  if (!guildId || !snowflake(guildId))
    throw new Error("DISCORD_GUILD_ID must be a server ID");
  if (!channelIds.length || channelIds.some((id) => !snowflake(id)))
    throw new Error(
      "DISCORD_CHANNEL_IDS must contain comma-separated channel IDs",
    );
  return { token, guildId, channelIds: [...new Set(channelIds)] };
}

async function requestDiscord<T>(
  config: DiscordConfig,
  path: string,
  body?: DiscordSendBody,
): Promise<T> {
  // Fetch failures can contain the request URL or headers. Never propagate them.
  try {
    const response = await fetch(`${apiBase}${path}`, {
      method: body ? "POST" : "GET",
      signal: AbortSignal.timeout(15000),
      headers: {
        Authorization: `Bot ${config.token}`,
        ...(body ? { "content-type": "application/json" } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    if (!response.ok) throw new Error("Discord HTTP request failed");
    return (await response.json()) as T;
  } catch (error) {
    if (
      body &&
      error instanceof Error &&
      ["TimeoutError", "AbortError"].includes(error.name)
    )
      // eslint-disable-next-line preserve-caught-error -- Transport errors can contain credentials.
      throw new Error(
        "Discord send timed out; delivery is uncertain. Check the destination before retrying.",
      );
    // Intentionally discard fetch/JSON errors: they may embed credentials or URLs.
    // eslint-disable-next-line preserve-caught-error -- Transport errors can contain credentials.
    throw new Error("Discord request failed");
  }
}

async function allowedChannel(
  config: DiscordConfig,
  channelId: string,
): Promise<void> {
  const channel = await requestDiscord<DiscordChannel>(
    config,
    `/channels/${channelId}`,
  );
  if (channel.id !== channelId || channel.guild_id !== config.guildId)
    throw new Error("Discord channel is not in the configured server");
}

export async function sendDiscordMessage(input: {
  channelId: string;
  text: string;
  replyTo?: string;
}): Promise<void> {
  const config = discordConfig();
  if (!input.text.trim() || input.text.length > 2000)
    throw new Error("Discord text must be 1–2000 characters");
  if (input.replyTo !== undefined && !snowflake(input.replyTo))
    throw new Error("Invalid Discord reply ID");
  if (!config.channelIds.includes(input.channelId))
    throw new Error("Discord channel is not allowlisted");
  await allowedChannel(config, input.channelId);
  await requestDiscord<{ id: string }>(
    config,
    `/channels/${input.channelId}/messages`,
    {
      content: input.text,
      allowed_mentions: { parse: [], replied_user: false },
      ...(input.replyTo
        ? {
            message_reference: {
              message_id: input.replyTo,
              channel_id: input.channelId,
              fail_if_not_exists: true,
            },
          }
        : {}),
    },
  );
}
