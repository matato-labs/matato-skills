defmodule WebApp.TelemetryConfigTest do
  use ExUnit.Case, async: true

  test "does not configure telemetry in the test environment" do
    assert Application.get_env(:opentelemetry, :traces_exporter) == :none
    assert Application.get_env(:web_app, :otel_endpoint) == nil
  end

  test "instruments Bandit HTTP and Phoenix LiveView events" do
    assert %{id: {OpentelemetryBandit, _}} =
             Enum.find(
               :telemetry.list_handlers([:bandit, :request, :start]),
               &match?(%{id: {OpentelemetryBandit, _}}, &1)
             )

    assert %{id: {OpentelemetryPhoenix, :live_view}} =
             Enum.find(
               :telemetry.list_handlers([:phoenix, :live_view, :mount, :start]),
               &match?(%{id: {OpentelemetryPhoenix, :live_view}}, &1)
             )
  end
end
