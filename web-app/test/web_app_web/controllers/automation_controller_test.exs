defmodule WebAppWeb.AutomationControllerTest do
  use WebAppWeb.ConnCase, async: false

  alias WebApp.Automations

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

    automation = json_response(conn, 201)["automation"]
    assert %{"monitor" => false} = automation
    refute Map.has_key?(automation, "bot_id")
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
