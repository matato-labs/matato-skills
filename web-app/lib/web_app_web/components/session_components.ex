defmodule WebAppWeb.SessionComponents do
  use Phoenix.Component

  import WebAppWeb.CoreComponents

  attr :workspace_groups, :list, required: true
  attr :automation_groups, :list, required: true
  attr :session_id, :string, default: nil
  attr :delete_session_id, :string, default: nil
  attr :mobile_sidebar_open, :boolean, required: true

  def sidebar(assigns) do
    ~H"""
    <aside
      id="session-sidebar"
      class={[
        "fixed inset-y-0 left-0 z-30 w-72 overflow-y-auto border-r border-base-content/10 bg-base-200 shadow-2xl transition-transform duration-200 ease-out lg:static lg:z-auto lg:w-auto lg:translate-x-0 lg:shadow-none",
        !@mobile_sidebar_open && "-translate-x-full"
      ]}
    >
      <div class="flex items-center justify-between gap-3 px-5 py-5">
        <div class="flex items-center gap-3">
          <div class="grid size-8 place-items-center rounded-lg bg-primary text-primary-content">
            <.icon name="hero-command-line" class="size-4" />
          </div>
          <p class="text-sm font-semibold tracking-tight">Matato Agent</p>
        </div>
        <button
          type="button"
          phx-click="close_mobile_sidebar"
          class="grid size-8 place-items-center rounded-md text-base-content/50 transition-colors hover:bg-base-content/8 hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary lg:hidden"
          aria-label="Close menu"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>

      <div class="border-t border-base-content/10 px-3 py-4">
        <div class="mb-2 flex items-center justify-between px-2">
          <h2 class="text-[0.68rem] font-semibold uppercase tracking-[0.16em] text-base-content/45">
            Workspace
          </h2>
          <.link
            navigate="/"
            class="rounded-md p-1 text-base-content/45 transition-colors hover:bg-base-content/5 hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
            aria-label="New session"
          >
            <.icon name="hero-plus" class="size-4" />
          </.link>
        </div>

        <nav id="workspace-session-groups" class="space-y-1.5" aria-label="Workspace agent sessions">
          <.session_group
            :for={group <- @workspace_groups}
            group={group}
            prefix="workspace"
            session_id={@session_id}
            delete_session_id={@delete_session_id}
          />
          <p :if={@workspace_groups == []} class="px-2 py-3 text-xs leading-5 text-base-content/40">
            No sessions yet.
          </p>
        </nav>

        <div class="mt-5 border-t border-base-content/10 pt-4">
          <h2 class="mb-2 px-2 text-[0.68rem] font-semibold uppercase tracking-[0.16em] text-base-content/45">
            Automations
          </h2>
          <nav id="automation-session-groups" class="space-y-1.5" aria-label="Active automation work">
            <.session_group
              :for={group <- @automation_groups}
              group={group}
              prefix="automation"
              session_id={@session_id}
              delete_session_id={@delete_session_id}
            />
            <p :if={@automation_groups == []} class="px-2 py-1 text-xs leading-5 text-base-content/40">
              No active work.
            </p>
          </nav>
        </div>
      </div>
    </aside>
    """
  end

  attr :group, :map, required: true
  attr :prefix, :string, required: true
  attr :session_id, :string, default: nil
  attr :delete_session_id, :string, default: nil

  defp session_group(assigns) do
    ~H"""
    <details id={"#{@prefix}-session-group-#{@group.key}"} open class="group">
      <summary class="flex cursor-pointer list-none items-center gap-2 rounded-md px-2 py-1.5 text-xs font-semibold text-base-content/55 transition-colors hover:bg-base-content/5 hover:text-base-content focus:outline-none focus-visible:ring-2 focus-visible:ring-primary">
        <.icon
          name="hero-chevron-right"
          class="size-3 shrink-0 transition-transform group-open:rotate-90"
        />
        <span class="truncate">{@group.label}</span>
      </summary>
      <div class="mt-0.5 space-y-0.5 pl-2">
        <.session_row
          :for={session <- @group.sessions}
          session={session}
          selected={session.id == @session_id}
          delete_session_id={@delete_session_id}
        />
      </div>
    </details>
    """
  end

  attr :mobile_sidebar_open, :boolean, required: true

  def mobile_header(assigns) do
    ~H"""
    <header class="flex min-h-16 shrink-0 items-center gap-3 border-b border-base-content/10 px-5 lg:hidden">
      <button
        id="mobile-menu-button"
        type="button"
        phx-click="toggle_mobile_sidebar"
        class="grid size-9 place-items-center rounded-md text-base-content/65 transition-colors hover:bg-base-content/8 hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
        aria-controls="session-sidebar"
        aria-expanded={to_string(@mobile_sidebar_open)}
        aria-label={if @mobile_sidebar_open, do: "Close menu", else: "Open menu"}
      >
        <.icon name="hero-bars-3" class="size-5" />
      </button>
      <p class="text-sm font-semibold tracking-tight">Matato Agent</p>
    </header>
    """
  end

  attr :session, :map, required: true
  attr :selected, :boolean, required: true
  attr :delete_session_id, :string, default: nil

  defp session_row(assigns) do
    ~H"""
    <div id={"session-#{@session.id}"} class={session_row_class(@selected)}>
      <.link
        :if={@session.source == "web"}
        navigate={"/sessions/#{@session.id}"}
        class="flex min-w-0 flex-1 items-center gap-2"
      >
        <.session_row_content session={@session} />
      </.link>
      <.session_row_content :if={@session.source != "web"} session={@session} />
      <button
        :if={@session.source == "web" && @delete_session_id != @session.id}
        id={"delete-session-#{@session.id}"}
        type="button"
        phx-click="confirm_delete_session"
        phx-value-id={@session.id}
        class="grid size-7 shrink-0 place-items-center rounded-md text-base-content/35 transition-colors hover:bg-error/10 hover:text-error focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
        aria-label={"Delete #{@session.title}"}
      >
        <.icon name="hero-trash" class="size-3.5" />
      </button>
      <button
        :if={@session.source == "web" && @delete_session_id == @session.id}
        id={"confirm-delete-session-#{@session.id}"}
        type="button"
        phx-click="delete_session"
        phx-value-id={@session.id}
        class="grid size-7 shrink-0 place-items-center rounded-md bg-error/15 text-error transition-colors hover:bg-error/25 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
        aria-label={"Confirm deletion of #{@session.title}"}
      >
        <.icon name="hero-check" class="size-3.5" />
      </button>
    </div>
    """
  end

  attr :session, :map, required: true

  defp session_row_content(assigns) do
    ~H"""
    <span class={["size-1.5 shrink-0 rounded-full", status_color(@session.status)]}></span>
    <span class="min-w-0 flex-1 truncate">{@session.title}</span>
    <span
      :if={@session.source != "web"}
      class="rounded bg-base-content/8 px-1 py-0.5 text-[0.6rem] font-medium uppercase tracking-wide text-base-content/45"
    >
      {@session.source}
    </span>
    <span class="sr-only">{status_label(@session.status)}</span>
    """
  end

  def status_label("waiting_for_input"), do: "Waiting for input"
  def status_label(status), do: status |> String.replace("_", " ") |> String.capitalize()

  def status_color(status) when status in ["starting", "working", "retrying", "compacting"],
    do: "bg-warning"

  def status_color(status) when status in ["interrupted", "failed"], do: "bg-error"

  def status_color(status) when status in ["stopped", "waiting_for_input"],
    do: "bg-base-content/35"

  def status_color("settled"), do: "bg-success/70"
  def status_color(_status), do: "bg-base-content/35"

  defp session_row_class(selected) do
    [
      "flex min-w-0 items-center gap-2 rounded-lg px-2.5 py-2 text-sm transition-colors",
      selected && "bg-base-content/8 text-base-content",
      !selected && "text-base-content/55 hover:bg-base-content/5 hover:text-base-content/80"
    ]
  end
end
