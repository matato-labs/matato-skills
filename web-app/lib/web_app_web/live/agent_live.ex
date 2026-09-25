defmodule WebAppWeb.AgentLive do
  use WebAppWeb, :live_view

  alias WebApp.{Automations, Bots, Sessions}

  alias WebAppWeb.{AgentTranscript, SessionComponents}

  @max_prompt_bytes 100_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Sessions.subscribe()
      Automations.subscribe()
      Bots.subscribe()
    end

    sessions = Sessions.list()

    socket =
      assign(socket,
        page_title: "Matato Agent",
        sessions: sessions,
        workspace_groups: Sessions.workspace_groups(sessions),
        automation_groups: Sessions.automation_groups(sessions, Automations.list()),
        bots: Bots.list(),
        session_id: nil,
        bot: nil,
        chat_name: nil,
        show_bot_form: false,
        bot_error: nil,
        bot_form: bot_form(),
        show_bot_editor: false,
        show_automation_activity: false,
        bot_editor_error: nil,
        bot_editor_form: bot_form(),
        delete_session_id: nil,
        delete_bot_id: nil,
        mobile_sidebar_open: false,
        session: nil,
        draft: "",
        error: nil,
        available_models: [],
        thinking_levels: [],
        composer_form: to_form(%{"message" => ""}, as: :composer),
        dialog_form: to_form(%{"value" => ""}, as: :dialog),
        expanded_work_ids: MapSet.new(),
        last_sequence: 0,
        timeline_items: []
      )

    {:ok, stream(socket, :messages, [])}
  end

  @impl true
  def handle_params(%{"bot_id" => bot_id}, _uri, socket) do
    socket = unsubscribe_session(socket)

    case Bots.get(bot_id) do
      nil ->
        {:noreply, assign(socket, bot: nil, chat_name: nil, session: nil, error: "Bot not found")}

      bot ->
        open_bot_chat(socket, bot)
    end
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    socket = unsubscribe_session(socket)
    if connected?(socket), do: Sessions.subscribe_agent(id)

    case Sessions.open(id) do
      :ok ->
        %{sequence: sequence, view: snapshot} = Sessions.snapshot_with_sequence(id)

        {:noreply,
         socket
         |> assign(
           session_id: id,
           bot: nil,
           chat_name: session_name(id),
           mobile_sidebar_open: false,
           expanded_work_ids: MapSet.new(),
           error: nil,
           last_sequence: sequence
         )
         |> sync_session(snapshot)}

      {:error, error} ->
        {:noreply,
         assign(socket,
           session_id: id,
           bot: nil,
           chat_name: nil,
           session: nil,
           mobile_sidebar_open: false,
           error: error
         )}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, unsubscribe_session(socket)}

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

  def handle_event("show_bot_editor", _params, %{assigns: %{bot: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("show_bot_editor", _params, socket) do
    {:noreply,
     assign(socket,
       show_bot_editor: true,
       bot_editor_error: nil,
       bot_editor_form: bot_form(socket.assigns.bot)
     )}
  end

  def handle_event("hide_bot_editor", _params, socket),
    do: {:noreply, assign(socket, show_bot_editor: false, bot_editor_error: nil)}

  def handle_event("toggle_automation_activity", _params, %{assigns: %{bot: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("toggle_automation_activity", _params, socket),
    do: {:noreply, update(socket, :show_automation_activity, &(!&1))}

  def handle_event("hide_automation_activity", _params, socket),
    do: {:noreply, assign(socket, show_automation_activity: false)}

  def handle_event("update_bot", %{"bot" => params}, %{assigns: %{bot: bot}} = socket) do
    case Bots.update(bot.id, params) do
      {:ok, bot} ->
        {:noreply,
         socket
         |> assign(bot: bot, chat_name: bot.name, show_bot_editor: false, bot_editor_error: nil)
         |> assign_sessions()}

      {:error, reason} ->
        {:noreply,
         assign(socket, bot_editor_error: format_error(reason), bot_editor_form: bot_form(params))}
    end
  end

  def handle_event("confirm_delete_session", %{"id" => id}, socket),
    do: {:noreply, assign(socket, delete_session_id: id)}

  def handle_event("confirm_delete_bot", %{"id" => id}, socket),
    do: {:noreply, assign(socket, delete_bot_id: id)}

  def handle_event("delete_bot", %{"id" => id}, socket) do
    case Bots.delete(id) do
      :ok ->
        {:noreply, push_navigate(socket, to: "/")}

      {:error, :not_found} ->
        {:noreply, assign(socket, error: "Bot not found", delete_bot_id: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: format_error(reason), delete_bot_id: nil)}
    end
  end

  def handle_event("toggle_work", %{"id" => id, "open" => "true"}, socket),
    do: {:noreply, update(socket, :expanded_work_ids, &MapSet.put(&1, id))}

  def handle_event("toggle_work", %{"id" => id, "open" => "false"}, socket),
    do: {:noreply, update(socket, :expanded_work_ids, &MapSet.delete(&1, id))}

  def handle_event("message_copied", _params, socket),
    do: {:noreply, put_flash(socket, :info, "Message copied")}

  def handle_event("message_copy_failed", _params, socket),
    do: {:noreply, put_flash(socket, :error, "Message could not be copied")}

  def handle_event("toggle_mobile_sidebar", _params, socket),
    do: {:noreply, update(socket, :mobile_sidebar_open, &(!&1))}

  def handle_event("close_mobile_sidebar", _params, socket),
    do: {:noreply, assign(socket, mobile_sidebar_open: false)}

  def handle_event("delete_session", %{"id" => id}, socket) do
    case Sessions.delete(id) do
      :ok when id == socket.assigns.session_id ->
        {:noreply, push_navigate(socket, to: "/")}

      :ok ->
        {:noreply, socket |> assign_sessions() |> assign(delete_session_id: nil)}

      {:error, error} ->
        {:noreply, assign(socket, error: error, delete_session_id: nil)}
    end
  end

  def handle_event(
        "compose",
        %{"composer" => %{"message" => message}, "behavior" => "steer"},
        socket
      ),
      do: send_command(socket, "steer", message)

  def handle_event("compose", %{"composer" => %{"message" => message}}, socket),
    do:
      send_command(
        socket,
        if(agent_active?(socket.assigns.session.status), do: "follow_up", else: "prompt"),
        message
      )

  def handle_event("draft", %{"composer" => %{"message" => message}}, socket),
    do: {:noreply, set_draft(socket, message)}

  def handle_event("abort", _params, socket), do: run_command(socket, %{"type" => "abort"})

  def handle_event("abort_and_restore_queue", _params, socket) do
    queued_messages =
      socket.assigns.session.queue["steering"] ++ socket.assigns.session.queue["followUp"]

    socket
    |> set_draft(Enum.join(queued_messages ++ [socket.assigns.draft], "\n\n"))
    |> run_command(%{"type" => "abort"})
  end

  def handle_event("stop", _params, socket) do
    :ok = Sessions.stop(socket.assigns.session_id)

    {:noreply, assign(socket, session: %{socket.assigns.session | status: :stopped})}
  end

  def handle_event("set_model", %{"model" => value}, socket) do
    [provider, model_id] = String.split(value, "/", parts: 2)

    case command(socket, %{"type" => "set_model", "provider" => provider, "modelId" => model_id}) do
      :ok -> {:noreply, apply_model(socket, %{"provider" => provider, "id" => model_id})}
      {:ok, model} -> {:noreply, apply_model(socket, model)}
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  end

  def handle_event("set_thinking_level", %{"level" => level}, socket) do
    case command(socket, %{"type" => "set_thinking_level", "level" => level}) do
      :ok ->
        session = Map.put(socket.assigns.session, :thinking_level, level)
        {:noreply, assign(socket, session: session, error: nil)}

      {:error, error} ->
        {:noreply, assign(socket, error: error)}
    end
  end

  def handle_event("resume", _params, socket) do
    id = socket.assigns.session_id

    case Sessions.open(id) do
      :ok -> {:noreply, resync_session(socket |> assign(error: nil), id)}
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  catch
    :exit, _reason -> {:noreply, assign(socket, error: "Agent process could not be resumed")}
  end

  def handle_event("dialog", params, socket) do
    response = dialog_response(socket.assigns.session.dialog, params)

    case Sessions.respond(socket.assigns.session_id, response) do
      :ok -> {:noreply, assign(socket, session: Sessions.clear_dialog(socket.assigns.session))}
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  end

  @impl true
  def handle_info(:changed, socket), do: {:noreply, assign_sessions(socket)}

  def handle_info({:agent_update, session_id, sequence, update}, socket) do
    cond do
      session_id != socket.assigns.session_id ->
        {:noreply, socket}

      sequence <= socket.assigns.last_sequence ->
        {:noreply, socket}

      sequence != socket.assigns.last_sequence + 1 ->
        {:noreply, resync_session(socket, session_id)}

      true ->
        socket =
          socket
          |> apply_hint(update)
          |> apply_dialog_form(update)
          |> assign(
            session: Sessions.apply(socket.assigns.session, update),
            last_sequence: sequence
          )

        {:noreply, socket |> assign_sessions() |> reconcile_timeline()}
    end
  end

  defdelegate transcript_item(assigns), to: AgentTranscript
  defdelegate work_label(item), to: AgentTranscript
  defdelegate markdown(text), to: AgentTranscript
  defdelegate command_location(command), to: AgentTranscript
  defdelegate command_path(command), to: AgentTranscript
  defdelegate message_text(message), to: AgentTranscript
  defdelegate display_message_text(message), to: AgentTranscript
  defdelegate visible_message?(message), to: AgentTranscript
  defdelegate partial_text(session), to: AgentTranscript
  defdelegate partial_thinking(session), to: AgentTranscript
  defdelegate partial_items(session), to: AgentTranscript
  defdelegate tool_status(tool), to: AgentTranscript
  defdelegate tool_output(tool), to: AgentTranscript
  defdelegate tool_result(result), to: AgentTranscript
  defdelegate work_turn_items(items, partial, active?), to: AgentTranscript
  defdelegate work_turn_items(items, partial, active?, duration), to: AgentTranscript

  defp agent_active?(status),
    do: status in [:working, :retrying, :compacting, :waiting_for_input]

  defp send_command(socket, _type, message) when message in [nil, ""], do: {:noreply, socket}

  defp send_command(socket, type, message) do
    message = String.trim(message)

    cond do
      message == "" ->
        {:noreply, socket}

      byte_size(message) > @max_prompt_bytes ->
        {:noreply, assign(socket, error: "Prompt exceeds 100 KB")}

      true ->
        case command(socket, %{"type" => type, "message" => message}) do
          :ok -> {:noreply, socket |> set_draft("") |> assign(error: nil)}
          {:error, error} -> {:noreply, assign(socket, error: error)}
        end
    end
  end

  defp run_command(socket, command) do
    case command(socket, command) do
      :ok -> {:noreply, assign(socket, error: nil)}
      {:ok, _data} -> {:noreply, assign(socket, error: nil)}
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  end

  defp command(socket, command) do
    Sessions.command(socket.assigns.session_id, command)
  catch
    :exit, _reason -> {:error, "Agent process is unavailable. Resume the session to reconnect."}
  end

  defp set_draft(socket, draft) do
    assign(socket, draft: draft, composer_form: to_form(%{"message" => draft}, as: :composer))
  end

  defp assign_sessions(socket) do
    sessions = Sessions.list()

    assign(socket,
      sessions: sessions,
      workspace_groups: Sessions.workspace_groups(sessions),
      automation_groups: Sessions.automation_groups(sessions, Automations.list()),
      bots: Bots.list()
    )
  end

  defp bot_form, do: bot_form(%{})

  defp bot_form(bot) do
    to_form(
      %{
        "name" => Map.get(bot, :name) || Map.get(bot, "name", ""),
        "role" => Map.get(bot, :role) || Map.get(bot, "role", ""),
        "description" => Map.get(bot, :description) || Map.get(bot, "description", "")
      },
      as: :bot
    )
  end

  defp session_name(id) do
    case Sessions.get(id) do
      %{"name" => name} -> name
      nil -> nil
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp sync_session(socket, snapshot) do
    items = timeline_for(socket, snapshot)

    socket
    |> assign(session: snapshot, timeline_items: items)
    |> stream(:messages, items, reset: true)
    |> assign_composer_options()
  end

  defp assign_composer_options(socket) do
    if connected?(socket) do
      socket = sync_model_state(socket)

      assign(socket,
        available_models: available_models(socket),
        thinking_levels: thinking_levels(socket)
      )
    else
      socket
    end
  end

  defp sync_model_state(socket) do
    case command(socket, %{"type" => "get_state"}) do
      {:ok, data} ->
        session =
          socket.assigns.session
          |> Map.put(:model, data["model"])
          |> Map.put(:thinking_level, data["thinkingLevel"])

        assign(socket, session: session)

      _result ->
        socket
    end
  end

  defp apply_model(socket, model) do
    socket = assign(socket, session: %{socket.assigns.session | model: model})
    assign(socket, thinking_levels: thinking_levels(socket), error: nil)
  end

  defp available_models(socket) do
    case command(socket, %{"type" => "get_available_models"}) do
      {:ok, %{"models" => models}} -> models_with_current(socket.assigns.session.model, models)
      _result -> []
    end
  end

  defp models_with_current(nil, models), do: models

  defp models_with_current(model, models) do
    current? = &(&1["id"] == model["id"] and &1["provider"] == model["provider"])
    if Enum.any?(models, current?), do: models, else: [model | models]
  end

  defp thinking_levels(socket) do
    case command(socket, %{"type" => "get_available_thinking_levels"}) do
      {:ok, %{"levels" => levels}} -> levels
      _result -> []
    end
  end

  defp resync_session(socket, id) do
    %{sequence: sequence, view: snapshot} = Sessions.snapshot_with_sequence(id)

    socket
    |> assign(last_sequence: sequence, error: nil)
    |> sync_session(snapshot)
  end

  defp reconcile_timeline(socket) do
    items = timeline_for(socket, socket.assigns.session)
    old_items = Map.new(socket.assigns.timeline_items, &{&1.id, &1})
    new_items = Map.new(items, &{&1.id, &1})

    socket =
      Enum.reduce(old_items, socket, fn {id, _item}, socket ->
        if Map.has_key?(new_items, id),
          do: socket,
          else: stream_delete(socket, :messages, %{id: id})
      end)

    socket =
      Enum.reduce(Enum.with_index(items), socket, fn {item, index}, socket ->
        if old_items[item.id] == item,
          do: socket,
          else: stream_insert(socket, :messages, item, at: index)
      end)

    assign(socket, timeline_items: items)
  end

  defp timeline_for(socket, session) do
    session
    |> AgentTranscript.transcript_items()
    |> AgentTranscript.mark_expanded_work(socket.assigns.expanded_work_ids)
  end

  defp apply_hint(socket, {:hint, %{"method" => "set_editor_text", "text" => text}}),
    do: set_draft(socket, text)

  defp apply_hint(socket, {:hint, %{"method" => "setTitle", "title" => title}}),
    do: assign(socket, page_title: title)

  defp apply_hint(socket, _update), do: socket

  defp apply_dialog_form(socket, {:event, %{"type" => "extension_ui_request"} = event}),
    do: assign(socket, dialog_form: to_form(%{"value" => event["prefill"] || ""}, as: :dialog))

  defp apply_dialog_form(socket, _update), do: socket

  defp unsubscribe_session(socket) do
    if connected?(socket) and socket.assigns.session_id,
      do: Sessions.unsubscribe_agent(socket.assigns.session_id)

    socket
  end

  defp open_bot_chat(socket, bot) do
    id = bot.chat_remote_session_id
    if connected?(socket), do: Sessions.subscribe_agent(id)

    case Sessions.open(id, Bots.identity_for(bot)) do
      :ok ->
        {:noreply,
         socket
         |> assign(
           bot: bot,
           chat_name: bot.name,
           session_id: id,
           mobile_sidebar_open: false,
           show_automation_activity: false,
           expanded_work_ids: MapSet.new(),
           error: nil
         )
         |> resync_session(id)}

      {:error, error} ->
        {:noreply,
         assign(socket,
           bot: bot,
           chat_name: bot.name,
           session_id: id,
           session: nil,
           mobile_sidebar_open: false,
           show_automation_activity: false,
           error: error
         )}
    end
  end

  defp dialog_response(%{"id" => id, "method" => "confirm"}, params) do
    %{"type" => "extension_ui_response", "id" => id, "confirmed" => params["answer"] == "true"}
  end

  defp dialog_response(%{"id" => id}, %{"cancel" => "true"}),
    do: %{"type" => "extension_ui_response", "id" => id, "cancelled" => true}

  defp dialog_response(%{"id" => id}, %{"dialog" => params}),
    do: %{"type" => "extension_ui_response", "id" => id, "value" => params["value"]}

  defp dialog_response(%{"id" => id}, params),
    do: %{"type" => "extension_ui_response", "id" => id, "value" => params["value"]}
end
