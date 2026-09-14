defmodule WebApp.MessageWorkerTest do
  use ExUnit.Case, async: false

  alias WebApp.{
    AgentSession,
    MessageDeliveryScheduler,
    MessageWorker,
    Messages,
    RemoteSessions,
    Repo,
    Workspace
  }

  alias WebApp.Bots.Bot
  alias WebApp.Messages.Message

  setup do
    Repo.delete_all(Message)
    Repo.delete_all(Bot)
    root = Path.join(System.tmp_dir!(), "message-worker-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    executable = Path.join(root, "fakepi")
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    project = Path.join(Workspace.root(), "message-worker-#{id}")
    File.mkdir_p!(project)

    File.write!(
      executable,
      "#!/usr/bin/env python3\nimport json, sys\nfor line in sys.stdin:\n command = json.loads(line)\n response = {\"id\": command[\"id\"], \"type\": \"response\", \"command\": command[\"type\"], \"success\": True}\n if command[\"type\"] == \"get_state\": response[\"data\"] = {\"model\": None, \"isStreaming\": False, \"isCompacting\": False, \"sessionFile\": None, \"sessionId\": \"worker\"}\n elif command[\"type\"] == \"get_messages\": response[\"data\"] = {\"messages\": []}\n elif command[\"type\"] == \"get_commands\": response[\"data\"] = {\"commands\": []}\n print(json.dumps(response), flush=True)\n"
    )

    File.chmod!(executable, 0o700)

    start_supervised!(
      {AgentSession, id: id, name: "background", project: project, executable: executable},
      id: id
    )

    assert :ok = AgentSession.await_ready(id)

    {:ok, _session} =
      RemoteSessions.create(%{
        id: id,
        name: "background",
        project_path: project,
        relative_project: Path.relative_to(project, Workspace.root()),
        source: "bot_background",
        status: "settled"
      })

    bot =
      Repo.insert!(%Bot{
        name: "Worker",
        role: "operator",
        description: "Processes internal work",
        chat_remote_session_id: "chat-worker",
        background_remote_session_id: id
      })

    on_exit(fn ->
      Repo.delete_all(Message)
      Repo.delete(bot)
      RemoteSessions.delete(id)
      File.rm_rf!(root)
      File.rm_rf!(project)
    end)

    %{bot: bot}
  end

  test "polls pending deliveries every three seconds" do
    assert [{_, job}] = MessageDeliveryScheduler.jobs()
    assert {MessageWorker, :deliver_pending, []} = job.task
    assert inspect(job.schedule) == "~e[*/3 * * * * *]"
  end

  test "delivers pending messages through the private background session", %{bot: bot} do
    bot_id = bot.id
    :ok = Messages.subscribe(bot_id)

    {:ok, message} =
      Messages.create(%{
        receiver_bot_id: bot_id,
        sender_type: "automation",
        kind: "result",
        content: "Work finished"
      })

    assert_receive {:message_changed, ^bot_id}
    :ok = MessageWorker.deliver_pending()
    assert_receive {:message_changed, ^bot_id}
    assert [%Message{id: message_id, sent_status: "sent"}] = Messages.list_for_bot(bot.id)
    assert message_id == message.id
  end

  test "marks a message failed when its background session is unavailable" do
    bot =
      Repo.insert!(%Bot{
        name: "Unavailable",
        role: "operator",
        description: "Cannot receive work",
        chat_remote_session_id: "chat-unavailable",
        background_remote_session_id: "background-unavailable"
      })

    {:ok, message} =
      Messages.create(%{
        receiver_bot_id: bot.id,
        sender_type: "automation",
        kind: "result",
        content: "Delivery fails"
      })

    :ok = MessageWorker.deliver_pending()

    assert [%Message{id: message_id, sent_status: "failed"}] = Messages.list_for_bot(bot.id)
    assert message_id == message.id
  end

  test "defers a message when the background bot is busy", %{bot: bot} do
    :owner = AgentSession.claim(bot.background_remote_session_id, self())

    {:ok, message} =
      Messages.create(%{
        receiver_bot_id: bot.id,
        sender_type: "automation",
        kind: "result",
        content: "Wait for me"
      })

    :ok = MessageWorker.deliver_pending()

    assert [%Message{id: message_id, sent_status: "pending"}] = Messages.list_for_bot(bot.id)
    assert message_id == message.id
    AgentSession.release(bot.background_remote_session_id, self())
  end
end
