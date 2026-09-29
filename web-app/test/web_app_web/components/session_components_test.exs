defmodule WebAppWeb.SessionComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias WebAppWeb.SessionComponents

  test "shows generic sessions without bots or plugin controls" do
    html =
      render_component(&SessionComponents.sidebar/1,
        workspace_groups: [],
        automation_groups: [],
        general_sessions: [
          %{id: "general-1", title: "New session", status: "settled", source: "general"}
        ],
        mobile_sidebar_open: false
      )

    document = LazyHTML.from_fragment(html)
    assert LazyHTML.query(document, "#session-sidebar button[phx-click='start_general']") != []

    assert LazyHTML.query(
             document,
             "#session-sidebar a[aria-label='New workspace session'][href='/']"
           ) != []

    assert html =~ ~s(id="general-sessions")
    assert html =~ ~s(href="/sessions/general-1")
    refute html =~ ~s(href="/plugins")
    refute html =~ ~s(id="bots")
  end

  test "historical conversations remain clickable workspace sessions" do
    html =
      render_component(&SessionComponents.sidebar/1,
        workspace_groups: [
          %{
            key: :root,
            label: "Workspace",
            sessions: [
              %{id: "historicalId", title: "Conversation", status: "stopped", source: "bot_chat"}
            ]
          }
        ],
        automation_groups: [],
        mobile_sidebar_open: false
      )

    assert html
           |> LazyHTML.from_fragment()
           |> LazyHTML.query("#session-historicalId a[href='/sessions/historicalId']")
           |> Enum.count() == 1
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
