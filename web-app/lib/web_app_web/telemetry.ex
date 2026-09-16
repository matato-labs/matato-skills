defmodule WebAppWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://telemetry-metrics.hexdocs.pm
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # LiveView Metrics
      summary("phoenix.live_view.mount.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.mount.exception.duration",
        tags: [:exception],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_event.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_event.exception.duration",
        tags: [:event, :exception],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_component.handle_event.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_component.handle_event.stop.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_component.handle_event.exception.duration",
        tags: [:event, :exception],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("web_app.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("web_app.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("web_app.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("web_app.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("web_app.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # Automation Metrics
      counter("web_app.automation.run.count",
        tags: [:result],
        description: "The number of automation runs by result"
      ),
      summary("web_app.automation.run.duration",
        tags: [:result],
        unit: {:native, :millisecond},
        description: "The time spent executing an automation run"
      ),

      # Agent Session Metrics
      counter("web_app.agent_session.start.count",
        description: "The number of agent sessions started"
      ),
      counter("web_app.agent_session.stop.count",
        description: "The number of agent sessions stopped"
      ),
      summary("web_app.agent_session.stop.duration",
        unit: {:native, :second},
        description: "The lifetime of an agent session"
      ),
      counter("web_app.agent_session.prompt.count",
        tags: [:type],
        description: "The number of prompts sent to agent sessions by command type"
      ),

      # Runtime Metrics
      last_value("web_app.agent_sessions.active",
        description: "The number of currently running agent sessions"
      ),
      last_value("web_app.messages.pending",
        description: "The number of messages waiting for delivery"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  def measure_agent_sessions do
    count =
      case Process.whereis(WebApp.AgentSupervisor) do
        nil -> 0
        _pid -> DynamicSupervisor.count_children(WebApp.AgentSupervisor).active
      end

    :telemetry.execute([:web_app, :agent_sessions], %{active: count})
  end

  def measure_pending_messages do
    :telemetry.execute([:web_app, :messages], %{pending: WebApp.Messages.count_pending()})
  rescue
    # The Repo may be unavailable or sandbox-owned (for example in tests);
    # skip the measurement instead of crashing the poller.
    _error -> :ok
  end

  defp periodic_measurements do
    [
      {__MODULE__, :measure_agent_sessions, []},
      {__MODULE__, :measure_pending_messages, []}
    ]
  end
end
