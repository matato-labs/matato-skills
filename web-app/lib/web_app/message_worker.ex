defmodule WebApp.MessageWorker do
  use GenServer

  alias WebApp.{AgentSession, Bots, Messages, RemoteRegistry}

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
         :ok <- RemoteRegistry.open(bot.background_remote_session_id, Bots.identity_for(bot)) do
      deliver_to_bot(bot, message)
    else
      _ -> :failed
    end
  catch
    :exit, _reason -> :failed
  end

  defp deliver_to_bot(bot, message) do
    session_id = bot.background_remote_session_id

    cond do
      AgentSession.snapshot(session_id).status in @busy_statuses ->
        :pending

      AgentSession.claim(session_id, self()) != :owner ->
        :pending

      true ->
        try do
          if AgentSession.owner_command(session_id, self(), command(bot, message)) == :ok,
            do: :sent,
            else: :failed
        after
          AgentSession.release(session_id, self())
        end
    end
  catch
    :exit, _reason -> :failed
  end

  defp command(bot, message) do
    %{
      "type" => "prompt",
      "message" =>
        "You are #{bot.name}, #{bot.role}. #{bot.description}\n\nInternal #{message.kind} from #{message.sender_type}:\n#{message.content}"
    }
  end
end
