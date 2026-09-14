defmodule WebAppWeb.BotLiveTest do
  use WebAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias WebApp.Repo
  alias WebApp.Bots.Bot

  setup do
    Repo.delete_all(Bot)

    bot =
      Repo.insert!(%Bot{
        name: "Planner",
        role: "planner",
        description: "Plans work",
        chat_remote_session_id: "chat-live",
        background_remote_session_id: "background-live"
      })

    %{bot: bot}
  end

  test "lists bots in the sidebar and opens the creation dialog", %{conn: conn, bot: bot} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#bot-#{bot.id}[href='/bots/#{bot.id}']")
    refute has_element?(view, "#bot-dialog")

    view |> element("#new-bot-button") |> render_click()

    assert has_element?(view, "#bot-dialog")
    assert has_element?(view, "#create-bot-form")
  end

  test "places bots before workspace and automations", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    html = render(view)

    assert {bots_index, _length} = :binary.match(html, "id=\"bots\"")
    assert {workspace_index, _length} = :binary.match(html, "id=\"workspace-session-groups\"")
    assert {automations_index, _length} = :binary.match(html, "id=\"automation-session-groups\"")
    assert bots_index < workspace_index
    assert workspace_index < automations_index
  end

  test "confirms bot deletion inline", %{conn: conn, bot: bot} do
    {:ok, view, _html} = live(conn, "/")

    view |> element("#delete-bot-#{bot.id}") |> render_click()

    assert has_element?(view, "#confirm-delete-bot-#{bot.id}")
  end
end
