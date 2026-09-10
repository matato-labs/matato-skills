defmodule WebApp.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    WebApp.Workspace.validate!()
    OpentelemetryPhoenix.setup(adapter: :bandit, liveview: true)

    children = [
      WebAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:web_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WebApp.PubSub},
      {Registry, keys: :unique, name: WebApp.ProcessRegistry},
      {Registry, keys: :duplicate, name: WebApp.SubscriberRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: WebApp.AgentSupervisor},
      WebApp.RemoteRegistry,
      WebApp.AutomationScheduler,
      WebApp.AutomationWatcher,
      WebAppWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WebApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WebAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
