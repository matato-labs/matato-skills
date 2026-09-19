defmodule WebApp.Bots do
  use Boundary, top_level?: true, deps: [WebApp.Data, WebApp.Sessions], exports: []

  import Ecto.Query

  alias WebApp.Data.Repo
  alias WebApp.Sessions
  alias WebApp.Bots.Bot

  def list, do: Repo.all(from(bot in Bot, order_by: [asc: bot.inserted_at]))
  def get(nil), do: nil
  def get(id), do: Repo.get(Bot, id)
  def name(id), do: with(%Bot{name: name} <- get(id), do: name)

  def identity(id) do
    with %Bot{} = bot <- get(id), do: identity_for(bot)
  end

  @collaboration_instructions """
  You can collaborate with other bots through the web API. List bots with `GET /api/bots` to discover their names and IDs (find your own ID by matching your name), then send a message with `POST /api/messages` using `receiver_bot_id`, `sender_id` (your bot ID), `kind`, and `content`. Delivery is asynchronous: your message is queued and appears as a normal prompt in the receiver's chat session once that session is free. Messages from other bots arrive as `Internal <kind> from <sender>:` prompts.
  """

  def identity_for(%Bot{} = bot),
    do: "You are #{bot.name}, #{bot.role}. #{bot.description}\n\n#{@collaboration_instructions}"

  def identity_for_session(session_id) do
    with %Bot{} = bot <-
           Repo.one(
             from(bot in Bot,
               where:
                 bot.chat_remote_session_id == ^session_id or
                   bot.background_remote_session_id == ^session_id
             )
           ) do
      identity_for(bot)
    end
  end

  def create(attributes) do
    with {:ok, profile} <- validate_profile(attributes),
         {:ok, chat_id} <- create_chat(profile),
         {:ok, background_id} <- create_background(profile, chat_id),
         {:ok, bot} <- insert(profile, chat_id, background_id) do
      notify()
      {:ok, bot}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def update(id, attributes) do
    with %Bot{} = bot <- get(id),
         {:ok, bot} <- bot |> Bot.profile_changeset(attributes) |> Repo.update() do
      notify()
      {:ok, bot}
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(id) do
    case get(id) do
      nil -> {:error, :not_found}
      bot -> delete_bot_sessions(bot)
    end
  end

  def subscribe, do: Phoenix.PubSub.subscribe(WebApp.PubSub, "bots")

  defp validate_profile(attributes) do
    case Bot.profile_changeset(%Bot{}, attributes) |> Ecto.Changeset.apply_action(:insert) do
      {:ok, profile} -> {:ok, profile}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp create_chat(profile) do
    Sessions.create(".", %{
      name: profile.name,
      source: "bot_chat",
      identity: identity_for(profile)
    })
  end

  defp create_background(profile, chat_id) do
    case Sessions.create(".", %{
           name: "#{profile.name} background",
           source: "bot_background",
           identity: identity_for(profile)
         }) do
      {:ok, background_id} ->
        {:ok, background_id}

      {:error, reason} ->
        delete_remote_session(chat_id)
        {:error, reason}
    end
  end

  defp insert(profile, chat_id, background_id) do
    case Bot.changeset(profile, %{
           chat_remote_session_id: chat_id,
           background_remote_session_id: background_id
         })
         |> Repo.insert() do
      {:ok, bot} ->
        {:ok, bot}

      {:error, reason} ->
        delete_remote_session(chat_id)
        delete_remote_session(background_id)
        {:error, reason}
    end
  end

  defp delete_bot_sessions(bot) do
    with :ok <- delete_existing_remote_session(bot.chat_remote_session_id),
         :ok <- delete_existing_remote_session(bot.background_remote_session_id),
         {:ok, _bot} <- Repo.delete(bot) do
      notify()
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_existing_remote_session(id) do
    case Sessions.delete(id) do
      :ok -> :ok
      {:error, "Session not found"} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_remote_session(id) do
    case Sessions.delete(id) do
      :ok -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp notify, do: Phoenix.PubSub.broadcast(WebApp.PubSub, "bots", :changed)
end
