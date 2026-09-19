defmodule WebAppWeb.AutomationControllerTest do
  use WebAppWeb.ConnCase, async: false

  alias WebApp.Automations
  alias WebApp.Data.Repo
  alias WebApp.Bots.Bot

  setup do
    :ok = Automations.replace([])
  end

  test "defaults monitoring to disabled", %{conn: conn} do
    conn =
      post(conn, "/api/automations", %{
        "job_name" => "unmonitored",
        "enabled" => true,
        "schedule" => "0 9 * * *",
        "user_prompt" => "Review open work.",
        "daily_session" => false,
        "can_overlap" => false,
        "model" => "model",
        "thinking_level" => "low",
        "can_launch_sub_agents" => false,
        "use_skill" => false
      })

    assert %{"monitor" => false} = json_response(conn, 201)["automation"]
  end

  test "accepts nullable bot ids", %{conn: conn} do
    bot =
      Repo.insert!(%Bot{
        name: "Automations",
        role: "operator",
        description: "Runs jobs",
        chat_remote_session_id: "chat-controller",
        background_remote_session_id: "background-controller"
      })

    on_exit(fn -> Repo.delete(bot) end)

    attributes = %{
      "job_name" => "bot-job",
      "bot_id" => bot.id,
      "enabled" => true,
      "schedule" => "0 9 * * *",
      "user_prompt" => "Run it",
      "daily_session" => false,
      "can_overlap" => false,
      "model" => "model",
      "thinking_level" => "low",
      "can_launch_sub_agents" => false,
      "use_skill" => false
    }

    conn = post(conn, "/api/automations", attributes)
    assert %{"id" => id, "bot_id" => bot_id} = json_response(conn, 201)["automation"]
    assert bot_id == bot.id

    conn = put(build_conn(), "/api/automations/#{id}", Map.put(attributes, "bot_id", nil))
    assert %{"bot_id" => nil} = json_response(conn, 200)["automation"]
  end

  test "rejects a bot id that does not identify a durable bot", %{conn: conn} do
    conn =
      post(conn, "/api/automations", %{
        "job_name" => "missing-bot",
        "bot_id" => Ecto.UUID.generate(),
        "enabled" => true,
        "schedule" => "0 9 * * *",
        "user_prompt" => "Run it",
        "daily_session" => false,
        "can_overlap" => false,
        "model" => "model",
        "thinking_level" => "low",
        "can_launch_sub_agents" => false,
        "use_skill" => false
      })

    assert %{"errors" => %{"bot_id" => ["does not exist"]}} = json_response(conn, 422)
  end

  test "creates, reads, updates, and deletes automations", %{conn: conn} do
    attributes = %{
      "job_name" => "daily-review",
      "enabled" => true,
      "schedule" => "0 9 * * *",
      "user_prompt" => "Review open work.",
      "daily_session" => false,
      "can_overlap" => true,
      "model" => "model",
      "thinking_level" => "low",
      "can_launch_sub_agents" => false,
      "monitor" => true,
      "use_skill" => true
    }

    conn = post(conn, "/api/automations", attributes)

    assert %{
             "id" => id,
             "job_name" => "daily-review",
             "can_overlap" => true,
             "monitor" => true
           } = json_response(conn, 201)["automation"]

    conn = get(build_conn(), "/api/automations")
    assert [%{"id" => ^id}] = json_response(conn, 200)["automations"]
    assert %Automations{id: ^id} = Automations.get(id)

    conn = get(build_conn(), "/api/automations/#{id}")
    assert %{"id" => ^id} = json_response(conn, 200)["automation"]

    conn = put(build_conn(), "/api/automations/#{id}", %{attributes | "enabled" => false})
    assert %{"enabled" => false} = json_response(conn, 200)["automation"]

    conn = delete(build_conn(), "/api/automations/#{id}")
    assert response(conn, 204)

    conn = get(build_conn(), "/api/automations/#{id}")
    assert %{"error" => "Automation not found"} = json_response(conn, 404)
  end
end
