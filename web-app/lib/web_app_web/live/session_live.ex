defmodule WebAppWeb.SessionLive do
  use WebAppWeb, :live_view

  alias WebApp.{Bots, ProjectSessionCatalog, RemoteRegistry, Workspace}
  alias WebAppWeb.SessionComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      RemoteRegistry.subscribe()
      Bots.subscribe()
    end

    sessions = RemoteRegistry.list()

    {:ok,
     assign(socket,
       page_title: "New Matato session",
       projects: Workspace.directories(),
       workspace_groups: ProjectSessionCatalog.workspace_groups(sessions),
       automation_groups: ProjectSessionCatalog.automation_groups(sessions),
       bots: Bots.list(),
       session_id: nil,
       show_bot_form: false,
       bot_error: nil,
       bot_form: bot_form(),
       delete_session_id: nil,
       delete_bot_id: nil,
       mobile_sidebar_open: false,
       error: nil,
       start_form: to_form(%{"project" => ""}, as: :session)
     )}
  end

  @impl true
  def handle_event("show_bot_form", _params, socket),
    do: {:noreply, assign(socket, show_bot_form: true, bot_error: nil, bot_form: bot_form())}

  def handle_event("hide_bot_form", _params, socket),
    do: {:noreply, assign(socket, show_bot_form: false, bot_error: nil)}

  def handle_event("create_bot", %{"bot" => params}, socket) do
    case Bots.create(params) do
      {:ok, bot} -> {:noreply, push_navigate(socket, to: "/bots/#{bot.id}")}
      {:error, reason} -> {:noreply, assign(socket, bot_error: format_error(reason))}
    end
  end

  def handle_event("confirm_delete_session", %{"id" => id}, socket),
    do: {:noreply, assign(socket, delete_session_id: id)}

  def handle_event("confirm_delete_bot", %{"id" => id}, socket),
    do: {:noreply, assign(socket, delete_bot_id: id)}

  def handle_event("delete_bot", %{"id" => id}, socket) do
    case Bots.delete(id) do
      :ok ->
        {:noreply, socket |> assign_sessions() |> assign(delete_bot_id: nil, error: nil)}

      {:error, :not_found} ->
        {:noreply, assign(socket, error: "Bot not found", delete_bot_id: nil)}
    end
  end

  def handle_event("toggle_mobile_sidebar", _params, socket),
    do: {:noreply, update(socket, :mobile_sidebar_open, &(!&1))}

  def handle_event("close_mobile_sidebar", _params, socket),
    do: {:noreply, assign(socket, mobile_sidebar_open: false)}

  def handle_event("delete_session", %{"id" => id}, socket) do
    case RemoteRegistry.delete(id) do
      :ok ->
        sessions = RemoteRegistry.list()

        {:noreply,
         assign(socket,
           workspace_groups: ProjectSessionCatalog.workspace_groups(sessions),
           automation_groups: ProjectSessionCatalog.automation_groups(sessions),
           bots: Bots.list(),
           delete_session_id: nil,
           error: nil
         )}

      {:error, error} ->
        {:noreply, assign(socket, error: error, delete_session_id: nil)}
    end
  end

  def handle_event("start", %{"session" => params}, socket) do
    relative = params["project"] || ""

    cond do
      byte_size(relative) > 1_024 ->
        {:noreply, assign(socket, error: "Project path is too long")}

      true ->
        case RemoteRegistry.create(relative) do
          {:ok, id} -> {:noreply, push_navigate(socket, to: "/sessions/#{id}")}
          {:error, error} -> {:noreply, assign(socket, error: error)}
        end
    end
  end

  @impl true
  def handle_info(:changed, socket) do
    sessions = RemoteRegistry.list()

    {:noreply,
     assign(socket,
       workspace_groups: ProjectSessionCatalog.workspace_groups(sessions),
       automation_groups: ProjectSessionCatalog.automation_groups(sessions),
       bots: Bots.list()
     )}
  end

  defp assign_sessions(socket) do
    sessions = RemoteRegistry.list()

    assign(socket,
      workspace_groups: ProjectSessionCatalog.workspace_groups(sessions),
      automation_groups: ProjectSessionCatalog.automation_groups(sessions),
      bots: Bots.list()
    )
  end

  defp bot_form, do: to_form(%{"name" => "", "role" => "", "description" => ""}, as: :bot)

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
