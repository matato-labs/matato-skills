defmodule WebApp.BotsTest do
  use ExUnit.Case, async: false

  alias WebApp.{Bots, RemoteSessions, Repo, Workspace}
  alias WebApp.Bots.Bot
  alias WebApp.Messages.Message

  setup do
    Repo.delete_all(Message)
    Repo.delete_all(Bot)
    pi_dir = Path.join(System.tmp_dir!(), "bot-pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    File.mkdir_p!(pi_dir)

    File.write!(
      pi_path,
      "#!/usr/bin/env python3\nimport json, sys\nfor line in sys.stdin:\n command = json.loads(line)\n response = {\"id\": command[\"id\"], \"type\": \"response\", \"command\": command[\"type\"], \"success\": True}\n if command[\"type\"] == \"get_state\": response[\"data\"] = {\"model\": None, \"isStreaming\": False, \"isCompacting\": False, \"sessionFile\": None, \"sessionId\": \"bot\"}\n elif command[\"type\"] == \"get_messages\": response[\"data\"] = {\"messages\": []}\n elif command[\"type\"] == \"get_commands\": response[\"data\"] = {\"commands\": []}\n print(json.dumps(response), flush=True)\n"
    )

    File.chmod!(pi_path, 0o700)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")

    on_exit(fn ->
      System.put_env("PATH", original_path)
      Repo.delete_all(Message)
      Repo.delete_all(Bot)
      File.rm_rf!(pi_dir)
    end)

    :ok
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

    assert Bots.identity(bot.id) == "You are Research, researcher. Find facts"

    assert Bots.identity_for_session("chat-identity") ==
             "You are Research, researcher. Find facts"

    assert Bots.identity_for_session("background-identity") ==
             "You are Research, researcher. Find facts"

    assert Bots.identity("missing") == nil
    assert Bots.identity_for_session("missing") == nil
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
             RemoteSessions.get(bot.chat_remote_session_id)

    assert project == Workspace.root()

    assert %{"source" => "bot_background", "project" => ^project, "relative_project" => "."} =
             RemoteSessions.get(bot.background_remote_session_id)

    :ok = Bots.delete(bot.id)
  end
end
