defmodule WebAppWeb.AutomationRunLive do
  use WebAppWeb, :live_view

  alias WebApp.{Automations, Sessions}
  alias WebAppWeb.AgentTranscript

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Sessions.subscribe()

    socket =
      socket
      |> assign(
        page_title: "Automation run",
        run_id: id,
        run: nil,
        automation_path: "/",
        transcript: nil,
        transcript_available?: false,
        bot_owned?: false,
        expanded_work_ids: MapSet.new(),
        error: nil
      )
      |> stream(:messages, [])
      |> load_run()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_work", %{"id" => id, "open" => "true"}, socket) do
    expanded = MapSet.put(socket.assigns.expanded_work_ids, id)
    {:noreply, socket |> assign(expanded_work_ids: expanded) |> load_run()}
  end

  def handle_event("toggle_work", %{"id" => id, "open" => "false"}, socket) do
    expanded = MapSet.delete(socket.assigns.expanded_work_ids, id)
    {:noreply, socket |> assign(expanded_work_ids: expanded) |> load_run()}
  end

  def handle_event("message_copied", _params, socket),
    do: {:noreply, put_flash(socket, :info, "Message copied")}

  def handle_event("message_copy_failed", _params, socket),
    do: {:noreply, put_flash(socket, :error, "Message could not be copied")}

  def handle_event("retry", _params, %{assigns: %{run: %{"status" => "failed"} = run}} = socket) do
    case Enum.find(Automations.list(), &(&1.job_name == run["name"])) do
      nil ->
        {:noreply, put_flash(socket, :error, "Automation is no longer available")}

      automation ->
        Automations.run(automation)
        {:noreply, put_flash(socket, :info, "Automation retry started")}
    end
  end

  def handle_event("retry", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:changed, socket), do: {:noreply, load_run(socket)}

  defdelegate transcript_item(assigns), to: AgentTranscript
  defdelegate markdown(text), to: AgentTranscript
  defdelegate work_label(item), to: AgentTranscript
  defdelegate tool_status(tool), to: AgentTranscript
  defdelegate tool_output(tool), to: AgentTranscript
  defdelegate tool_result(result), to: AgentTranscript

  def status_label("settled"), do: "Finished"
  def status_label("waiting_for_input"), do: "Working"

  def status_label(status) when status in ["starting", "working", "retrying", "compacting"],
    do: "Working"

  def status_label(_status), do: "Failed"

  def status_class("settled"), do: "bg-success/10 text-success"

  def status_class(status)
      when status in ["starting", "working", "waiting_for_input", "retrying", "compacting"],
      do: "bg-warning/10 text-warning"

  def status_class(_status), do: "bg-error/10 text-error"

  defp load_run(socket) do
    case Sessions.get(socket.assigns.run_id) do
      %{"source" => "automation"} = run ->
        load_transcript(socket, run)

      _run ->
        assign(socket,
          run: nil,
          transcript: nil,
          transcript_available?: false,
          error: "Automation run not found"
        )
    end
  end

  defp load_transcript(socket, run) do
    if bot_owned?(run) do
      socket
      |> assign(
        page_title: "#{run["name"]} · Automation run",
        run: run,
        automation_path: automation_path(run),
        transcript: nil,
        transcript_available?: false,
        bot_owned?: true,
        error: nil
      )
      |> stream(:messages, [], reset: true)
    else
      load_workspace_transcript(socket, run)
    end
  end

  defp load_workspace_transcript(socket, run) do
    case Sessions.load_automation_transcript(run) do
      {:ok, transcript} ->
        items =
          transcript
          |> AgentTranscript.transcript_items()
          |> AgentTranscript.mark_expanded_work(socket.assigns.expanded_work_ids)

        socket
        |> assign(
          page_title: "#{run["name"]} · Automation run",
          run: run,
          automation_path: automation_path(run),
          transcript: transcript,
          transcript_available?: true,
          bot_owned?: false,
          error: nil
        )
        |> stream(:messages, items, reset: true)

      {:error, :unavailable} ->
        socket
        |> assign(
          page_title: "#{run["name"]} · Automation run",
          run: run,
          automation_path: automation_path(run),
          transcript: nil,
          transcript_available?: false,
          bot_owned?: false,
          error: nil
        )
        |> stream(:messages, [], reset: true)
    end
  end

  defp bot_owned?(run) do
    case Enum.find(Automations.list(), &(&1.job_name == run["name"])) do
      %{bot_id: bot_id} when not is_nil(bot_id) -> true
      _ -> false
    end
  end

  defp automation_path(run) do
    case Enum.find(Automations.list(), &(&1.job_name == run["name"])) do
      nil -> "/"
      automation -> "/automations/#{automation.id}"
    end
  end
end
