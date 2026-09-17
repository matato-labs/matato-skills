defmodule WebAppWeb.DashboardTest do
  use WebAppWeb.ConnCase, async: false

  test "redirects /dashboard to the home page", %{conn: conn} do
    conn = get(conn, "/dashboard")

    assert redirected_to(conn) == "/dashboard/home"
  end

  test "renders the dashboard", %{conn: conn} do
    conn = get(conn, "/dashboard/home")

    assert html_response(conn, 200) =~ "LiveDashboard"
  end
end
