defmodule WebApp.AgentFanoutTest do
  use ExUnit.Case, async: false

  alias WebApp.AgentFanout

  test "does not deliver after a subscriber unsubscribes" do
    session_id = "fanout-#{System.unique_integer([:positive])}"
    assert :ok = AgentFanout.subscribe(session_id)
    assert :ok = AgentFanout.unsubscribe(session_id)

    AgentFanout.broadcast(session_id, {:agent_update, session_id, 1, {:hint, %{}}})

    refute_receive {:agent_update, ^session_id, 1, _update}
  end

  test "delivers every update to a slow subscriber" do
    session_id = "fanout-#{System.unique_integer([:positive])}"
    parent = self()

    pid =
      spawn(fn ->
        AgentFanout.subscribe(session_id)
        send(parent, :subscribed)

        receive do
          :drain -> send(parent, {:messages, Process.info(self(), :messages)})
        end
      end)

    assert_receive :subscribed

    Enum.each(1..200, fn sequence ->
      AgentFanout.broadcast(session_id, {:agent_update, session_id, sequence, {:hint, %{}}})
    end)

    send(pid, :drain)
    assert_receive {:messages, {:messages, messages}}

    assert Enum.count(messages, &match?({:agent_update, ^session_id, _sequence, _update}, &1)) ==
             200
  end
end
