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

  test "renders workspace automation history as linked run cards with readable results" do
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
            sessions: [
              %{id: "working", status: "waiting_for_input", result: nil},
              %{
                id: "finished",
                status: "settled",
                result:
                  "A complete, readable result with more than twenty words: a summary of the work done and next steps for the operator."
              },
              %{
                id: "failed",
                status: "failed",
                result: "Permission denied\nTry another workspace"
              }
            ]
          }
        ],
        mobile_sidebar_open: false
      )

    assert html =~ ~s(aria-label="Automations")
    assert html =~ "Daily review"
    assert html =~ "1 working · 2 finished · 1 failed"
    assert html =~ ~s(href="/automations/12")

    assert [card] = Regex.run(~r{<a[^>]*href="/automation-runs/working"[^>]*>.*?</a>}s, html)
    assert card =~ "Working"
    refute html =~ ~s(href="/automation-runs/finished")
    refute html =~ ~s(href="/automation-runs/failed")
    refute html =~ "max-w-20 truncate"
  end

  test "bot automations do not appear beneath the bot in the chat navigation" do
    html =
      render_component(&SessionComponents.sidebar/1,
        workspace_groups: [],
        automation_groups: [
          %{
            id: 9,
            label: "Review changes",
            bot_id: "bot",
            count: 1,
            status_counts: %{failed: 1},
            sessions: [
              %{id: "run1", status: "failed", result: "API <token> rejected & retry failed"}
            ]
          }
        ],
        bots: [%{id: "bot", name: "Review bot", chat_remote_session_id: "chat"}],
        sessions: [%{"id" => "chat", "status" => "working"}],
        mobile_sidebar_open: false
      )

    assert [bot_link] = Regex.run(~r{<a[^>]*href="/bots/bot"[^>]*>.*?</a>}s, html)
    assert bot_link =~ "Review bot"
    assert bot_link =~ "Working"
    refute html =~ ~s(href="/automations/9")
    refute html =~ ~s(href="/automation-runs/run1")
    refute html =~ "API &lt;token&gt; rejected &amp; retry failed"

    assert [_, workspace_automations] =
             Regex.run(~r{id="automation-session-groups"[^>]*>(.*?)</nav>}s, html)

    refute workspace_automations =~ ~s(href="/automations/9")
  end

  test "unmonitored bot automation does not appear beneath its bot" do
    html =
      render_component(&SessionComponents.sidebar/1,
        workspace_groups: [],
        automation_groups: [
          %{id: 4, label: "Inbox", bot_id: "bot", monitor: false, count: 0, sessions: []}
        ],
        bots: [%{id: "bot", name: "Assistant", chat_remote_session_id: "chat"}],
        mobile_sidebar_open: false
      )

    refute html =~ ~s(href="/automations/4")
    refute html =~ "Monitoring off"
    refute html =~ "/automation-runs/"

    assert [_, workspace_automations] =
             Regex.run(~r{id="automation-session-groups"[^>]*>(.*?)</nav>}s, html)

    refute workspace_automations =~ ~s(href="/automations/4")
  end

  test "renders bot automation activity with the automation status" do
    html =
      render_component(&SessionComponents.automation_activity_panel/1,
        bot: %{name: "Review bot"},
        automation_groups: [
          %{
            id: 9,
            label: "Review changes",
            sessions: [%{id: "run1", status: "failed", result: "API <token> rejected"}]
          }
        ]
      )

    assert html =~ ~s(id="automation-activity-panel")
    assert html =~ ~s(id="automation-activity-run-run1")
    assert html =~ "Automation"
    assert html =~ "Failed"
    assert html =~ "API &lt;token&gt; rejected"
    refute html =~ "Activity ·"
  end

  test "an automation without runs keeps its detail link and shows no run card" do
    html =
      render_component(&SessionComponents.sidebar/1,
        workspace_groups: [],
        automation_groups: [%{id: 3, label: "Pending", count: 0, sessions: []}],
        mobile_sidebar_open: false
      )

    assert html =~ ~s(href="/automations/3")
    assert html =~ "No runs"
    refute html =~ "/automation-runs/"
  end
end
