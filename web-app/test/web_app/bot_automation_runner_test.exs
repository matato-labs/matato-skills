defmodule WebApp.BotAutomationRunnerTest do
  use ExUnit.Case, async: false

  alias WebApp.Automations
  alias WebApp.Automations.Runner
  alias WebApp.Bots.Bot
  alias WebApp.Data.Repo
  alias WebApp.Sessions.{Agent, Store, Workspace}

  setup do
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    project = Path.join(Workspace.root(), "automation#{id}")
    File.mkdir_p!(project)
    executable = Path.join(project, "fakepi")

    File.write!(
      executable,
      ~S"""
      #!/usr/bin/env python3
      import json, sys, time
      for line in sys.stdin:
       command = json.loads(line)
       with open('commands.jsonl', 'a') as file: file.write(json.dumps(command) + '\n')
       kind = command['type']
       response = {'type': 'response', 'id': command['id'], 'success': True}
       if kind == 'get_state': response['data'] = {'model': None, 'isStreaming': False, 'isCompacting': False}
       if kind == 'get_messages': response['data'] = {'messages': [{'role': 'assistant', 'content': [{'type': 'text', 'text': 'Old answer'}]}]}
       if kind == 'get_commands': response['data'] = {'commands': []}
       print(json.dumps(response), flush=True)
       if kind == 'prompt':
        print(json.dumps({'type': 'agent_start'}), flush=True)
        time.sleep(0.15)
        print(json.dumps({'type': 'message_end', 'message': {'role': 'assistant', 'content': [{'type': 'text', 'text': command['message']}]}}), flush=True)
        print(json.dumps({'type': 'agent_settled'}), flush=True)
      """
      |> String.trim_leading()
    )

    File.chmod!(executable, 0o700)

    start_supervised!(
      {Agent, id: id, name: "background", project: project, executable: executable},
      id: id
    )

    assert :ok = Agent.await_ready(id)

    {:ok, _} =
      Store.create(%{
        id: id,
        name: "background",
        project_path: project,
        relative_project: Path.relative_to(project, Workspace.root()),
        source: "bot_background",
        status: "settled"
      })

    bot =
      Repo.insert!(%Bot{
        name: "Runner",
        role: "assistant",
        description: "Test",
        chat_remote_session_id: "chat#{id}",
        background_remote_session_id: id
      })

    on_exit(fn ->
      Repo.delete(bot)
      Store.delete(id)
      File.rm_rf!(project)
    end)

    %{bot: bot, id: id, project: project}
  end

  test "serializes turns, applies settings and returns only the current answer", %{
    bot: bot,
    project: project
  } do
    first = Task.async(fn -> Runner.run(automation(bot, "First")) end)
    Process.sleep(40)
    second = Task.async(fn -> Runner.run(automation(bot, "Second")) end)
    assert Task.await(first) == :ok
    assert Task.await(second) == :ok

    commands =
      File.read!(Path.join(project, "commands.jsonl"))
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert Enum.map(Enum.filter(commands, &(&1["type"] == "prompt")), & &1["message"]) == [
             "First",
             "Second"
           ]

    assert Enum.count(
             commands,
             &(&1["type"] == "set_model" and &1["provider"] == "openai" and
                 &1["modelId"] == "gpt-4o")
           ) == 2

    assert Enum.count(commands, &(&1["type"] == "set_thinking_level" and &1["level"] == "low")) ==
             2

    refute Enum.any?(commands, &(&1["message"] == "Old answer"))
  end

  test "waits for an owned idle background session instead of racing its prompt", %{
    bot: bot,
    id: id,
    project: project
  } do
    assert :owner = Agent.claim(id, self())
    task = Task.async(fn -> Runner.run(automation(bot, "After owner releases")) end)
    Process.sleep(200)

    commands = File.read!(Path.join(project, "commands.jsonl"))
    refute commands =~ "After owner releases"

    Agent.release(id, self())
    assert Task.await(task) == :ok
    assert File.read!(Path.join(project, "commands.jsonl")) =~ "After owner releases"
  end

  test "monitored bot runs persist their own result without sending a message", %{bot: bot} do
    existing = Store.list() |> Enum.map(& &1["id"]) |> MapSet.new()
    Runner.run(%{automation(bot, "Summarize the work") | monitor: true})
    _ = :sys.get_state(WebApp.Sessions.Registry)

    assert [%{"id" => id, "status" => "settled", "result" => "Summarize the work"}] =
             Store.list()
             |> Enum.reject(&MapSet.member?(existing, &1["id"]))
             |> Enum.filter(&(&1["source"] == "automation"))

    assert [] = WebApp.Messages.list_for_bot(bot.id)
    on_exit(fn -> Store.delete(id) end)
  end

  test "invalid model fails before prompting and releases ownership", %{
    bot: bot,
    id: id,
    project: project
  } do
    Runner.run(%{automation(bot, "Never") | model: "unqualified"})
    assert :owner = Agent.claim(id, self())
    Agent.release(id, self())

    commands =
      File.read!(Path.join(project, "commands.jsonl"))
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    refute Enum.any?(commands, &(&1["type"] == "prompt"))
  end

  test "rejects daily sessions without delivering a prompt", %{bot: bot, project: project} do
    Runner.run(%{automation(bot, "Never") | daily_session: true})

    commands =
      File.read!(Path.join(project, "commands.jsonl"))
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    refute Enum.any?(commands, &(&1["type"] == "prompt"))
  end

  defp automation(bot, prompt),
    do: %Automations{
      job_name: "job",
      bot_id: bot.id,
      enabled: true,
      schedule: "* * * * *",
      user_prompt: prompt,
      daily_session: false,
      can_overlap: true,
      model: "openai/gpt-4o",
      thinking_level: "low",
      use_skill: false
    }
end
