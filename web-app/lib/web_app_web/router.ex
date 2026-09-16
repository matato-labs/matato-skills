defmodule WebAppWeb.Router do
  use WebAppWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WebAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :dashboard_auth do
    plug :authenticate_dashboard
  end

  scope "/", WebAppWeb do
    pipe_through :browser

    live "/", SessionLive, :index
    live "/sessions/:id", AgentLive, :show
    live "/bots/:bot_id", AgentLive, :show
  end

  scope "/api", WebAppWeb do
    pipe_through :api

    resources "/automations", AutomationController,
      only: [:index, :show, :create, :update, :delete]

    resources "/bots", BotController, only: [:index, :show, :create, :update, :delete]
  end

  # Runtime observability dashboard. Available in every environment but
  # protected by HTTP basic auth. Credentials come from the DASHBOARD_USERNAME
  # and DASHBOARD_PASSWORD environment variables; without them the route
  # responds with 404. Destructive dashboard actions stay disabled.
  scope "/" do
    pipe_through [:browser, :dashboard_auth]

    live_dashboard "/dashboard",
      metrics: WebAppWeb.Telemetry,
      ecto_repos: [WebApp.Repo],
      allow_destructive_actions: false
  end

  defp authenticate_dashboard(conn, _opts) do
    case Application.get_env(:web_app, :dashboard_auth) do
      nil ->
        conn |> send_resp(:not_found, "Not found") |> halt()

      credentials ->
        Plug.BasicAuth.basic_auth(conn, credentials)
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:web_app, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: WebAppWeb.Telemetry,
        ecto_repos: [WebApp.Repo],
        live_session_name: :dev_dashboard

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
