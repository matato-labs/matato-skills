defmodule WebAppWeb.MessageControllerTest do
  use WebAppWeb.ConnCase, async: false

  alias WebApp.{Messages, Repo}
  alias WebApp.Bots.Bot
  alias WebApp.Messages.Message

  setup do
    :ok = :sys.suspend(WebApp.MessageWorker)
    on_exit(fn -> :ok = :sys.resume(WebApp.MessageWorker) end)
    Repo.delete_all(Message)
    Repo.delete_all(Bot)

    sender =
      Repo.insert!(%Bot{
        name: "Sender",
        role: "researcher",
        description: "Finds answers",
        chat_remote_session_id: "chat-sender",
        background_remote_session_id: "background-sender"
      })

    receiver =
      Repo.insert!(%Bot{
        name: "Receiver",
        role: "writer",
        description: "Writes reports",
        chat_remote_session_id: "chat-receiver",
        background_remote_session_id: "background-receiver"
      })

    %{sender: sender, receiver: receiver}
  end

  test "creates a pending bot message", %{conn: conn, sender: sender, receiver: receiver} do
    conn =
      post(conn, "/api/messages", %{
        "receiver_bot_id" => receiver.id,
        "sender_id" => sender.id,
        "kind" => "request",
        "content" => "Summarize the open issues"
      })

    assert %{
             "message" => %{
               "sender_type" => "bot",
               "sender_id" => sender_id,
               "receiver_bot_id" => receiver_id,
               "kind" => "request",
               "sent_status" => "pending"
             }
           } = json_response(conn, 201)

    assert sender_id == sender.id
    assert receiver_id == receiver.id
    assert [%{content: "Summarize the open issues"}] = Messages.list_for_bot(receiver.id)
  end

  test "rejects an unknown receiver", %{conn: conn, sender: sender} do
    conn =
      post(conn, "/api/messages", %{
        "receiver_bot_id" => Ecto.UUID.generate(),
        "sender_id" => sender.id,
        "kind" => "request",
        "content" => "Hello"
      })

    assert %{"error" => %{"receiver_bot_id" => ["does not exist"]}} = json_response(conn, 422)
  end

  test "rejects an unknown sender", %{conn: conn, receiver: receiver} do
    conn =
      post(conn, "/api/messages", %{
        "receiver_bot_id" => receiver.id,
        "sender_id" => Ecto.UUID.generate(),
        "kind" => "request",
        "content" => "Hello"
      })

    assert %{"error" => %{"sender_id" => ["does not exist"]}} = json_response(conn, 422)
  end

  test "requires kind and content", %{conn: conn, sender: sender, receiver: receiver} do
    conn =
      post(conn, "/api/messages", %{"receiver_bot_id" => receiver.id, "sender_id" => sender.id})

    assert %{"error" => %{"kind" => ["can't be blank"], "content" => ["can't be blank"]}} =
             json_response(conn, 422)
  end
end
