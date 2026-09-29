defmodule WebApp do
  use Boundary,
    deps: [WebApp.Automations, WebApp.Data, WebApp.Sessions],
    exports: []

  def prepare do
    Calendar.put_time_zone_database(Tzdata.TimeZoneDatabase)
    WebApp.Sessions.validate_workspace!()
    Logger.add_handlers(:web_app)
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit, liveview: true)
  end

  def child_specs(endpoint) do
    log_exporter = if endpoint, do: [{WebApp.OtelLogExporter, endpoint}], else: []

    log_exporter ++
      [
        {DNSCluster, query: Application.get_env(:web_app, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: WebApp.PubSub}
      ] ++
      WebApp.Data.child_specs() ++
      WebApp.Sessions.child_specs() ++
      WebApp.Automations.child_specs()
  end

  def enable_log_exporter(endpoint) do
    if endpoint, do: LoggerBackends.add(WebApp.OtelLoggerBackend)
    :ok
  end
end
