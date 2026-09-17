defmodule WebAppWeb.TelemetryTest do
  use ExUnit.Case, async: false

  alias WebAppWeb.Telemetry

  defp metric_names do
    MapSet.new(Telemetry.metrics(), fn metric -> Enum.join(metric.name, ".") end)
  end

  test "includes Phoenix endpoint and router metrics" do
    names = metric_names()

    assert "phoenix.endpoint.stop.duration" in names
    assert "phoenix.router_dispatch.start.system_time" in names
    assert "phoenix.router_dispatch.stop.duration" in names
    assert "phoenix.router_dispatch.exception.duration" in names
  end

  test "includes LiveView mount and handle event metrics" do
    names = metric_names()

    assert "phoenix.live_view.mount.start.system_time" in names
    assert "phoenix.live_view.mount.stop.duration" in names
    assert "phoenix.live_view.mount.exception.duration" in names
    assert "phoenix.live_view.handle_event.stop.duration" in names
    assert "phoenix.live_view.handle_event.exception.duration" in names
    assert "phoenix.live_component.handle_event.stop.duration" in names
  end

  test "includes Ecto query timing metrics" do
    names = metric_names()

    assert "web_app.repo.query.total_time" in names
    assert "web_app.repo.query.query_time" in names
    assert "web_app.repo.query.decode_time" in names
    assert "web_app.repo.query.queue_time" in names
    assert "web_app.repo.query.idle_time" in names
  end

  test "includes VM metrics collected by telemetry poller" do
    names = metric_names()

    assert "vm.memory.total" in names
    assert "vm.total_run_queue_lengths.total" in names
    assert "vm.total_run_queue_lengths.cpu" in names
    assert "vm.total_run_queue_lengths.io" in names
  end
end
