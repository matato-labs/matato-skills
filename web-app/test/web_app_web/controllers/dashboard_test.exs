defmodule WebAppWeb.DashboardTest do
  use WebAppWeb.ConnCase, async: false

  @credentials [username: "admin", password: "dashboard-secret"]

  test "rejects unauthenticated access", %{conn: conn} do
    conn = get(conn, "/dashboard")

    assert conn.status == 401
    assert get_resp_header(conn, "www-authenticate") != []
  end

  test "rejects invalid credentials", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Basic " <> Base.encode64("admin:wrong"))
      |> get("/dashboard")

    assert conn.status == 401
  end

  test "renders the dashboard with valid credentials", %{conn: conn} do
    credentials = Base.encode64("#{@credentials[:username]}:#{@credentials[:password]}")

    conn =
      conn
      |> put_req_header("authorization", "Basic " <> credentials)
      |> get("/dashboard")

    assert redirected_to(conn) == "/dashboard/home"

    conn =
      build_conn()
      |> put_req_header("authorization", "Basic " <> credentials)
      |> get("/dashboard/home")

    assert html_response(conn, 200) =~ "LiveDashboard"
  end

  test "responds with not found when credentials are not configured", %{conn: conn} do
    Application.delete_env(:web_app, :dashboard_auth)
    on_exit(fn -> Application.put_env(:web_app, :dashboard_auth, @credentials) end)

    assert conn |> get("/dashboard") |> response(404)
  end
end
