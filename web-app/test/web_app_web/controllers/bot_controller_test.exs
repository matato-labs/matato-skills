defmodule WebAppWeb.BotControllerTest do
  use WebAppWeb.ConnCase, async: false

  alias WebApp.Data.Repo
  alias WebApp.Bots.Bot

  setup do
    Repo.delete_all(Bot)

    bot =
      Repo.insert!(%Bot{
        name: "Research",
        role: "researcher",
        description: "Find answers",
        chat_remote_session_id: "chat-api",
        background_remote_session_id: "background-api"
      })

    %{bot: bot}
  end

  test "lists and reads bots without exposing remote sessions as routes", %{conn: conn, bot: bot} do
    conn = get(conn, "/api/bots")

    assert [%{"id" => id, "name" => "Research", "role" => "researcher"}] =
             json_response(conn, 200)["bots"]

    assert id == bot.id

    conn = get(build_conn(), "/api/bots/#{bot.id}")

    assert %{"id" => ^id, "chat_remote_session_id" => "chat-api"} =
             json_response(conn, 200)["bot"]
  end

  test "returns profile validation errors without creating a bot", %{conn: conn} do
    conn = post(conn, "/api/bots", %{"name" => "Research"})

    assert %{"error" => %{"description" => ["can't be blank"], "role" => ["can't be blank"]}} =
             json_response(conn, 422)
  end

  test "updates bot profiles", %{conn: conn, bot: bot} do
    conn =
      put(conn, "/api/bots/#{bot.id}", %{
        "name" => "Writer",
        "role" => "editor",
        "description" => "Writes concise copy"
      })

    assert %{"name" => "Writer", "role" => "editor", "description" => "Writes concise copy"} =
             json_response(conn, 200)["bot"]

    assert %Bot{name: "Writer", chat_remote_session_id: "chat-api"} = Repo.get(Bot, bot.id)
  end

  test "returns not found for an absent bot", %{conn: conn} do
    assert %{"error" => "Bot not found"} = json_response(get(conn, "/api/bots/missing"), 404)
    assert %{"error" => "Bot not found"} = json_response(put(conn, "/api/bots/missing", %{}), 404)
  end
end
