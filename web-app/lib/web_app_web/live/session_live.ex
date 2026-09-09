defmodule WebAppWeb.SessionLive do
  use WebAppWeb, :live_view

  alias WebApp.{RemoteRegistry, Workspace}
  alias WebAppWeb.SessionComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "New Matato session",
       projects: Workspace.directories(),
       sessions: RemoteRegistry.list(),
       session_id: nil,
       error: nil,
       start_form: to_form(%{"project" => ""}, as: :session)
     )}
  end

  @impl true
  def handle_event("start", %{"session" => params}, socket) do
    relative = params["project"] || ""

    cond do
      byte_size(relative) > 1_024 ->
        {:noreply, assign(socket, error: "Project path is too long")}

      true ->
        case RemoteRegistry.create(relative) do
          {:ok, id} -> {:noreply, push_navigate(socket, to: ~p"/sessions/#{id}")}
          {:error, error} -> {:noreply, assign(socket, error: error)}
        end
    end
  end
end
