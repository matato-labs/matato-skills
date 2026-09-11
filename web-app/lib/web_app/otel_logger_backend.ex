defmodule WebApp.OtelLoggerBackend do
  @behaviour :gen_event

  @impl true
  def init(__MODULE__), do: {:ok, __MODULE__}

  @impl true
  def handle_event({level, _group_leader, {Logger, message, _timestamp, _metadata}}, state) do
    WebApp.OtelLogExporter.export(level, message)
    {:ok, state}
  end

  def handle_event(_event, state), do: {:ok, state}

  @impl true
  def handle_call(_request, state), do: {:ok, :ok, state}

  @impl true
  def handle_info(_message, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok

  @impl true
  def code_change(_old_version, state, _extra), do: {:ok, state}
end
