defmodule WebApp.AgentSessionTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias WebApp.{AgentFanout, AgentSession}

  setup do
    root = Path.join(System.tmp_dir!(), "agent-session-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    executable = Path.join(root, "fakepi")

    File.write!(executable, """
    #!/usr/bin/env python3
    import json, sys
    with open("#{root}/arguments.json", "w") as file:
      json.dump(sys.argv[1:], file)
    for line in sys.stdin:
      command = json.loads(line)
      id = command.get("id")
      type = command["type"]
      if type == "get_state":
        data = {"model": None, "isStreaming": False, "isCompacting": False, "sessionFile": "#{root}/session.jsonl", "sessionId": "pi-1"}
        print(json.dumps({"id": id, "type": "response", "command": type, "success": True, "data": data}), flush=True)
      elif type == "get_messages":
        print(json.dumps({"id": id, "type": "response", "command": type, "success": True, "data": {"messages": []}}), flush=True)
      elif type == "reject":
        print(json.dumps({"id": id, "type": "response", "command": type, "success": False, "error": "rejected"}), flush=True)
      elif type == "dialog":
        print(json.dumps({"id": id, "type": "response", "command": type, "success": True}), flush=True)
        print(json.dumps({"type": "extension_ui_request", "id": "dialog-1", "method": "confirm", "title": "Continue?"}), flush=True)
      elif type == "bad_record":
        print("[]", flush=True)
      elif type == "extension_ui_response":
        pass
      else:
        print(json.dumps({"id": id, "type": "response", "command": type, "success": True}), flush=True)
    """)

    File.chmod!(executable, 0o700)
    File.touch!(Path.join(root, "session.jsonl"))

    on_exit(fn -> File.rm_rf!(root) end)
    %{executable: executable, root: root}
  end

  test "always starts Pi with full permissions", context do
    id = "test-#{System.unique_integer([:positive])}"

    start_supervised!(
      {AgentSession,
       id: id,
       name: "test",
       project: context.root,
       executable: context.executable,
       interrupted: false},
      id: id
    )

    assert :ok = AgentSession.await_ready(id)
    arguments = context.root |> Path.join("arguments.json") |> File.read!() |> Jason.decode!()
    assert "--approve" in arguments
    refute "--no-approve" in arguments
  end

  test "discovers in order, keeps rejection nonfatal, and enforces dialog ownership", context do
    id = "test-#{System.unique_integer([:positive])}"
    AgentFanout.subscribe(id)

    start_supervised!(
      {AgentSession,
       id: id,
       name: "test",
       project: context.root,
       executable: context.executable,
       interrupted: false}
    )

    assert_receive {:agent_snapshot, %{status: :settled}}, 2_000
    assert {:error, "rejected"} = AgentSession.command(id, %{"type" => "reject"})
    assert AgentSession.snapshot(id).status == :settled

    assert :owner = AgentSession.claim(id, self())
    parent = self()
    observer = spawn(fn -> send(parent, {:observer, AgentSession.claim(id, self())}) end)
    assert_receive {:observer, :observer}
    assert is_pid(observer)

    assert {:error, "Only the interaction owner can control this session"} =
             AgentSession.owner_command(id, observer, %{"type" => "prompt", "message" => "no"})

    assert :ok = AgentSession.command(id, %{"type" => "dialog"})
    assert_receive {:agent_snapshot, %{status: :waiting_for_input, dialog: dialog}}, 2_000

    assert {:error, "Only the interaction owner can answer"} =
             AgentSession.respond(id, observer, %{
               "type" => "extension_ui_response",
               "id" => dialog["id"],
               "confirmed" => true
             })

    assert :ok =
             AgentSession.respond(id, self(), %{
               "type" => "extension_ui_response",
               "id" => dialog["id"],
               "confirmed" => true
             })
  end

  test "handles Pi exiting before the first command", context do
    executable = Path.join(context.root, "exit-immediately")
    File.write!(executable, "#!/bin/sh\nexit 1\n")
    File.chmod!(executable, 0o700)
    id = "test-#{System.unique_integer([:positive])}"

    log =
      capture_log(fn ->
        start_supervised!(
          {AgentSession,
           id: id, name: "test", project: context.root, executable: executable, interrupted: false}
        )

        assert {:error, _reason} = AgentSession.await_ready(id)
      end)

    refute log =~ "GenServer {WebApp.ProcessRegistry"
  end

  test "quarantines a child after an invalid protocol record", context do
    id = "test-#{System.unique_integer([:positive])}"

    pid =
      start_supervised!(
        {AgentSession,
         id: id,
         name: "test",
         project: context.root,
         executable: context.executable,
         interrupted: false}
      )

    assert :ok = AgentSession.await_ready(id)
    monitor = Process.monitor(pid)

    log =
      capture_log(fn ->
        assert {:error, "Pi emitted a non-object protocol record"} =
                 AgentSession.command(id, %{"type" => "bad_record"})

        assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 2_000
      end)

    assert log =~ "Pi RPC protocol failure"
  end
end
