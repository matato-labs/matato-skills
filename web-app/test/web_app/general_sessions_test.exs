defmodule WebApp.Sessions.GeneralTest do
  use WebAppWeb.ConnCase, async: false

  alias WebApp.Sessions
  alias WebApp.Sessions.{Agent, Registry, Store, Workspace}

  setup do
    root = Path.join(System.tmp_dir!(), "general-#{System.unique_integer([:positive])}")
    config = Path.join(root, "config")
    executable = Path.join(root, "pi")
    File.mkdir_p!(root)

    File.write!(executable, """
    #!/usr/bin/env python3
    import json, os, sys
    with open(#{inspect(Path.join(root, "cwd"))}, "w") as file:
      file.write(os.getcwd())
    session = sys.argv[sys.argv.index("--session") + 1] if "--session" in sys.argv else None
    messages = []
    if session:
      with open(session) as history:
        messages = [entry["message"] for entry in map(json.loads, history) if entry.get("type") == "message"]
    for line in sys.stdin:
      command = json.loads(line)
      data = {"model": None, "isStreaming": False, "isCompacting": False, "sessionFile": session, "sessionId": "pi-general"} if command["type"] == "get_state" else {"messages": messages} if command["type"] == "get_messages" else {"commands": []}
      print(json.dumps({"id": command["id"], "type": "response", "command": command["type"], "success": True, "data": data}), flush=True)
    """)

    File.chmod!(executable, 0o755)
    old_path = System.fetch_env!("PATH")
    old_config = Application.fetch_env!(:web_app, :automation_storage_path)
    System.put_env("PATH", "#{root}:#{old_path}")
    Application.put_env(:web_app, :automation_storage_path, config)

    on_exit(fn ->
      Store.list()
      |> Enum.filter(&(&1["project"] == config))
      |> Enum.each(fn session ->
        if Agent.whereis(session["id"]), do: Agent.stop(session["id"])
        Store.delete(session["id"])
      end)

      System.put_env("PATH", old_path)
      Application.put_env(:web_app, :automation_storage_path, old_config)
      File.rm_rf!(root)
    end)

    %{config: config, root: root}
  end

  test "creates, catalogs, and reopens general sessions outside WORKSPACE", context do
    assert {:ok, id} = Sessions.create_general()

    assert %{"name" => "New session", "source" => "general", "relative_project" => "."} =
             metadata = Sessions.get(id)

    assert metadata["project"] == context.config
    assert File.read!(Path.join(context.root, "cwd")) == context.config
    assert [%{id: ^id, source: "general"}] = Sessions.general_sessions(Sessions.list())
    assert [] = Sessions.workspace_groups([metadata])

    GenServer.cast(Registry, {:prompt, id, "Plan the next release"})
    _ = :sys.get_state(Registry)
    assert %{"name" => "Plan the next release"} = Sessions.get(id)
    assert :ok = Sessions.stop(id)
    assert :ok = Sessions.open(id)
    assert :ok = Sessions.stop(id)
    assert :ok = Sessions.delete(id)
  end

  test "creates a general session through the sessions API when project is omitted", %{
    conn: conn,
    config: config
  } do
    conn = post(conn, "/api/sessions", %{})

    assert %{"session" => %{"id" => id, "source" => "general", "project" => ^config}} =
             json_response(conn, 201)

    assert :ok = Sessions.stop(id)
    assert :ok = Sessions.delete(id)
  end

  test "historical workspace-root sessions remain reopenable without becoming general" do
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    root = Workspace.root()
    file = Path.join(Application.fetch_env!(:web_app, :session_dir), "#{id}.jsonl")
    File.mkdir_p!(Path.dirname(file))
    message = %{"role" => "user", "content" => "Historical conversation", "timestamp" => 1}

    content =
      Jason.encode!(%{type: "session", id: id, cwd: root}) <>
        "\n" <>
        Jason.encode!(%{type: "message", id: "entry", message: message}) <> "\n"

    File.write!(file, content)

    assert {:ok, _session} =
             Store.create(%{
               id: id,
               name: "Old bot conversation",
               project_path: root,
               relative_project: ".",
               source: "bot_chat",
               session_file: file,
               status: "stopped"
             })

    on_exit(fn ->
      if Agent.whereis(id), do: Agent.stop(id)
      Store.delete(id)
      File.rm(file)
    end)

    assert {:ok, %{"project" => ^root, "name" => "Old bot conversation"}} =
             Store.get(id) |> Store.validate_metadata()

    assert [%{sessions: [%{id: ^id}]}] = Sessions.workspace_groups([Store.get(id)])
    assert [] = Sessions.general_sessions([Store.get(id)])
    assert :ok = Sessions.open(id)
    assert Sessions.snapshot(id).messages == [message]
    assert :ok = Sessions.stop(id)
    assert :ok = Sessions.open(id)
    assert Sessions.snapshot(id).messages == [message]
    assert Sessions.get(id)["session_file"] == file
    assert File.read!(file) == content
    assert :ok = Sessions.stop(id)
  end

  test "automation transcript files are allowed only for automation sources", %{config: config} do
    path = Path.join(config, "sessions/automations/old.jsonl")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "{}\n")

    assert {:ok, ^path} = Store.validate_session_file(path, "automation")
    assert {:error, "Invalid session path"} = Store.validate_session_file(path, "general")
    assert {:error, "Invalid session path"} = Store.validate_session_file(path)
  end

  test "rejects forged general metadata and keeps workspace paths restricted", context do
    assert {:ok, id} = Sessions.create_general()
    metadata = Store.get(id)

    assert {:error, "Invalid session metadata"} =
             Store.validate_metadata(%{metadata | "project" => Workspace.root()})

    assert {:error, "Invalid session metadata"} =
             Store.validate_metadata(%{metadata | "relative_project" => "../"})

    assert_raise ArgumentError, fn -> Workspace.resolve(context.config) end
    assert :ok = Sessions.stop(id)
    assert :ok = Sessions.delete(id)
  end
end
