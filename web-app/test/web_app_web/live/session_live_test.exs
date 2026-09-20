defmodule WebAppWeb.SessionLiveTest do
  use WebAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "rejects malformed project values without terminating the page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_submit(view, "start", %{"session" => %{"project" => %{}}})

    assert has_element?(view, "[class*='text-error']", "Invalid session submission")

    assert {:noreply, socket} =
             WebAppWeb.SessionLive.handle_event(
               "start",
               %{"session" => %{"project" => %{}}},
               %Phoenix.LiveView.Socket{}
             )

    assert socket.assigns.error == "Invalid session submission"
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
