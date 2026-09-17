defmodule WebApp.MessagesTest do
  use ExUnit.Case, async: false

  alias WebApp.{Messages, Repo}
  alias WebApp.Bots.Bot
  alias WebApp.Messages.Message

  setup do
    :ok = :sys.suspend(WebApp.MessageWorker)
    on_exit(fn -> :ok = :sys.resume(WebApp.MessageWorker) end)
    Repo.delete_all(Message)
    Repo.delete_all(Bot)

    bot =
      Repo.insert!(%Bot{
        name: "Inbox",
        role: "assistant",
        description: "Tests",
        chat_remote_session_id: "chat-test",
        background_remote_session_id: "background-test"
      })

    %{bot: bot}
  end

  test "persists automation results for a bot only", %{bot: bot} do
    assert :ok = Messages.create_automation_result(nil, "ignored")
    assert [] = Messages.list_for_bot(bot.id)

    assert {:ok, %Message{kind: "result", sender_type: "automation", content: "Finished"}} =
             Messages.create_automation_result(bot.id, "Finished")
  end

  test "persists messages in timestamp and id order", %{bot: bot} do
    timestamp = DateTime.utc_now()
    first = create_message(bot, timestamp, "first")
    second = create_message(bot, timestamp, "second")

    assert Enum.sort([first, second]) == Enum.map(Messages.list_for_bot(bot.id), & &1.id)
  end

  test "rejects a message for a bot that does not exist" do
    assert {:error, changeset} =
             Messages.create(%{
               receiver_bot_id: Ecto.UUID.generate(),
               sender_type: "automation",
               kind: "result",
               content: "Missing recipient"
             })

    assert {:receiver_bot_id, {"does not exist", []}} in changeset.errors
  end

  test "counts messages waiting for delivery", %{bot: bot} do
    create_message(bot, DateTime.utc_now(), "first")
    create_message(bot, DateTime.utc_now(), "second")

    assert Messages.count_pending() == 2

    assert %Message{} = Messages.claim_pending()
    assert Messages.count_pending() == 1
  end

  test "claims a pending message only once", %{bot: bot} do
    message = create_message(bot, DateTime.utc_now(), "claim me")

    assert %Message{id: ^message, sent_status: "processing"} = Messages.claim_pending()
    assert nil == Messages.claim_pending()
  end

  test "returns interrupted processing messages to pending", %{bot: bot} do
    message = create_message(bot, DateTime.utc_now(), "retry")
    assert %Message{} = Messages.claim_pending()

    assert {1, _} = Messages.reset_processing()
    assert [%Message{id: ^message, sent_status: "pending"}] = Messages.list_for_bot(bot.id)
  end

  test "skips deferred messages while preserving pending order", %{bot: bot} do
    first = create_message(bot, DateTime.from_unix!(1, :second), "first")
    second = create_message(bot, DateTime.from_unix!(2, :second), "second")

    assert %Message{id: ^second} = Messages.claim_pending([first])
  end

  test "broadcasts after persistence and after delivery state changes", %{bot: bot} do
    :ok = Messages.subscribe(bot.id)
    message = create_message(bot, DateTime.utc_now(), "notice")

    assert_receive {:message_changed, bot_id}
    assert bot_id == bot.id

    :ok = Messages.finish(%Message{id: message, receiver_bot_id: bot.id}, "failed")
    assert_receive {:message_changed, ^bot_id}
    assert [%Message{sent_status: "failed"}] = Messages.list_for_bot(bot.id)
  end

  defp create_message(bot, timestamp, content) do
    {:ok, message} =
      Messages.create(%{
        receiver_bot_id: bot.id,
        sender_type: "automation",
        kind: "result",
        content: content,
        timestamp: timestamp
      })

    message.id
  end
end
