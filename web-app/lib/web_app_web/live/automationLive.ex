defmodule WebAppWeb.AutomationLive do
  use WebAppWeb, :live_view

  alias WebApp.{Automations, Sessions}

  @page_size 10

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Automations.subscribe()
      Sessions.subscribe()
    end

    {:ok,
     assign(socket,
       automation_id: nil,
       automation: nil,
       runs: [],
       run_count: 0,
       page: 1,
       page_count: 1,
       error: nil
     )}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    {:noreply,
     socket
     |> assign(automation_id: id, page: page_number(params["page"]))
     |> load_automation()}
  end

  @impl true
  def handle_info(:changed, socket), do: {:noreply, load_automation(socket)}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="min-h-screen bg-base-300 text-base-content">
        <header class="border-b border-base-content/10 px-5 py-4 lg:px-8">
          <div class="mx-auto flex max-w-6xl items-center gap-4">
            <.link
              navigate="/"
              class="grid size-9 shrink-0 place-items-center rounded-lg text-base-content/55 transition-colors hover:bg-base-content/8 hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
              aria-label="Back to sessions"
            >
              <.icon name="hero-arrow-left" class="size-4" />
            </.link>
            <div class="min-w-0 flex-1">
              <p class="text-[0.68rem] font-semibold uppercase tracking-[0.16em] text-base-content/45">
                Automation
              </p>
              <h1 class="truncate text-base font-semibold tracking-tight">
                {if @automation, do: @automation.job_name, else: "Automation unavailable"}
              </h1>
            </div>
            <span
              :if={@automation}
              class={[
                "rounded-full px-2.5 py-1 text-xs font-semibold",
                if(@automation.enabled,
                  do: "bg-success/10 text-success",
                  else: "bg-base-content/8 text-base-content/50"
                )
              ]}
            >
              {if @automation.enabled, do: "Enabled", else: "Disabled"}
            </span>
          </div>
        </header>

        <section class="px-5 py-8 lg:px-8">
          <div class="mx-auto max-w-6xl">
            <div
              :if={@error}
              id="automation-error"
              class="rounded-lg border border-error/30 bg-error/8 px-4 py-3 text-sm text-error"
              role="alert"
            >
              {@error}
            </div>

            <section :if={@automation} aria-labelledby="runs-heading">
              <div class="mb-5 flex items-end justify-between gap-4">
                <div>
                  <h2 id="runs-heading" class="text-sm font-semibold">Run history</h2>
                  <p class="mt-1 text-xs text-base-content/45">
                    {run_count_label(@run_count)}
                  </p>
                </div>
              </div>

              <div
                :if={@runs == []}
                id="automation-runs-empty"
                class="border-y border-base-content/10 py-16 text-center"
              >
                <h3 class="text-sm font-semibold">No runs yet</h3>
                <p class="mt-1 text-sm text-base-content/45">
                  Runs will appear here after this automation starts.
                </p>
              </div>

              <div :if={@runs != []} class="overflow-x-auto border-y border-base-content/10">
                <table id="automation-runs" class="w-full min-w-[42rem] text-left text-sm">
                  <thead class="text-[0.68rem] font-semibold uppercase tracking-[0.12em] text-base-content/40">
                    <tr>
                      <th class="px-3 py-3" scope="col">Status</th>
                      <th class="px-3 py-3" scope="col">Started</th>
                      <th class="px-3 py-3" scope="col">Last activity</th>
                      <th class="w-10 px-3 py-3" scope="col"><span class="sr-only">Open</span></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-base-content/10">
                    <tr :for={run <- @runs} id={"automation-run-#{run["id"]}"} class="group">
                      <td class="px-3 py-3.5">
                        <span class={[
                          "inline-flex rounded-full px-2 py-1 text-xs font-semibold",
                          status_class(run["status"])
                        ]}>
                          {status_label(run["status"])}
                        </span>
                      </td>
                      <td class="px-3 py-3.5 text-base-content/70">
                        {format_time(run["created_at"])}
                      </td>
                      <td class="px-3 py-3.5 text-base-content/50">
                        {format_time(run["updated_at"])}
                      </td>
                      <td class="px-3 py-3.5">
                        <.link
                          navigate={"/automation-runs/#{run["id"]}"}
                          class="grid size-8 place-items-center rounded-md text-base-content/40 transition-colors group-hover:bg-base-content/5 group-hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
                          aria-label={"Open run from #{format_time(run["created_at"])}"}
                        >
                          <.icon name="hero-chevron-right" class="size-4" />
                        </.link>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <nav
                :if={@page_count > 1}
                id="automation-pagination"
                class="mt-5 flex items-center justify-between gap-4"
                aria-label="Run history pages"
              >
                <.link
                  patch={page_path(@automation.id, max(@page - 1, 1))}
                  class={[
                    "btn btn-sm btn-ghost",
                    @page == 1 && "pointer-events-none opacity-40"
                  ]}
                  aria-disabled={to_string(@page == 1)}
                >
                  <.icon name="hero-chevron-left" class="size-4" /> Previous
                </.link>
                <span class="text-xs text-base-content/45">Page {@page} of {@page_count}</span>
                <.link
                  patch={page_path(@automation.id, min(@page + 1, @page_count))}
                  class={[
                    "btn btn-sm btn-ghost",
                    @page == @page_count && "pointer-events-none opacity-40"
                  ]}
                  aria-disabled={to_string(@page == @page_count)}
                >
                  Next <.icon name="hero-chevron-right" class="size-4" />
                </.link>
              </nav>
            </section>
          </div>
        </section>
      </main>
    </Layouts.app>
    """
  end

  def status_label("settled"), do: "Finished"

  def status_label(status)
      when status in ["starting", "working", "waiting_for_input", "retrying", "compacting"],
      do: "Working"

  def status_label(_status), do: "Failed"

  def status_class("settled"), do: "bg-success/10 text-success"

  def status_class(status)
      when status in ["starting", "working", "waiting_for_input", "retrying", "compacting"],
      do: "bg-warning/10 text-warning"

  def status_class(_status), do: "bg-error/10 text-error"

  def format_time(nil), do: "Not available"

  def format_time(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> Calendar.strftime(datetime, "%b %-d, %Y at %H:%M")
      _result -> timestamp
    end
  end

  def run_count_label(1), do: "1 run"
  def run_count_label(count), do: "#{count} runs"

  def page_path(id, 1), do: "/automations/#{id}"
  def page_path(id, page), do: "/automations/#{id}?page=#{page}"

  defp page_number(nil), do: 1

  defp page_number(value) do
    case Integer.parse(value) do
      {page, ""} when page > 0 -> page
      _result -> 1
    end
  end

  defp load_automation(socket) do
    with {id, ""} <- Integer.parse(socket.assigns.automation_id),
         %Automations{} = automation <- Automations.get(id) do
      all_runs = Sessions.automation_runs(Sessions.list(), automation.job_name)
      run_count = length(all_runs)
      page_count = max(div(run_count + @page_size - 1, @page_size), 1)
      page = min(socket.assigns.page, page_count)
      runs = Enum.slice(all_runs, (page - 1) * @page_size, @page_size)

      assign(socket,
        page_title: "#{automation.job_name} · Automation",
        automation: automation,
        runs: runs,
        run_count: run_count,
        page: page,
        page_count: page_count,
        error: nil
      )
    else
      _result ->
        assign(socket,
          page_title: "Automation unavailable",
          automation: nil,
          runs: [],
          run_count: 0,
          page: 1,
          page_count: 1,
          error: "Automation not found"
        )
    end
  end
end
