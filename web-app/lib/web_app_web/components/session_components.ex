defmodule WebAppWeb.SessionComponents do
  use WebAppWeb, :html

  attr :sessions, :list, required: true
  attr :session_id, :string, default: nil

  def sidebar(assigns) do
    ~H"""
    <aside class="overflow-y-auto border-b border-base-content/10 bg-base-200 lg:border-r lg:border-b-0">
      <div class="flex items-center gap-3 px-5 py-5">
        <div class="grid size-8 place-items-center rounded-lg bg-primary text-primary-content">
          <.icon name="hero-command-line" class="size-4" />
        </div>
        <p class="text-sm font-semibold tracking-tight">Matato Agent</p>
      </div>

      <div class="border-t border-base-content/10 px-3 py-4">
        <div class="mb-2 flex items-center justify-between px-2">
          <h2 class="text-[0.68rem] font-semibold uppercase tracking-[0.16em] text-base-content/45">
            Sessions
          </h2>
          <.link
            navigate={~p"/"}
            class="rounded-md p-1 text-base-content/45 hover:bg-base-content/5 hover:text-base-content"
            aria-label="New session"
          >
            <.icon name="hero-plus" class="size-4" />
          </.link>
        </div>
        <nav class="flex gap-2 overflow-x-auto lg:block lg:space-y-1" aria-label="Agent sessions">
          <.link
            :for={item <- @sessions}
            navigate={~p"/sessions/#{item["id"]}"}
            class={[
              "flex min-w-48 items-center gap-2 rounded-lg px-2.5 py-2 text-sm transition-colors lg:min-w-0",
              item["id"] == @session_id && "bg-base-content/8 text-base-content",
              item["id"] != @session_id &&
                "text-base-content/55 hover:bg-base-content/5 hover:text-base-content/80"
            ]}
          >
            <span class={[
              "size-1.5 shrink-0 rounded-full",
              item["status"] in ["starting", "working", "retrying", "compacting"] && "bg-warning",
              item["status"] in ["interrupted", "failed"] && "bg-error",
              item["status"] in ["stopped", "waiting_for_input"] && "bg-base-content/35",
              item["status"] == "settled" && "bg-success/70"
            ]}></span>
            <span class="truncate">{item["name"]}</span>
          </.link>
          <p :if={@sessions == []} class="px-2 py-3 text-xs leading-5 text-base-content/40">
            No sessions yet.
          </p>
        </nav>
      </div>
    </aside>
    """
  end
end
