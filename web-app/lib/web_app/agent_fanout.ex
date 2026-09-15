defmodule WebApp.AgentFanout do
  @moduledoc "Bounded in-process event delivery for connected LiveViews."

  @max_mailbox 100

  def subscribe(session_id) do
    case Registry.register(WebApp.SubscriberRegistry, session_id, nil) do
      {:ok, _owner} -> :ok
      {:error, {:already_registered, _pid}} -> :ok
    end
  end

  def unsubscribe(session_id), do: Registry.unregister(WebApp.SubscriberRegistry, session_id)

  def broadcast(session_id, {:agent_update, session_id, sequence, _update} = message) do
    Registry.dispatch(WebApp.SubscriberRegistry, session_id, fn entries ->
      Enum.each(entries, fn {pid, _value} -> deliver(pid, session_id, sequence, message) end)
    end)
  end

  defp deliver(pid, session_id, sequence, message) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, length} when length < @max_mailbox ->
        send(pid, message)

      {:message_queue_len, _length} ->
        case Process.info(pid, :messages) do
          {:messages, messages} ->
            if Enum.any?(messages, &match?({:agent_resync, ^session_id, _sequence}, &1)) do
              :ok
            else
              send(pid, {:agent_resync, session_id, sequence})
            end

          _result ->
            :ok
        end

      _result ->
        :ok
    end
  end
end
