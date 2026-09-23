defmodule WebAppWeb.SessionComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias WebAppWeb.SessionComponents

  test "shows each bot chat status with the workspace status marker" do
    html =
      render_component(&SessionComponents.sidebar/1,
        workspace_groups: [],
        automation_groups: [],
        bots: [%{id: "bot", name: "Review bot", chat_remote_session_id: "chat"}],
        sessions: [%{"id" => "chat", "status" => "working"}],
        mobile_sidebar_open: false
      )

    assert html =~ "bot-bot"
    assert html =~ "bg-warning"
    assert html =~ "Working"
    refute html =~ "hero-cpu-chip"
  end

  test "renders one automation link with status counts and no run links" do
    html =
      render_component(&SessionComponents.sidebar/1,
        workspace_groups: [],
        automation_groups: [
          %{
            key: 12,
            id: 12,
            label: "Daily review",
            count: 4,
            status_counts: %{working: 1, finished: 2, failed: 1},
            sessions: []
          }
        ],
        mobile_sidebar_open: false
      )

    assert html =~ ~s(aria-label="Automations")
    assert html =~ "Daily review"
    assert html =~ "1 working · 2 finished · 1 failed"
    assert html =~ ~s(href="/automations/12")
    refute html =~ "/automation-runs/"
  end
end
