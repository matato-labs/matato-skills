defmodule WebAppWeb.SessionComponents do
  use Phoenix.Component

  import WebAppWeb.CoreComponents

  attr :workspace_groups, :list, required: true
  attr :automation_groups, :list, required: true
  attr :bots, :list, default: []
  attr :sessions, :list, default: []
  attr :session_id, :string, default: nil
  attr :bot_id, :string, default: nil
  attr :delete_session_id, :string, default: nil
  attr :delete_bot_id, :string, default: nil
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
            Bots
          </h2>
          <button
            id="new-bot-button"
            type="button"
            phx-click="show_bot_form"
            class="rounded-md p-1 text-base-content/45 transition-colors hover:bg-base-content/5 hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
            aria-label="Create bot"
          >
            <.icon name="hero-plus" class="size-4" />
          </button>
        </div>
        <nav id="bots" class="space-y-0.5" aria-label="Bots">
          <.bot_row
            :for={bot <- @bots}
            bot={bot}
            status={bot_status(bot, @sessions)}
            selected={bot.id == @bot_id}
            delete_bot_id={@delete_bot_id}
          />
          <p :if={@bots == []} class="px-2 py-1 text-xs leading-5 text-base-content/40">
            No bots yet.
          </p>
        </nav>

        <div class="mt-5 border-t border-base-content/10 pt-4">
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
              :for={group <- visible_groups(@workspace_groups)}
              group={group}
              prefix="workspace"
              session_id={@session_id}
              delete_session_id={@delete_session_id}
            />
            <p
              :if={visible_groups(@workspace_groups) == []}
              class="px-2 py-3 text-xs leading-5 text-base-content/40"
            >
              No sessions yet.
            </p>
          </nav>
        </div>

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
            <p
              :if={@automation_groups == []}
              class="px-2 py-1 text-xs leading-5 text-base-content/40"
            >
              No active work.
            </p>
          </nav>
        </div>
      </div>
    </aside>
    """
  end

  defp visible_groups(groups), do: Enum.reject(groups, &(&1.key == :others))

  defp bot_status(bot, sessions) do
    Enum.find_value(sessions, "stopped", fn session ->
      if session["id"] == bot.chat_remote_session_id, do: session["status"]
    end)
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

  attr :bot, :map, required: true
  attr :status, :string, required: true
  attr :selected, :boolean, required: true
  attr :delete_bot_id, :string, default: nil

  defp bot_row(assigns) do
    ~H"""
    <div class={session_row_class(@selected)}>
      <.link
        id={"bot-#{@bot.id}"}
        navigate={"/bots/#{@bot.id}"}
        class="flex min-w-0 flex-1 items-center gap-2"
      >
        <span class={["size-1.5 shrink-0 rounded-full", status_color(@status)]}></span>
        <span class="min-w-0 flex-1 truncate">{@bot.name}</span>
        <span class="sr-only">{status_label(@status)}</span>
      </.link>
      <.inline_delete_button
        id={@bot.id}
        label={@bot.name}
        item_type="bot"
        confirming?={@delete_bot_id == @bot.id}
      />
    </div>
    """
  end

  attr :show_bot_form, :boolean, required: true
  attr :bot_form, :map, required: true
  attr :bot_error, :string, default: nil

  def bot_dialog(assigns) do
    ~H"""
    <div
      :if={@show_bot_form}
      id="bot-dialog"
      class="fixed inset-0 z-40 grid place-items-center bg-base-300/75 px-5"
      role="dialog"
      aria-modal="true"
      aria-labelledby="bot-dialog-title"
    >
      <section class="w-full max-w-md rounded-2xl border border-base-content/15 bg-base-200 p-6 shadow-2xl">
        <div class="flex items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.16em] text-primary">New bot</p>
            <h2 id="bot-dialog-title" class="mt-1 text-lg font-semibold tracking-tight">
              Set its working identity
            </h2>
          </div>
          <button
            id="close-bot-dialog"
            type="button"
            phx-click="hide_bot_form"
            class="btn btn-ghost btn-sm btn-square"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
        <.form for={@bot_form} id="create-bot-form" phx-submit="create_bot" class="mt-6 space-y-4">
          <.input field={@bot_form[:name]} label="Name" required autofocus />
          <.input field={@bot_form[:role]} label="Role" required />
          <.input field={@bot_form[:description]} type="textarea" label="Description" required />
          <p :if={@bot_error} id="bot-error" class="text-sm text-error" role="alert">{@bot_error}</p>
          <div class="flex justify-end gap-2 pt-2">
            <button
              id="cancel-bot-button"
              type="button"
              phx-click="hide_bot_form"
              class="btn btn-ghost"
            >Cancel</button>
            <button id="create-bot-button" class="btn btn-primary">Create bot</button>
          </div>
        </.form>
      </section>
    </div>
    """
  end

  attr :chat_name, :string, default: nil
  attr :bot, :map, default: nil
  attr :mobile_sidebar_open, :boolean, required: true

  def chat_header(assigns) do
    ~H"""
    <header
      id="chat-header"
      class="fixed inset-x-0 top-0 z-10 flex min-h-16 shrink-0 items-center gap-3 border-b border-base-content/10 bg-base-300 px-5 lg:static lg:px-8"
    >
      <button
        id="mobile-menu-button"
        type="button"
        phx-click="toggle_mobile_sidebar"
        class="grid size-9 place-items-center rounded-md text-base-content/65 transition-colors hover:bg-base-content/8 hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary lg:hidden"
        aria-controls="session-sidebar"
        aria-expanded={to_string(@mobile_sidebar_open)}
        aria-label={if @mobile_sidebar_open, do: "Close menu", else: "Open menu"}
      >
        <.icon name="hero-bars-3" class="size-5" />
      </button>
      <div class="flex min-w-0 items-center gap-2">
        <h1 class="truncate text-sm font-semibold tracking-tight">{@chat_name || "Matato Agent"}</h1>
        <button
          :if={@bot}
          id="edit-bot-button"
          type="button"
          phx-click="show_bot_editor"
          class="grid size-7 shrink-0 place-items-center rounded-md text-base-content/45 transition-colors hover:bg-base-content/8 hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
          aria-label="Edit bot"
        >
          <.icon name="hero-pencil-square" class="size-4" />
        </button>
      </div>
    </header>
    """
  end

  attr :show, :boolean, required: true
  attr :bot_form, :map, required: true
  attr :error, :string, default: nil

  def bot_editor(assigns) do
    ~H"""
    <div
      :if={@show}
      id="bot-editor-backdrop"
      phx-click="hide_bot_editor"
      class="fixed inset-0 z-30 bg-base-300/50"
      aria-hidden="true"
    >
    </div>
    <aside
      :if={@show}
      id="bot-editor"
      class="fixed inset-y-0 right-0 z-40 flex w-full max-w-md flex-col border-l border-base-content/10 bg-base-200 shadow-2xl"
      aria-label="Edit bot"
    >
      <div class="flex justify-end border-b border-base-content/10 px-6 py-4">
        <button
          id="close-bot-editor"
          type="button"
          phx-click="hide_bot_editor"
          class="btn btn-ghost btn-sm btn-square"
          aria-label="Close editor"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
      <.form
        for={@bot_form}
        id="edit-bot-form"
        phx-submit="update_bot"
        class="flex flex-1 flex-col gap-4 overflow-y-auto px-6 py-6"
      >
        <.input field={@bot_form[:name]} label="Name" required autofocus />
        <.input field={@bot_form[:role]} label="Role" required />
        <.input
          field={@bot_form[:description]}
          type="textarea"
          label="Description"
          required
          class="textarea textarea-bordered min-h-36 w-full bg-base-300"
        />
        <p :if={@error} id="bot-editor-error" class="text-sm text-error" role="alert">{@error}</p>
        <div class="mt-auto flex justify-end gap-2 border-t border-base-content/10 pt-5">
          <button
            id="cancel-bot-editor"
            type="button"
            phx-click="hide_bot_editor"
            class="btn btn-ghost"
          >Cancel</button>
          <button id="save-bot-button" class="btn btn-primary">Save changes</button>
        </div>
      </.form>
    </aside>
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
      <.inline_delete_button
        :if={@session.source == "web"}
        id={@session.id}
        label={@session.title}
        item_type="session"
        confirming?={@delete_session_id == @session.id}
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :item_type, :string, required: true
  attr :confirming?, :boolean, required: true

  defp inline_delete_button(assigns) do
    ~H"""
    <button
      :if={!@confirming?}
      id={"delete-#{@item_type}-#{@id}"}
      type="button"
      phx-click={"confirm_delete_#{@item_type}"}
      phx-value-id={@id}
      class="grid size-7 shrink-0 place-items-center rounded-md text-base-content/35 transition-colors hover:bg-error/10 hover:text-error focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
      aria-label={"Delete #{@label}"}
    >
      <.icon name="hero-trash" class="size-3.5" />
    </button>
    <button
      :if={@confirming?}
      id={"confirm-delete-#{@item_type}-#{@id}"}
      type="button"
      phx-click={"delete_#{@item_type}"}
      phx-value-id={@id}
      class="grid size-7 shrink-0 place-items-center rounded-md bg-error/15 text-error transition-colors hover:bg-error/25 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
      aria-label={"Confirm deletion of #{@label}"}
    >
      <.icon name="hero-check" class="size-3.5" />
    </button>
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
