defmodule WebApp.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Calendar.put_time_zone_database(Tzdata.TimeZoneDatabase)
    WebApp.Workspace.validate!()
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit, liveview: true)

    endpoint = Application.get_env(:web_app, :otel_endpoint)

    log_exporter = if endpoint, do: [{WebApp.OtelLogExporter, endpoint}], else: []

    children =
      log_exporter ++
        [
          WebAppWeb.Telemetry,
          {DNSCluster, query: Application.get_env(:web_app, :dns_cluster_query) || :ignore},
          {Phoenix.PubSub, name: WebApp.PubSub},
          {Registry, keys: :unique, name: WebApp.ProcessRegistry},
          {Registry, keys: :duplicate, name: WebApp.SubscriberRegistry},
          {DynamicSupervisor, strategy: :one_for_one, name: WebApp.AgentSupervisor},
          WebApp.Repo,
          WebApp.RemoteRegistry,
          WebApp.MessageWorker,
          WebApp.MessageDeliveryScheduler,
          WebApp.AutomationScheduler,
          WebApp.AutomationSubscription,
          WebAppWeb.Endpoint
        ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WebApp.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        if endpoint, do: LoggerBackends.add(WebApp.OtelLoggerBackend)
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
