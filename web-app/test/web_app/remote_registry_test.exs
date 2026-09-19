defmodule WebApp.Sessions.RegistryTest do
  use ExUnit.Case, async: false

  alias WebApp.Sessions.{Registry, Store}

  setup do
    on_exit(fn ->
      Store.list()
      |> Enum.filter(&String.starts_with?(&1["project"], System.tmp_dir!()))
      |> Enum.each(&Store.delete(&1["id"]))
    end)

    :ok
  end

  test "derives the session name from the first prompt of a web session" do
    id = create_session("alpha", "alpha")

    GenServer.cast(Registry, {:prompt, id, "  fix   the login\nbug please right now"})
    _ = :sys.get_state(Registry)

    assert Store.get(id)["name"] == "fix the login bug please right"
  end

  test "keeps custom web session names" do
    id = create_session("alpha", "My session")

    GenServer.cast(Registry, {:prompt, id, "fix the login bug"})
    _ = :sys.get_state(Registry)

    assert Store.get(id)["name"] == "My session"
  end

  test "keeps bot session names" do
    id = create_session("alpha", "alpha", "bot_chat")

    GenServer.cast(Registry, {:prompt, id, "fix the login bug"})
    _ = :sys.get_state(Registry)

    assert Store.get(id)["name"] == "alpha"
  end

  test "ignores blank prompts" do
    id = create_session("alpha", "alpha")

    GenServer.cast(Registry, {:prompt, id, "   \n  "})
    _ = :sys.get_state(Registry)

    assert Store.get(id)["name"] == "alpha"
  end

  defp create_session(project_name, name, source \\ "web") do
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    project = Path.join(System.tmp_dir!(), project_name)

    {:ok, _session} =
      Store.create(%{
        id: id,
        name: name,
        project_path: project,
        relative_project: project_name,
        status: "settled",
        source: source
      })

    id
  end
end
