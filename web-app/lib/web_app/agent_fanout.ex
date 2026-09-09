defmodule WebApp.AgentFanout do
  @moduledoc "Bounded in-process event delivery for connected LiveViews."

  @max_mailbox 100

  def subscribe(session_id) do
    case Registry.register(WebApp.SubscriberRegistry, session_id, nil) do
      {:ok, _owner} -> :ok
      {:error, {:already_registered, _pid}} -> :ok
    end
  end

  def broadcast(session_id, message) do
    Registry.dispatch(WebApp.SubscriberRegistry, session_id, fn entries ->
      Enum.each(entries, fn {pid, _value} -> deliver(pid, message) end)
    end)
  end

  defp deliver(pid, message) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, length} when length < @max_mailbox -> send(pid, message)
      _result -> Process.exit(pid, :kill)
    end
  end
end
