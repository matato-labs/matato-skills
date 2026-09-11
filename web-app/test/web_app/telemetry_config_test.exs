defmodule WebApp.TelemetryConfigTest do
  use ExUnit.Case

  test "disables telemetry outside production" do
    assert runtimeConfig("test", "http://collector:4318") == "{:none, nil, nil, nil}"
    assert runtimeConfig("dev", "http://collector:4318") == "{:none, nil, nil, nil}"
  end

  test "disables production telemetry when OTEL_ENDPOINT is blank" do
    assert runtimeConfig("prod", "   ") == "{:none, nil, nil, nil}"
  end

  test "configures production OTLP HTTP export at OTEL_ENDPOINT" do
    assert runtimeConfig("prod", "http://collector:4318") ==
             "{:otlp, :http_protobuf, \"http://collector:4318\", \"http://collector:4318\"}"
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

  defp runtimeConfig(environment_name, endpoint) do
    expression =
      "IO.inspect({Application.get_env(:opentelemetry, :traces_exporter), Application.get_env(:opentelemetry_exporter, :otlp_protocol), Application.get_env(:opentelemetry_exporter, :otlp_endpoint), Application.get_env(:web_app, :otel_endpoint)})"

    environment = [
      {"MIX_ENV", environment_name},
      {"OTEL_ENDPOINT", endpoint},
      {"WORKSPACE", System.tmp_dir!()},
      {"SECRET_KEY_BASE", "test-secret-key-base"},
      {"PHX_HOST", "example.com"}
    ]

    {output, 0} = System.cmd("mix", ["run", "--no-start", "-e", expression], env: environment)
    output |> String.trim() |> String.split("\n") |> List.last()
  end
end
