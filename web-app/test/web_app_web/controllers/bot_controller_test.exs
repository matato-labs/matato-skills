defmodule WebAppWeb.BotControllerTest do
  use WebAppWeb.ConnCase, async: false

  alias WebApp.Repo
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

  test "returns not found for an absent bot", %{conn: conn} do
    assert %{"error" => "Bot not found"} = json_response(get(conn, "/api/bots/missing"), 404)
  end
end
