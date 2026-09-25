defmodule WebAppWeb.AutomationRunLiveTest do
  use WebAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias WebApp.Automations
  alias WebApp.Sessions.Store

  setup do
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    job_name = "daily-review-#{System.unique_integer([:positive])}"

    session_dir =
      Path.join(Application.fetch_env!(:web_app, :automation_storage_path), "sessions")

    File.mkdir_p!(session_dir)
    session_file = Path.join(session_dir, "#{id}.jsonl")

    entries = [
      %{"type" => "session", "version" => 3, "id" => id, "cwd" => "/tmp"},
      %{
        "type" => "message",
        "message" => %{"role" => "user", "content" => "Run the review", "timestamp" => 1}
      },
      %{
        "type" => "message",
        "message" => %{
          "role" => "assistant",
          "content" => [%{"type" => "text", "text" => "Review complete"}],
          "timestamp" => 2
        }
      }
    ]

    File.write!(session_file, Enum.map_join(entries, "\n", &Jason.encode!/1) <> "\n")

    {:ok, _run} =
      Store.create(%{
        id: id,
        name: job_name,
        project_path: System.tmp_dir!(),
        relative_project: ".",
        session_file: session_file,
        pi_session_id: id,
        source: "automation",
        status: "settled"
      })

    {:ok, automation} =
      Automations.create(%{
        job_name: job_name,
        enabled: true,
        schedule: "0 0 1 1 *",
        user_prompt: "Review",
        daily_session: false,
        can_overlap: false,
        model: "model",
        thinking_level: "off",
        can_launch_sub_agents: false,
        monitor: true,
        use_skill: false
      })

    on_exit(fn ->
      Automations.delete(automation.id)
      Store.delete(id)
      File.rm(session_file)
    end)

    %{id: id, automation: automation}
  end

  test "lists runs for an automation and opens the selected transcript", %{
    conn: conn,
    id: id,
    automation: automation
  } do
    {:ok, view, _html} = live(conn, "/automations/#{automation.id}")

    assert has_element?(view, "#automation-runs")
    assert has_element?(view, "#automation-run-#{id} a[href='/automation-runs/#{id}']")
    assert render(view) =~ "Finished"
  end

  test "paginates automation runs ten at a time", %{
    conn: conn,
    automation: automation
  } do
    ids =
      Enum.map(1..10, fn index ->
        id = "pagination-#{index}-#{System.unique_integer([:positive])}"

        {:ok, _run} =
          Store.create(%{
            id: id,
            name: automation.job_name,
            project_path: System.tmp_dir!(),
            relative_project: ".",
            source: "automation",
            status: "settled"
          })

        id
      end)

    on_exit(fn -> Enum.each(ids, &Store.delete/1) end)

    {:ok, view, _html} = live(conn, "/automations/#{automation.id}")

    assert length(Regex.scan(~r/<tr id="automation-run-/, render(view))) == 10
    assert has_element?(view, "#automation-pagination", "Page 1 of 2")

    view |> element("#automation-pagination a", "Next") |> render_click()

    assert_patch(view, "/automations/#{automation.id}?page=2")
    assert length(Regex.scan(~r/<tr id="automation-run-/, render(view))) == 1
    assert has_element?(view, "#automation-pagination", "Page 2 of 2")
  end

  test "renders a monitored run transcript without interactive controls", %{conn: conn, id: id} do
    {:ok, view, _html} = live(conn, "/automation-runs/#{id}")

    assert has_element?(view, "#run-status", "Finished")
    assert has_element?(view, "#transcript")
    assert render(view) =~ "Run the review"
    assert render(view) =~ "Review complete"
    refute has_element?(view, "#composer-form")
    refute has_element?(view, "#model-select")
    refute has_element?(view, "#stop-button")
  end

  test "offers retry only for failed runs", %{conn: conn, id: id, automation: automation} do
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    gate_path = Path.join(System.tmp_dir!(), "gate-#{System.unique_integer([:positive])}")
    File.mkdir_p!(pi_dir)

    File.write!(
      pi_path,
      "#!/bin/sh\nIFS= read -r line\nwhile [ ! -e #{gate_path} ]; do sleep 0.01; done\nprintf '{\"type\":\"agent_settled\"}\\n'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")
    WebApp.Sessions.Registry.subscribe()

    on_exit(fn ->
      System.put_env("PATH", original_path)
      File.rm(gate_path)
      File.rm_rf!(pi_dir)

      Store.list()
      |> Enum.filter(&(&1["name"] == automation.job_name and &1["source"] == "automation"))
      |> Enum.each(&Store.delete(&1["id"]))
    end)

    {:ok, _run} = Store.update(id, %{status: "failed"})
    {:ok, view, _html} = live(conn, "/automation-runs/#{id}")

    assert has_element?(view, "#retry-run", "Retry")
    view |> element("#retry-run") |> render_click()
    assert render(view) =~ "Automation retry started"
    assert_receive :changed
    File.write!(gate_path, "")
    assert_receive :changed
  end

  test "shows a not found state for a missing run", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/automation-runs/missing")
    assert has_element?(view, "#automation-run-error", "Automation run not found")
  end
end
