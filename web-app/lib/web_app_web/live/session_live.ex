defmodule WebAppWeb.SessionLive do
  use WebAppWeb, :live_view

  alias WebApp.{Automations, Sessions}
  alias WebAppWeb.SessionComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Sessions.subscribe()
      Automations.subscribe()
    end

    sessions = Sessions.list()

    {:ok,
     assign(socket,
       page_title: "New Matato session",
       projects: Sessions.workspace_directories(),
       sessions: sessions,
       workspace_groups: Sessions.workspace_groups(sessions),
       automation_groups: Sessions.automation_groups(sessions, Automations.list()),
       general_sessions: Sessions.general_sessions(sessions),
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
    case Sessions.delete(id) do
      :ok ->
        sessions = Sessions.list()

        {:noreply,
         assign(socket,
           sessions: sessions,
           workspace_groups: Sessions.workspace_groups(sessions),
           automation_groups: Sessions.automation_groups(sessions, Automations.list()),
           general_sessions: Sessions.general_sessions(sessions),
           delete_session_id: nil,
           error: nil
         )}

      {:error, error} ->
        {:noreply, assign(socket, error: error, delete_session_id: nil)}
    end
  end

  def handle_event("start_general", _params, socket) do
    case Sessions.create_general() do
      {:ok, id} -> {:noreply, push_navigate(socket, to: "/sessions/#{id}")}
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  end

  def handle_event("start", %{"session" => params}, socket) do
    relative = params["project"] || ""

    cond do
      byte_size(relative) > 1_024 ->
        {:noreply, assign(socket, error: "Project path is too long")}

      true ->
        case Sessions.create(relative) do
          {:ok, id} -> {:noreply, push_navigate(socket, to: "/sessions/#{id}")}
          {:error, error} -> {:noreply, assign(socket, error: error)}
        end
    end
  end

  @impl true
  def handle_info(:changed, socket) do
    sessions = Sessions.list()

    {:noreply,
     assign(socket,
       sessions: sessions,
       workspace_groups: Sessions.workspace_groups(sessions),
       automation_groups: Sessions.automation_groups(sessions, Automations.list()),
       general_sessions: Sessions.general_sessions(sessions)
     )}
  end
end
