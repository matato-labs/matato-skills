defmodule WebAppWeb.SessionLive do
  use WebAppWeb, :live_view

  alias WebApp.{ProjectSessionCatalog, RemoteRegistry, Workspace}
  alias WebAppWeb.SessionComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: RemoteRegistry.subscribe()
    sessions = RemoteRegistry.list()

    {:ok,
     assign(socket,
       page_title: "New Matato session",
       projects: Workspace.directories(),
       workspace_groups: ProjectSessionCatalog.workspace_groups(sessions),
       automation_groups: ProjectSessionCatalog.automation_groups(sessions),
       session_id: nil,
       delete_session_id: nil,
       mobile_sidebar_open: false,
       error: nil,
       start_form: to_form(%{"project" => ""}, as: :session)
     )}
  end

  @impl true
  def handle_event("confirm_delete_session", %{"id" => id}, socket),
    do: {:noreply, assign(socket, delete_session_id: id)}

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
       automation_groups: ProjectSessionCatalog.automation_groups(sessions)
     )}
  end
end
