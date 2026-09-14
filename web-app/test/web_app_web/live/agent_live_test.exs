defmodule WebAppWeb.AgentLiveTest do
  use WebAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias WebApp.{AgentFanout, AgentSession, Messages, RemoteSessions, Repo, Workspace}
  alias WebApp.Bots.Bot
  alias WebApp.Messages.Message

  setup do
    root = Path.join(System.tmp_dir!(), "agent-live-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    executable = Path.join(root, "fakepi")

    File.write!(executable, """
    #!/usr/bin/env python3
    import json, sys
    for line in sys.stdin:
      command = json.loads(line)
      response = {"id": command["id"], "type": "response", "command": command["type"], "success": True}
      if command["type"] == "get_state":
        response["data"] = {"model": None, "isStreaming": False, "isCompacting": False, "sessionFile": None, "sessionId": "pi-1"}
      elif command["type"] == "get_messages":
        response["data"] = {"messages": [{"role": "user", "content": "First prompt", "timestamp": 1000}, {"role": "assistant", "content": [{"type": "text", "text": "First reply"}], "timestamp": 3000}]}
      elif command["type"] == "get_commands":
        response["data"] = {"commands": [{"name": "plan", "description": "Plan the work", "source": "prompt", "sourceInfo": {"path": "#{root}/.pi/prompts/plan.md", "scope": "project"}}]}
      print(json.dumps(response), flush=True)
    """)

    File.chmod!(executable, 0o700)
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    project = Path.join(Workspace.root(), "agent-live-#{id}")
    File.mkdir_p!(project)
    AgentFanout.subscribe(id)

    start_supervised!(
      {AgentSession,
       id: id, name: "test", project: project, executable: executable, interrupted: false},
      id: id
    )

    assert :ok = AgentSession.await_ready(id)
    assert_receive {:agent_snapshot, %{commands: [_command]}}, 2_000

    {:ok, _session} =
      RemoteSessions.create(%{
        id: id,
        name: "test",
        project_path: project,
        relative_project: Path.relative_to(project, Workspace.root()),
        source: "web",
        status: "settled"
      })

    bot =
      Repo.insert!(%Bot{
        name: "Test bot",
        role: "tester",
        description: "Tests UI",
        chat_remote_session_id: id,
        background_remote_session_id: "background-#{id}"
      })

    on_exit(fn ->
      Repo.delete_all(Message)
      Repo.delete(bot)
      :ok = RemoteSessions.delete(id)

      File.rm_rf!(root)
      File.rm_rf!(project)
    end)

    %{id: id, bot: bot}
  end

  test "renders persisted bot activity in the bot chat", %{conn: conn, bot: bot} do
    {:ok, _message} =
      Messages.create(%{
        receiver_bot_id: bot.id,
        sender_type: "automation",
        timestamp: DateTime.from_unix!(2, :second),
        kind: "result",
        content: "Daily review complete",
        sent_status: "sent"
      })

    {:ok, view, _html} = live(conn, "/bots/#{bot.id}")

    html = render(view)
    assert has_element?(view, "[id*='notification-']")
    assert html =~ "border-info/30"
    assert html =~ "text-info"
    assert html =~ "Daily review complete"
    assert {prompt_index, _length} = :binary.match(html, "First prompt")
    assert {activity_index, _length} = :binary.match(html, "Daily review complete")
    assert {reply_index, _length} = :binary.match(html, "First reply")
    assert prompt_index < activity_index
    assert activity_index < reply_index
  end

  test "renders failed bot activity in red" do
    html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "notification-failed",
        item: %{kind: :notification, status: "failed", content: "Delivery failed"}
      )

    assert html =~ "border-error/30"
    assert html =~ "bg-error/10"
    assert html =~ "text-error"
  end

  test "hides expanded skill content in the transcript" do
    message = %{
      "content" =>
        "<skill name=\"review\" location=\"/skills/review/SKILL.md\">\nReview instructions\n</skill>\n\nCheck the API"
    }

    assert WebAppWeb.AgentLive.display_message_text(message) == "/skill:review\n\nCheck the API"
  end

  test "groups live work and keeps the settled final reply outside it" do
    user = %{id: "user", kind: :message, role: :user, text: "Fix it"}
    progress = %{id: "progress", kind: :message, role: :agent, text: "I will inspect it"}

    trace = %{
      id: "tool",
      kind: :tool,
      tool: %{name: "bash", args: "pwd", result: nil, error: false}
    }

    final = %{id: "final", kind: :message, role: :agent, text: "Fixed"}

    assert [
             ^user,
             %{kind: :work_turn, active?: false, messages: [^progress], traces: [^trace]},
             ^final
           ] =
             WebAppWeb.AgentLive.work_turn_items([user, progress, trace, final], [], false)

    assert [
             ^user,
             %{kind: :work_turn, active?: true, messages: [^progress, ^final], traces: [^trace]}
           ] =
             WebAppWeb.AgentLive.work_turn_items([user, progress, trace], [final], true)
  end

  test "renders a work disclosure with nested activity" do
    html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "work-user-settled",
        item: %{
          kind: :work_turn,
          active?: false,
          messages: [%{id: "progress", kind: :message, role: :agent, text: "I will inspect it"}],
          traces: [
            %{
              id: "tool",
              kind: :tool,
              tool: %{name: "bash", args: "pwd", result: nil, error: false}
            }
          ]
        }
      )

    assert html =~ "Worked"
    assert html =~ "Activity (1)"
  end

  test "renders agent replies without a message bubble" do
    html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "agent-message",
        item: %{kind: :message, role: :agent, text: "Done"}
      )

    refute html =~ "max-w-[72ch]"
    refute html =~ "rounded-2xl"
  end

  test "renders discovered slash commands when the composer starts with a slash", %{
    conn: conn,
    id: id
  } do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")

    assert has_element?(view, "#composer-form")
    assert has_element?(view, "#slash-command-picker[hidden]")

    view
    |> form("#composer-form", composer: %{message: "/"})
    |> render_change()

    assert has_element?(view, "#slash-command-picker:not([hidden])")
    assert has_element?(view, "#slash-command-plan[title$='.pi/prompts/plan.md']")
  end

  test "opens and closes the mobile session drawer", %{conn: conn, id: id} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")

    assert has_element?(
             view,
             "#mobile-menu-button[aria-expanded='false'][aria-label='Open menu']"
           )

    refute has_element?(view, "#mobile-sidebar-backdrop")

    view |> element("#mobile-menu-button") |> render_click()

    assert has_element?(
             view,
             "#mobile-menu-button[aria-expanded='true'][aria-label='Close menu']"
           )

    assert has_element?(view, "#mobile-sidebar-backdrop")

    render_patch(view, ~p"/sessions/#{id}")

    refute has_element?(view, "#mobile-sidebar-backdrop")

    view |> element("#mobile-menu-button") |> render_click()
    view |> element("#mobile-sidebar-backdrop") |> render_click()

    refute has_element?(view, "#mobile-sidebar-backdrop")
  end
end
