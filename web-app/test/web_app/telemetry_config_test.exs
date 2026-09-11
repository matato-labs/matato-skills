defmodule WebApp.TelemetryConfigTest do
  use ExUnit.Case, async: true

  test "exports traces to the local collector when OTEL_ENDPOINT is absent" do
    assert runtimeConfig(nil) == "{:otlp, :http_protobuf, \"http://localhost:4318\"}"
  end

  test "disables trace export when OTEL_ENDPOINT is blank" do
    assert runtimeConfig("   ") == "{:none, nil, nil}"
  end

  test "configures OTLP HTTP export at OTEL_ENDPOINT" do
    assert runtimeConfig("http://collector:4318") ==
             "{:otlp, :http_protobuf, \"http://collector:4318\"}"
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

  defp runtimeConfig(endpoint) do
    expression =
      "IO.inspect({Application.get_env(:opentelemetry, :traces_exporter), Application.get_env(:opentelemetry_exporter, :otlp_protocol), Application.get_env(:opentelemetry_exporter, :otlp_endpoint)})"

    environment = [{"MIX_ENV", "test"}, {"OTEL_ENDPOINT", endpoint}]
    {output, 0} = System.cmd("mix", ["run", "--no-start", "-e", expression], env: environment)
    String.trim(output)
  end
end
