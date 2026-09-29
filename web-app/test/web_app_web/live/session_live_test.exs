defmodule WebAppWeb.SessionLiveTest do
  use WebAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias WebApp.Sessions.{Store, Workspace}

  test "centers the workspace picker and keeps general creation in the sidebar", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "main .place-items-center #start-session-form select[name='session[project]']"
           )

    refute has_element?(view, "#start-general-button")
    assert has_element?(view, "#session-sidebar button[phx-click='start_general']")
    assert has_element?(view, "#session-sidebar a[aria-label='New workspace session'][href='/']")
    refute has_element?(view, "#plugins-link")
  end

  test "channel controls and status APIs are not routed" do
    for path <- ["/plugins", "/api/channels/telegram", "/api/channels/discord"] do
      assert Phoenix.Router.route_info(WebAppWeb.Router, "GET", path, "localhost") == :error
    end
  end

  test "lists general sessions apart from historic workspace root sessions", %{conn: conn} do
    general_id = "general-#{System.unique_integer([:positive])}"
    workspace_id = "workspace-#{System.unique_integer([:positive])}"
    root = Workspace.root()

    {:ok, _} =
      Store.create(%{
        id: general_id,
        name: "New session",
        project_path: root,
        relative_project: ".",
        source: "general",
        status: "settled"
      })

    {:ok, _} =
      Store.create(%{
        id: workspace_id,
        name: "Workspace run",
        project_path: root,
        relative_project: ".",
        source: "web",
        status: "settled"
      })

    on_exit(fn ->
      Store.delete(general_id)
      Store.delete(workspace_id)
    end)

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#general-sessions #session-#{general_id}")
    assert has_element?(view, "#workspace-session-groups #session-#{workspace_id}")
    refute has_element?(view, "#general-sessions #session-#{workspace_id}")
  end

  test "opens and closes the mobile session drawer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#mobile-menu-button[aria-expanded='false'][aria-label='Open menu']"
           )

    view |> element("#mobile-menu-button") |> render_click()

    assert has_element?(
             view,
             "#mobile-menu-button[aria-expanded='true'][aria-label='Close menu']"
           )

    assert has_element?(view, "#mobile-sidebar-backdrop")

    view |> element("#mobile-sidebar-backdrop") |> render_click()

    refute has_element?(view, "#mobile-sidebar-backdrop")
  end
end
