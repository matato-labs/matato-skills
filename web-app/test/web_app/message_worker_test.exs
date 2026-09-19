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
      "#!/usr/bin/env python3\nimport json, sys\nfor line in sys.stdin:\n command = json.loads(line)\n with open(\"commands.jsonl\", \"a\") as file: file.write(json.dumps(command) + \"\\n\")\n response = {\"id\": command[\"id\"], \"type\": \"response\", \"command\": command[\"type\"], \"success\": True}\n if command[\"type\"] == \"get_state\": response[\"data\"] = {\"model\": None, \"isStreaming\": False, \"isCompacting\": False, \"sessionFile\": None, \"sessionId\": \"worker\"}\n elif command[\"type\"] == \"get_messages\": response[\"data\"] = {\"messages\": []}\n elif command[\"type\"] == \"get_commands\": response[\"data\"] = {\"commands\": []}\n print(json.dumps(response), flush=True)\n"
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

    %{bot: bot, project: project, executable: executable}
  end

  test "polls pending deliveries every three seconds" do
    assert [{_, job}] = MessageDeliveryScheduler.jobs()
    assert {MessageWorker, :deliver_pending, []} = job.task
    assert inspect(job.schedule) == "~e[*/3 * * * * *]"
  end

  test "delivers pending messages through the private background session", %{
    bot: bot,
    project: project
  } do
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

    assert [prompt] = prompts(project)
    assert prompt["message"] == "Internal result from automation:\nWork finished"
  end

  test "delivers bot messages through the visible chat session", %{
    bot: bot,
    project: project,
    executable: executable
  } do
    chat_id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    chat_project = Path.join(Workspace.root(), "message-worker-chat-#{chat_id}")
    File.mkdir_p!(chat_project)

    start_supervised!(
      {AgentSession, id: chat_id, name: "chat", project: chat_project, executable: executable},
      id: chat_id
    )

    assert :ok = AgentSession.await_ready(chat_id)

    {:ok, _session} =
      RemoteSessions.create(%{
        id: chat_id,
        name: "chat",
        project_path: chat_project,
        relative_project: Path.relative_to(chat_project, Workspace.root()),
        source: "bot_chat",
        status: "settled"
      })

    chat_bot =
      Repo.insert!(%Bot{
        name: "Chatty",
        role: "assistant",
        description: "Chats with other bots",
        chat_remote_session_id: chat_id,
        background_remote_session_id: "background-chatty"
      })

    on_exit(fn ->
      Repo.delete(chat_bot)
      RemoteSessions.delete(chat_id)
      File.rm_rf!(chat_project)
    end)

    {:ok, message} =
      Messages.create(%{
        receiver_bot_id: chat_bot.id,
        sender_type: "bot",
        sender_id: bot.id,
        kind: "request",
        content: "Hello from Worker"
      })

    :ok = MessageWorker.deliver_pending()

    assert [%Message{id: message_id, sent_status: "sent"}] = Messages.list_for_bot(chat_bot.id)
    assert message_id == message.id

    assert [prompt] = prompts(chat_project)
    assert prompt["message"] == "Internal request from Worker:\nHello from Worker"
    refute prompt["message"] =~ "You are Chatty"
    assert prompts(project) == []
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

  test "continues delivering remaining messages after a failure", %{bot: bot} do
    unavailable =
      Repo.insert!(%Bot{
        name: "Unavailable",
        role: "operator",
        description: "Cannot receive work",
        chat_remote_session_id: "chat-unavailable",
        background_remote_session_id: "background-unavailable"
      })

    {:ok, failing} =
      Messages.create(%{
        receiver_bot_id: unavailable.id,
        sender_type: "automation",
        kind: "result",
        content: "Delivery fails",
        timestamp: DateTime.from_unix!(1, :second)
      })

    {:ok, deliverable} =
      Messages.create(%{
        receiver_bot_id: bot.id,
        sender_type: "automation",
        kind: "result",
        content: "Delivery works",
        timestamp: DateTime.from_unix!(2, :second)
      })

    :ok = MessageWorker.deliver_pending()

    assert [%Message{id: message_id, sent_status: "failed"}] =
             Messages.list_for_bot(unavailable.id)

    assert message_id == failing.id

    assert [%Message{id: message_id, sent_status: "sent"}] = Messages.list_for_bot(bot.id)
    assert message_id == deliverable.id
  end

  test "continues delivering remaining messages after a success", %{bot: bot, project: project} do
    {:ok, first} =
      Messages.create(%{
        receiver_bot_id: bot.id,
        sender_type: "automation",
        kind: "result",
        content: "First",
        timestamp: DateTime.from_unix!(1, :second)
      })

    {:ok, second} =
      Messages.create(%{
        receiver_bot_id: bot.id,
        sender_type: "automation",
        kind: "result",
        content: "Second",
        timestamp: DateTime.from_unix!(2, :second)
      })

    :ok = MessageWorker.deliver_pending()

    assert [%Message{sent_status: "sent"}, %Message{sent_status: "sent"}] =
             Messages.list_for_bot(bot.id)

    assert [first_prompt, second_prompt] = prompts(project)
    assert first_prompt["message"] == "Internal result from automation:\nFirst"
    assert second_prompt["message"] == "Internal result from automation:\nSecond"
    assert first.id != second.id
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

  defp prompts(project) do
    project
    |> Path.join("commands.jsonl")
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
    |> Enum.filter(&(&1["type"] == "prompt"))
  end
end
