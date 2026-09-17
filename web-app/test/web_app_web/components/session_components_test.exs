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

  test "renders active automation work separately from workspace sessions" do
    html =
      render_component(&SessionComponents.sidebar/1,
        workspace_groups: [],
        automation_groups: [
          %{
            key: :others,
            label: "Others",
            sessions: [
              %{id: "automation", source: "automation", status: "working", title: "Daily review"}
            ]
          }
        ],
        mobile_sidebar_open: false
      )

    assert html =~ "Automations"
    assert html =~ "automation-session-groups"
    assert html =~ "Daily review"
    assert html =~ "Working"
  end
end
