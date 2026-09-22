defmodule WebAppWeb.SessionControllerTest do
  use WebAppWeb.ConnCase, async: false

  alias WebApp.Sessions.{Agent, Registry, Store, Workspace}

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "matato-sessions-#{System.unique_integer([:positive])}")

    project_dir =
      Path.join(Workspace.root(), "session-controller-#{System.unique_integer([:positive])}")

    File.mkdir_p!(session_dir)
    File.mkdir_p!(project_dir)
    previous = Application.fetch_env!(:web_app, :session_dir)
    Application.put_env(:web_app, :session_dir, session_dir)
    Registry.subscribe()

    on_exit(fn ->
      Application.put_env(:web_app, :session_dir, previous)

      Store.list()
      |> Enum.filter(&String.starts_with?(&1["project"], project_dir <> "/"))
      |> Enum.each(&Store.delete(&1["id"]))

      File.rm_rf!(session_dir)
      File.rm_rf!(project_dir)
    end)

    %{session_dir: session_dir, project_dir: project_dir}
  end

  test "registers a terminal session as a stopped extension session", %{
    conn: conn,
    session_dir: session_dir,
    project_dir: project_dir
  } do
    project = create_project(project_dir, "alpha")
    relative_project = Path.relative_to(project, Workspace.root())
    session_file = create_session_file(session_dir)

    conn =
      post(conn, "/api/sessions", %{
        "name" => "My session",
        "relative_project" => relative_project,
        "session_file" => session_file,
        "pi_session_id" => "pi-123"
      })

    assert %{"session" => session} = json_response(conn, 201)
    assert session["name"] == "My session"
    assert session["project"] == project
    assert session["relative_project"] == relative_project
    assert session["session_file"] == session_file
    assert session["pi_session_id"] == "pi-123"
    assert session["source"] == "extension"
    assert session["status"] == "stopped"

    assert_received :changed
    refute Agent.whereis(session["id"])
  end

  test "defaults the session name to the project directory name", %{
    conn: conn,
    session_dir: session_dir,
    project_dir: project_dir
  } do
    project = create_project(project_dir, "beta")

    conn =
      post(conn, "/api/sessions", %{
        "relative_project" => Path.relative_to(project, Workspace.root()),
        "session_file" => create_session_file(session_dir),
        "pi_session_id" => "pi-123"
      })

    assert %{"session" => %{"name" => "beta"}} = json_response(conn, 201)
  end

  test "updates the existing record when the session file is already registered", %{
    conn: conn,
    session_dir: session_dir,
    project_dir: project_dir
  } do
    project = create_project(project_dir, "alpha")
    session_file = create_session_file(session_dir)

    attributes = %{
      "name" => "First",
      "relative_project" => Path.relative_to(project, Workspace.root()),
      "session_file" => session_file,
      "pi_session_id" => "pi-123"
    }

    assert %{"session" => %{"id" => id}} =
             conn |> post("/api/sessions", attributes) |> json_response(201)

    assert %{"session" => session} =
             build_conn()
             |> post("/api/sessions", %{attributes | "name" => "Renamed"})
             |> json_response(201)

    assert session["id"] == id
    assert session["name"] == "Renamed"
    assert session["source"] == "extension"
    assert session["status"] == "stopped"
    assert length(Store.list()) == 1
  end

  test "deduplicates simultaneous registrations by session file", %{
    session_dir: session_dir,
    project_dir: project_dir
  } do
    project = create_project(project_dir, "alpha")

    attributes = %{
      "name" => "Concurrent",
      "relative_project" => Path.relative_to(project, Workspace.root()),
      "session_file" => create_session_file(session_dir),
      "pi_session_id" => "pi-123"
    }

    ids =
      1..2
      |> Task.async_stream(fn _ -> Store.register(attributes) end,
        max_concurrency: 2,
        ordered: false
      )
      |> Enum.map(fn {:ok, {:ok, session}} -> session["id"] end)

    assert [_id] = Enum.uniq(ids)
    assert length(Store.list()) == 1
  end

  test "rejects a session file outside the session directory", %{
    conn: conn,
    project_dir: project_dir
  } do
    project = create_project(project_dir, "alpha")
    outside = Path.join(System.tmp_dir!(), "outside-#{System.unique_integer([:positive])}.jsonl")
    File.write!(outside, "{}")

    conn =
      post(conn, "/api/sessions", %{
        "relative_project" => Path.relative_to(project, Workspace.root()),
        "session_file" => outside,
        "pi_session_id" => "pi-123"
      })

    assert %{"error" => "Invalid session path"} = json_response(conn, 422)
    refute_registered(outside)
    File.rm!(outside)
  end

  test "rejects a session file that does not exist", %{
    conn: conn,
    session_dir: session_dir,
    project_dir: project_dir
  } do
    project = create_project(project_dir, "alpha")

    conn =
      post(conn, "/api/sessions", %{
        "relative_project" => Path.relative_to(project, Workspace.root()),
        "session_file" => Path.join(session_dir, "missing.jsonl"),
        "pi_session_id" => "pi-123"
      })

    assert %{"error" => "Session file not found"} = json_response(conn, 422)
    refute_registered(Path.join(session_dir, "missing.jsonl"))
  end

  test "rejects a project outside the workspace", %{conn: conn, session_dir: session_dir} do
    session_file = create_session_file(session_dir)

    conn =
      post(conn, "/api/sessions", %{
        "relative_project" => "../etc",
        "session_file" => session_file,
        "pi_session_id" => "pi-123"
      })

    assert %{"error" => "Invalid project"} = json_response(conn, 422)
    refute_registered(session_file)
  end

  defp create_project(project_dir, name) do
    path = Path.join(project_dir, name)
    File.mkdir_p!(path)

    case Workspace.canonical(path) do
      {:ok, canonical} -> canonical
      {:error, reason} -> raise reason
    end
  end

  defp create_session_file(session_dir) do
    path = Path.join(session_dir, "session-#{System.unique_integer([:positive])}.jsonl")
    File.write!(path, "{}")
    path
  end

  defp refute_registered(session_file),
    do: refute(Enum.find(Store.list(), &(&1["session_file"] == session_file)))
end
