defmodule WebApp.AgentFanoutTest do
  use ExUnit.Case, async: false

  alias WebApp.AgentFanout

  test "keeps a slow subscriber alive and requests a resynchronization" do
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
    monitor = Process.monitor(pid)

    Enum.each(1..101, fn sequence ->
      AgentFanout.broadcast(session_id, {:agent_update, session_id, sequence, {:hint, %{}}})
    end)

    refute_receive {:DOWN, ^monitor, :process, ^pid, _reason}
    send(pid, :drain)
    assert_receive {:messages, {:messages, messages}}
    assert Enum.any?(messages, &match?({:agent_resync, ^session_id, _sequence}, &1))
  end
end
