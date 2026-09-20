defmodule WebApp.Sessions.AgentTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias WebApp.Sessions.{Agent, Fanout}

  setup do
    root = Path.join(System.tmp_dir!(), "agent-session-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    executable = Path.join(root, "fakepi")

    File.write!(executable, """
    #!/usr/bin/env python3
    import json, os, sys
    with open("#{root}/arguments.json", "w") as file:
      json.dump(sys.argv[1:], file)
    for line in sys.stdin:
      command = json.loads(line)
      with open("#{root}/commands.jsonl", "a") as file:
        file.write(json.dumps(command) + "\\n")
      id = command.get("id")
      type = command["type"]
      if type == "get_state":
        data = [] if os.environ.get("MALFORMED_STATE") else {"model": None, "isStreaming": False, "isCompacting": False, "sessionFile": "#{root}/session.jsonl", "sessionId": "pi-1"}
        print(json.dumps({"id": id, "type": "response", "command": type, "success": True, "data": data}), flush=True)
      elif type == "get_messages":
        messages = {} if os.environ.get("MALFORMED_MESSAGES") else []
        print(json.dumps({"id": id, "type": "response", "command": type, "success": True, "data": {"messages": messages}}), flush=True)
      elif type == "get_commands":
        if os.environ.get("REJECT_COMMANDS"):
          print(json.dumps({"id": id, "type": "response", "command": type, "success": False, "error": "unavailable"}), flush=True)
        else:
          data = {"commands": [{"name": "plan", "description": "Plan the work", "source": "prompt", "sourceInfo": {"path": "#{root}/.pi/prompts/plan.md", "scope": "project"}}, {"name": "skill:review", "description": "Review the work", "source": "skill", "sourceInfo": {"path": "#{root}/.pi/skills/review/SKILL.md", "scope": "project"}}]}
          print(json.dumps({"id": id, "type": "response", "command": type, "success": True, "data": data}), flush=True)
      elif type == "reject":
        print(json.dumps({"id": id, "type": "response", "command": type, "success": False, "error": "rejected"}), flush=True)
      elif type == "dialog":
        print(json.dumps({"id": id, "type": "response", "command": type, "success": True}), flush=True)
        print(json.dumps({"type": "extension_ui_request", "id": "dialog-1", "method": "confirm", "title": "Continue?"}), flush=True)
      elif type == "large_event":
        print(json.dumps({"type": "message_update", "assistantMessageEvent": {"type": "text_delta", "contentIndex": 0, "delta": "x" * 30000}}), flush=True)
        print(json.dumps({"id": id, "type": "response", "command": type, "success": True}), flush=True)
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

  test "loads only Matato and project .pi command resources", context do
    File.mkdir_p!(Path.join(context.root, ".pi/skills"))
    File.mkdir_p!(Path.join(context.root, ".pi/prompts"))
    File.mkdir_p!(Path.join(context.root, ".agents/skills"))
    id = "test-#{System.unique_integer([:positive])}"

    start_supervised!(
      {Agent,
       id: id,
       name: "test",
       project: context.root,
       executable: context.executable,
       identity: "You are Test, tester. Test agent sessions.",
       interrupted: false},
      id: id
    )

    assert :ok = Agent.await_ready(id)
    arguments = context.root |> Path.join("arguments.json") |> File.read!() |> Jason.decode!()
    assert "--approve" in arguments
    assert "--extension" in arguments
    assert "--no-extensions" in arguments
    assert Application.fetch_env!(:web_app, :pi_package_root) in arguments
    assert "--no-skills" in arguments
    assert "--no-prompt-templates" in arguments
    assert "--append-system-prompt" in arguments
    assert "You are Test, tester. Test agent sessions." in arguments
    assert Path.join(context.root, ".pi/skills") in arguments
    assert Path.join(context.root, ".pi/prompts") in arguments
    refute Path.join(context.root, ".agents/skills") in arguments
    refute "--no-approve" in arguments
    refute "--session-dir" in arguments
  end

  test "discovers in order, keeps rejection nonfatal, and allows browser dialog responses",
       context do
    id = "test-#{System.unique_integer([:positive])}"
    Fanout.subscribe(id)

    start_supervised!(
      {Agent,
       id: id,
       name: "test",
       project: context.root,
       executable: context.executable,
       interrupted: false}
    )

    assert :ok = Agent.await_ready(id)
    assert_receive {:agent_update, ^id, sequence, {:commands_ready, commands}}, 2_000
    assert sequence > 0
    assert Enum.map(commands, & &1["name"]) == ["plan", "skill:review"]
    assert {:error, "rejected"} = Agent.command(id, %{"type" => "reject"})
    assert Agent.snapshot(id).status == :settled

    assert :owner = Agent.claim(id, self())
    parent = self()
    observer = spawn(fn -> send(parent, {:observer, Agent.claim(id, self())}) end)
    assert_receive {:observer, :observer}
    assert is_pid(observer)

    assert {:error, "Only the interaction owner can control this session"} =
             Agent.owner_command(id, observer, %{"type" => "prompt", "message" => "no"})

    assert :ok = Agent.command(id, %{"type" => "prompt", "message" => "from chat"})
    assert :ok = Agent.command(id, %{"type" => "dialog"})

    assert_receive {:agent_update, ^id, _sequence,
                    {:event,
                     %{"type" => "extension_ui_request", "id" => "dialog-1"} = dialog_event}},
                   2_000

    assert dialog_event["id"] == "dialog-1"
    dialog = Agent.snapshot(id).dialog

    assert {:error, "Only the interaction owner can answer"} =
             Agent.respond(id, observer, %{
               "type" => "extension_ui_response",
               "id" => dialog["id"],
               "confirmed" => true
             })

    caller = self()
    ref = make_ref()

    spawn(fn ->
      send(
        caller,
        {ref,
         Agent.respond(id, %{
           "type" => "extension_ui_response",
           "id" => dialog["id"],
           "confirmed" => true
         })}
      )
    end)

    assert_receive {^ref, :ok}
  end

  test "keeps a session usable when command discovery fails", context do
    id = "test-#{System.unique_integer([:positive])}"
    Fanout.subscribe(id)
    System.put_env("REJECT_COMMANDS", "1")
    on_exit(fn -> System.delete_env("REJECT_COMMANDS") end)

    start_supervised!(
      {Agent,
       id: id,
       name: "test",
       project: context.root,
       executable: context.executable,
       interrupted: false}
    )

    assert :ok = Agent.await_ready(id)

    assert_receive {:agent_update, ^id, _sequence,
                    {:commands_failed, "Command discovery failed: unavailable"}}

    assert Agent.snapshot(id).commands == []
    assert :ok = Agent.command(id, %{"type" => "prompt", "message" => "still works"})
  end

  test "caps event payloads before broadcasting", context do
    id = "test-#{System.unique_integer([:positive])}"
    Fanout.subscribe(id)

    start_supervised!(
      {Agent,
       id: id,
       name: "test",
       project: context.root,
       executable: context.executable,
       interrupted: false}
    )

    assert :ok = Agent.await_ready(id)
    assert :ok = Agent.command(id, %{"type" => "large_event"})

    assert_receive {:agent_update, ^id, _sequence,
                    {:event, %{"assistantMessageEvent" => %{"delta" => delta}}}},
                   2_000

    assert byte_size(delta) == 24_000
  end

  test "returns a canonical snapshot with its update sequence", context do
    id = "test-#{System.unique_integer([:positive])}"

    start_supervised!(
      {Agent,
       id: id,
       name: "test",
       project: context.root,
       executable: context.executable,
       interrupted: false}
    )

    assert :ok = Agent.await_ready(id)

    assert %{sequence: sequence, view: %{status: :settled}} =
             Agent.snapshot_with_sequence(id)

    assert is_integer(sequence)
  end

  test "forwards slash commands unchanged through every submission mode", context do
    id = "test-#{System.unique_integer([:positive])}"

    start_supervised!(
      {Agent,
       id: id,
       name: "test",
       project: context.root,
       executable: context.executable,
       interrupted: false}
    )

    assert :ok = Agent.await_ready(id)
    assert :ok = Agent.command(id, %{"type" => "prompt", "message" => "/plan API work"})

    assert :ok =
             Agent.command(id, %{"type" => "steer", "message" => "/skill:review API work"})

    assert :ok =
             Agent.command(id, %{"type" => "follow_up", "message" => "/plan API work"})

    commands =
      context.root
      |> Path.join("commands.jsonl")
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert Enum.filter(commands, &(&1["type"] in ["prompt", "steer", "follow_up"])) == [
             %{"id" => "#{id}-4", "type" => "prompt", "message" => "/plan API work"},
             %{"id" => "#{id}-5", "type" => "steer", "message" => "/skill:review API work"},
             %{"id" => "#{id}-6", "type" => "follow_up", "message" => "/plan API work"}
           ]
  end

  test "fails startup when Pi returns malformed discovery data", context do
    on_exit(fn ->
      System.delete_env("MALFORMED_STATE")
      System.delete_env("MALFORMED_MESSAGES")
    end)

    for {variable, expected_kind} <- [
          {"MALFORMED_STATE", "state"},
          {"MALFORMED_MESSAGES", "messages"}
        ] do
      System.put_env(variable, "1")
      id = "test-#{System.unique_integer([:positive])}"

      start_supervised!(
        {Agent,
         id: id,
         name: "test",
         project: context.root,
         executable: context.executable,
         interrupted: false},
        id: id
      )

      expected_error = "Pi returned malformed #{expected_kind} discovery data"
      assert {:error, ^expected_error} = Agent.await_ready(id)
      System.delete_env(variable)
    end
  end

  test "handles Pi exiting before the first command", context do
    executable = Path.join(context.root, "exit-immediately")
    File.write!(executable, "#!/bin/sh\nexit 1\n")
    File.chmod!(executable, 0o700)
    id = "test-#{System.unique_integer([:positive])}"

    log =
      capture_log(fn ->
        start_supervised!(
          {Agent,
           id: id, name: "test", project: context.root, executable: executable, interrupted: false}
        )

        assert {:error, _reason} = Agent.await_ready(id)
      end)

    refute log =~ "GenServer {WebApp.Sessions.ProcessRegistry"
  end

  test "quarantines a child after an invalid protocol record", context do
    id = "test-#{System.unique_integer([:positive])}"

    pid =
      start_supervised!(
        {Agent,
         id: id,
         name: "test",
         project: context.root,
         executable: context.executable,
         interrupted: false}
      )

    assert :ok = Agent.await_ready(id)
    monitor = Process.monitor(pid)

    log =
      capture_log(fn ->
        assert {:error, "Pi emitted a non-object protocol record"} =
                 Agent.command(id, %{"type" => "bad_record"})

        assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 2_000
      end)

    assert log =~ "Pi RPC protocol failure"
  end
end
