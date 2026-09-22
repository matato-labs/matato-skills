defmodule WebApp.BotsTest do
  use ExUnit.Case, async: false

  alias WebApp.Bots
  alias WebApp.Data.Repo
  alias WebApp.Sessions.{Store, Workspace}
  alias WebApp.Bots.Bot
  alias WebApp.Messages.Message

  setup do
    Repo.delete_all(Message)
    Repo.delete_all(Bot)
    pi_dir = Path.join(System.tmp_dir!(), "bot-pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    pi_marker = Path.join(pi_dir, "started")
    File.mkdir_p!(pi_dir)

    File.write!(
      pi_path,
      "#!/usr/bin/env python3\nimport json, sys, os\nfor line in sys.stdin:\n open(os.environ[\"BOT_PI_MARKER\"], \"a\").write(\"started\\n\")\n command = json.loads(line)\n response = {\"id\": command[\"id\"], \"type\": \"response\", \"command\": command[\"type\"], \"success\": True}\n if command[\"type\"] == \"get_state\": response[\"data\"] = {\"model\": None, \"isStreaming\": False, \"isCompacting\": False, \"sessionFile\": None, \"sessionId\": \"bot\"}\n elif command[\"type\"] == \"get_messages\": response[\"data\"] = {\"messages\": []}\n elif command[\"type\"] == \"get_commands\": response[\"data\"] = {\"commands\": []}\n print(json.dumps(response), flush=True)\n"
    )

    File.chmod!(pi_path, 0o700)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")
    original_marker = System.get_env("BOT_PI_MARKER")
    System.put_env("BOT_PI_MARKER", pi_marker)

    on_exit(fn ->
      System.put_env("PATH", original_path)

      if original_marker,
        do: System.put_env("BOT_PI_MARKER", original_marker),
        else: System.delete_env("BOT_PI_MARKER")

      Repo.delete_all(Message)
      Repo.delete_all(Bot)
      File.rm_rf!(pi_dir)
    end)

    %{pi_marker: pi_marker}
  end

  test "builds a bot identity from its durable profile" do
    bot =
      Repo.insert!(%Bot{
        name: "Research",
        role: "researcher",
        description: "Find facts",
        chat_remote_session_id: "chat-identity",
        background_remote_session_id: "background-identity"
      })

    for identity <- [
          Bots.identity(bot.id),
          Bots.identity_for_session("chat-identity"),
          Bots.identity_for_session("background-identity")
        ] do
      assert identity =~ "You are Research, researcher. Find facts"
      assert identity =~ "POST /api/messages"
      assert identity =~ "Watch for repeated tasks or recurring problems"
      assert identity =~ "suggest an automation for a repeated task"
      assert identity =~ "durable solution for a recurring problem"
      assert identity =~ "After completing the user's immediate request"
      assert identity =~ "briefly and optionally"
      assert identity =~ "never assume consent or let it interrupt the current request"

      assert identity =~
               "If the user declines a suggestion, do not raise that same suggestion again unless they bring up the need again"
    end

    assert Bots.identity("missing") == nil
    assert Bots.identity_for_session("missing") == nil
  end

  test "rejects an incomplete profile before creating remote sessions", %{pi_marker: pi_marker} do
    session_count = length(Store.list())

    assert {:error, changeset} = Bots.create(%{"name" => "Research"})

    assert [role: {"can't be blank", _}, description: {"can't be blank", _}] = changeset.errors

    assert session_count == length(Store.list())
    refute File.exists?(pi_marker)
  end

  test "creates permanent chat and private background remote sessions" do
    {:ok, bot} =
      Bots.create(%{
        "name" => "Research",
        "role" => "researcher",
        "description" => "Find facts"
      })

    assert %Bot{id: id, name: "Research", role: "researcher"} = Bots.get(bot.id)
    assert id == bot.id

    assert %{"source" => "bot_chat", "project" => project, "relative_project" => "."} =
             Store.get(bot.chat_remote_session_id)

    assert project == Workspace.root()

    assert %{"source" => "bot_background", "project" => ^project, "relative_project" => "."} =
             Store.get(bot.background_remote_session_id)

    :ok = Bots.delete(bot.id)
  end
end
