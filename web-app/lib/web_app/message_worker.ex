defmodule WebApp.MessageWorker do
  use GenServer

  alias WebApp.{AgentSession, Bots, Messages, RemoteRegistry}
  alias WebApp.Messages.Message

  @busy_statuses [:working, :waiting_for_input, :retrying, :compacting]

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def deliver_pending, do: GenServer.call(__MODULE__, :deliver_pending, :infinity)

  @impl true
  def init(:ok) do
    Messages.reset_processing()
    {:ok, :ready}
  end

  @impl true
  def handle_call(:deliver_pending, _from, state), do: {:reply, deliver([]), state}

  defp deliver(deferred_ids) do
    case Messages.claim_pending(deferred_ids) do
      nil ->
        :ok

      message ->
        case delivery_status(message) do
          :pending ->
            :ok = Messages.requeue(message)
            deliver([message.id | deferred_ids])

          status ->
            :ok = Messages.finish(message, Atom.to_string(status))
            deliver(deferred_ids)
        end
    end
  end

  defp delivery_status(message) do
    with bot when not is_nil(bot) <- Bots.get(message.receiver_bot_id),
         session_id <- session_id_for(bot, message),
         :ok <- RemoteRegistry.open(session_id, Bots.identity_for(bot)) do
      deliver_to_bot(session_id, message)
    else
      _ -> :failed
    end
  catch
    :exit, _reason -> :failed
  end

  defp session_id_for(bot, %Message{sender_type: "bot"}), do: bot.chat_remote_session_id
  defp session_id_for(bot, _message), do: bot.background_remote_session_id

  defp deliver_to_bot(session_id, message) do
    cond do
      AgentSession.snapshot(session_id).status in @busy_statuses ->
        :pending

      AgentSession.claim(session_id, self()) != :owner ->
        :pending

      true ->
        try do
          if AgentSession.owner_command(session_id, self(), command(message)) == :ok,
            do: :sent,
            else: :failed
        after
          AgentSession.release(session_id, self())
        end
    end
  catch
    :exit, _reason -> :failed
  end

  defp command(message) do
    %{
      "type" => "prompt",
      "message" => "Internal #{message.kind} from #{sender_name(message)}:\n#{message.content}"
    }
  end

  defp sender_name(%Message{sender_type: "bot", sender_id: sender_id}), do: Bots.name(sender_id)
  defp sender_name(message), do: message.sender_type
end
