defmodule WebApp.AgentFanout do
  @moduledoc "In-process event delivery for connected LiveViews."

  def subscribe(session_id) do
    case Registry.register(WebApp.SubscriberRegistry, session_id, nil) do
      {:ok, _owner} -> :ok
      {:error, {:already_registered, _pid}} -> :ok
    end
  end

  def unsubscribe(session_id), do: Registry.unregister(WebApp.SubscriberRegistry, session_id)

  def broadcast(session_id, {:agent_update, session_id, _sequence, _update} = message) do
    Registry.dispatch(WebApp.SubscriberRegistry, session_id, fn entries ->
      Enum.each(entries, fn {pid, _value} -> send(pid, message) end)
    end)
  end
end
