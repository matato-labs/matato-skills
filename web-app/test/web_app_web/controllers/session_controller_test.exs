defmodule WebAppWeb.SessionControllerTest do
  use WebAppWeb.ConnCase, async: false

  alias WebApp.{AgentSession, RemoteRegistry, RemoteSessions, Workspace}

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "matato-sessions-#{System.unique_integer([:positive])}")

    File.mkdir_p!(session_dir)
    previous = Application.fetch_env!(:web_app, :session_dir)
    Application.put_env(:web_app, :session_dir, session_dir)
    RemoteRegistry.subscribe()

    on_exit(fn ->
      Application.put_env(:web_app, :session_dir, previous)

      RemoteSessions.list()
      |> Enum.filter(&String.starts_with?(&1["project"], System.tmp_dir!()))
      |> Enum.each(&RemoteSessions.delete(&1["id"]))
    end)

    {:ok, session_dir: session_dir}
  end

  test "registers a terminal session as a stopped extension session", %{
    conn: conn,
    session_dir: session_dir
  } do
    project = create_project("alpha")
    session_file = create_session_file(session_dir)

    conn =
      post(conn, "/api/sessions", %{
        "name" => "My session",
        "relative_project" => "alpha",
        "session_file" => session_file,
        "pi_session_id" => "pi-123"
      })

    assert %{"session" => session} = json_response(conn, 201)
    assert session["name"] == "My session"
    assert session["project"] == project
    assert session["relative_project"] == "alpha"
    assert session["session_file"] == session_file
    assert session["pi_session_id"] == "pi-123"
    assert session["source"] == "extension"
    assert session["status"] == "stopped"

    assert_received :changed
    refute AgentSession.whereis(session["id"])
  end

  test "defaults the session name to the project directory name", %{conn: conn, session_dir: dir} do
    create_project("beta")

    conn =
      post(conn, "/api/sessions", %{
        "relative_project" => "beta",
        "session_file" => create_session_file(dir),
        "pi_session_id" => "pi-123"
      })

    assert %{"session" => %{"name" => "beta"}} = json_response(conn, 201)
  end

  test "updates the existing record when the session file is already registered", %{
    conn: conn,
    session_dir: session_dir
  } do
    create_project("alpha")
    session_file = create_session_file(session_dir)

    attributes = %{
      "name" => "First",
      "relative_project" => "alpha",
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
    assert length(RemoteSessions.list()) == 1
  end

  test "rejects a session file outside the session directory", %{conn: conn} do
    create_project("alpha")
    outside = Path.join(System.tmp_dir!(), "outside-#{System.unique_integer([:positive])}.jsonl")
    File.write!(outside, "{}")

    conn =
      post(conn, "/api/sessions", %{
        "relative_project" => "alpha",
        "session_file" => outside,
        "pi_session_id" => "pi-123"
      })

    assert %{"error" => "Invalid session path"} = json_response(conn, 422)
    refute_registered(outside)
  end

  test "rejects a session file that does not exist", %{conn: conn, session_dir: session_dir} do
    create_project("alpha")

    conn =
      post(conn, "/api/sessions", %{
        "relative_project" => "alpha",
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

  defp create_project(name) do
    path = Path.join(System.tmp_dir!(), name)
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
    do: refute(Enum.find(RemoteSessions.list(), &(&1["session_file"] == session_file)))
end
