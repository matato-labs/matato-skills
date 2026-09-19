defmodule WebApp.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Boundary, top_level?: true, deps: [WebApp, WebAppWeb], exports: []
  use Application

  @impl true
  def start(_type, _args) do
    WebApp.prepare()
    endpoint = Application.get_env(:web_app, :otel_endpoint)
    children = WebApp.child_specs(endpoint) ++ WebAppWeb.child_specs()

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WebApp.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        WebApp.enable_log_exporter(endpoint)
        {:ok, pid}

      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WebAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
