defmodule WebApp.Automations.Subscription do
  use GenServer

  require Logger

  alias WebApp.Automations
  alias WebApp.Automations.Scheduler

  @poll_interval 1_000

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    :ok = Phoenix.PubSub.subscribe(WebApp.PubSub, "automations")
    automations = Automations.list()
    apply(automations)
    schedule_poll()
    {:ok, fingerprint(automations)}
  end

  @impl true
  def handle_info(:changed, _fingerprint) do
    automations = Automations.list()
    apply(automations)
    {:noreply, fingerprint(automations)}
  end

  def handle_info(:poll, previous_fingerprint) do
    automations = Automations.list()
    current_fingerprint = fingerprint(automations)
    if current_fingerprint != previous_fingerprint, do: apply(automations)
    schedule_poll()
    {:noreply, current_fingerprint}
  end

  defp apply(automations) do
    case Scheduler.replace(automations) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Could not refresh automations", reason: reason)
    end
  end

  defp fingerprint(automations), do: :erlang.phash2(automations)
  defp schedule_poll, do: Process.send_after(self(), :poll, @poll_interval)
end
