defmodule WebApp.AutomationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias WebApp.{
    Automation,
    AutomationRunner,
    AutomationScheduler,
    ProjectSessionCatalog,
    RemoteRegistry,
    RemoteSessions,
    Repo,
    Messages
  }

  alias WebApp.Bots.Bot
  alias WebApp.Messages.Message

  setup do
    :ok = Automation.replace([])
    _ = :sys.get_state(WebApp.AutomationSubscription)
    :ok
  end

  test "stores replacement automations for the shared database" do
    automation = %{
      automation("stored", "* * * * *")
      | can_launch_sub_agents: true,
        can_overlap: true
    }

    assert :ok = Automation.replace([automation])

    assert [
             %Automation{
               job_name: "stored",
               can_launch_sub_agents: true,
               can_overlap: true
             }
           ] = Automation.list()
  end

  test "rejects replacement automations with duplicate job names" do
    assert {:error, "Automation job names must be unique"} =
             Automation.replace([
               automation("duplicate", "* * * * *"),
               automation("duplicate", "*/5 * * * *")
             ])
  end

  test "runs a prompt-only automation without a skill" do
    job_name = "automation-#{System.unique_integer([:positive])}"
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    prompt_path = temp_path()
    mix_env_path = temp_path()
    File.mkdir_p!(pi_dir)

    File.write!(
      pi_path,
      "#!/bin/sh\nIFS= read -r line\nprintf '%s' \"$line\" > #{prompt_path}\nprintf '%s' \"${MIX_ENV-unset}\" > #{mix_env_path}\nprintf '{\"type\":\"agent_settled\"}\\n'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    original_mix_env = System.fetch_env("MIX_ENV")
    System.put_env(%{"PATH" => "#{pi_dir}:#{original_path}", "MIX_ENV" => "prod"})

    on_exit(fn ->
      System.put_env("PATH", original_path)
      restore_mix_env(original_mix_env)
      File.rm(prompt_path)
      File.rm(mix_env_path)
      File.rm_rf!(pi_dir)
    end)

    AutomationRunner.run(%{automation(job_name, "* * * * *") | use_skill: false})

    prompt = File.read!(prompt_path)
    assert File.read!(mix_env_path) == "unset"
    assert prompt =~ "Run it"
    refute prompt =~ "/skill:"
  end

  test "persists bot automation execution and assistant result" do
    job_name = "automation-#{System.unique_integer([:positive])}"
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    File.mkdir_p!(pi_dir)

    bot =
      Repo.insert!(%Bot{
        name: "Ops",
        role: "operator",
        description: "Operate safely",
        chat_remote_session_id: "chat-ops",
        background_remote_session_id: "background-ops"
      })

    File.write!(
      pi_path,
      "#!/bin/sh\nIFS= read -r line\nprintf '%s\\n' '{\"type\":\"message_end\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Done\"}]}}' '{\"type\":\"agent_settled\"}'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")

    on_exit(fn ->
      System.put_env("PATH", original_path)
      Repo.delete_all(Message)
      Repo.delete(bot)
      File.rm_rf!(pi_dir)
    end)

    AutomationRunner.run(%{automation(job_name, "* * * * *") | use_skill: false, bot_id: bot.id})

    assert [result] = Messages.list_for_bot(bot.id)
    assert result.kind == "result"
    assert result.content == "Done"
  end

  test "registers monitored automation work while it is running" do
    job_name = "automation-#{System.unique_integer([:positive])}"
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    gate_path = temp_path()
    File.mkdir_p!(pi_dir)

    File.write!(
      pi_path,
      "#!/bin/sh\nwhile [ ! -e #{gate_path} ]; do sleep 0.01; done\nprintf '{\"type\":\"agent_settled\"}\\n'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")
    RemoteRegistry.subscribe()

    on_exit(fn ->
      File.write!(gate_path, "")
      System.put_env("PATH", original_path)
      File.rm(gate_path)
      File.rm_rf!(pi_dir)

      RemoteSessions.list()
      |> Enum.filter(&(&1["name"] == job_name and &1["source"] == "automation"))
      |> Enum.each(&RemoteSessions.delete(&1["id"]))
    end)

    task =
      Task.async(fn ->
        AutomationRunner.run(%{
          automation(job_name, "* * * * *")
          | use_skill: false,
            monitor: true
        })
      end)

    assert_receive :changed

    assert [%{sessions: [%{id: id, status: "working", title: ^job_name}]}] =
             ProjectSessionCatalog.automation_groups(RemoteRegistry.list())

    File.write!(gate_path, "")
    Task.await(task)
    _ = :sys.get_state(RemoteRegistry)
    assert_receive :changed
    assert %{"status" => "settled"} = RemoteSessions.get(id)
  end

  test "marks monitored automations as failed when Pi returns an error" do
    job_name = "automation-#{System.unique_integer([:positive])}"
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    File.mkdir_p!(pi_dir)

    File.write!(
      pi_path,
      "#!/bin/sh\nIFS= read -r line\nprintf '{\"type\":\"response\",\"success\":false,\"error\":\"failed\"}\\n'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")

    on_exit(fn ->
      System.put_env("PATH", original_path)
      File.rm_rf!(pi_dir)

      RemoteSessions.list()
      |> Enum.filter(&(&1["name"] == job_name and &1["source"] == "automation"))
      |> Enum.each(&RemoteSessions.delete(&1["id"]))
    end)

    AutomationRunner.run(%{automation(job_name, "* * * * *") | use_skill: false, monitor: true})
    _ = :sys.get_state(RemoteRegistry)

    assert %{"status" => "failed"} =
             RemoteSessions.list()
             |> Enum.find(&(&1["name"] == job_name and &1["source"] == "automation"))
  end

  test "logs the failed automation and reason" do
    job_name = "missing-#{System.unique_integer([:positive])}"

    log = capture_log(fn -> AutomationRunner.run(automation(job_name, "* * * * *")) end)

    assert log =~ "Automation failed: #{job_name}. Reason: Skill not found: #{job_name}"
  end

  test "validates every schedule before atomically replacing enabled jobs" do
    previous = automation("previous", "*/5 * * * * *")
    invalid_disabled = %{automation("disabled", "not a cron expression") | enabled: false}

    assert :ok = Automation.replace([previous])
    sync_subscription()

    assert {:error, "Invalid schedule for disabled: " <> _reason} =
             AutomationScheduler.replace([automation("next", "* * * * * *"), invalid_disabled])

    assert [{_, job}] = AutomationScheduler.jobs()
    assert {AutomationRunner, :run, [%{job_name: "previous"}]} = job.task
  end

  test "replaces schedules with enabled automations only" do
    disabled = %{automation("disabled", "* * * * *") | enabled: false}

    assert :ok = AutomationScheduler.replace([automation("enabled", "* * * * *"), disabled])

    assert [{_, %{task: {AutomationRunner, :run, [%{job_name: "enabled"}]}}}] =
             AutomationScheduler.jobs()
  end

  test "uses the seconds parser and overlap setting" do
    automation = %{automation("seconds", "*/5 * * * * *") | can_overlap: true}
    assert :ok = AutomationScheduler.replace([automation])

    assert [{_, job}] = AutomationScheduler.jobs()
    assert inspect(job.schedule) == "~e[*/5 * * * * * *]e"
    assert job.overlap
  end

  test "empty pre-script output skips Pi and post-script without notifying its bot" do
    bot =
      Repo.insert!(%Bot{
        name: "Skip",
        role: "operator",
        description: "Skips empty work",
        chat_remote_session_id: "chat-skip",
        background_remote_session_id: "background-skip"
      })

    job_name = "automation-#{System.unique_integer([:positive])}"
    skill_path = Path.join([System.user_home!(), ".pi", "agent", "skills", job_name])
    pi_marker = temp_path()
    post_marker = temp_path()
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    File.mkdir_p!(Path.join(skill_path, "scripts"))
    File.mkdir_p!(pi_dir)
    File.write!(Path.join(skill_path, "scripts/preScript.ts"), "console.log()")

    File.write!(
      Path.join(skill_path, "scripts/postScript.ts"),
      "await Bun.write(#{inspect(post_marker)}, \"post\")"
    )

    File.write!(
      pi_path,
      "#!/bin/sh\nIFS= read -r line\ntouch #{pi_marker}\nprintf '{\"type\":\"agent_settled\"}\\n'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")

    on_exit(fn ->
      System.put_env("PATH", original_path)
      File.rm_rf!(skill_path)
      File.rm(pi_marker)
      File.rm(post_marker)
      File.rm_rf!(pi_dir)
      Repo.delete_all(Message)
      Repo.delete(bot)
    end)

    AutomationRunner.run(%{automation(job_name, "* * * * *") | bot_id: bot.id})
    assert [] = Messages.list_for_bot(bot.id)
    refute File.exists?(pi_marker)
    refute File.exists?(post_marker)
  end

  test "removes MIX_ENV from skill scripts" do
    job_name = "automation-#{System.unique_integer([:positive])}"
    skill_path = Path.join([System.user_home!(), ".pi", "agent", "skills", job_name])
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    pre_mix_env_path = temp_path()
    post_mix_env_path = temp_path()
    File.mkdir_p!(Path.join(skill_path, "scripts"))
    File.mkdir_p!(pi_dir)

    File.write!(
      Path.join(skill_path, "scripts/preScript.ts"),
      "await Bun.write(#{inspect(pre_mix_env_path)}, Bun.env.MIX_ENV ?? \"unset\")\nconsole.log(\"work\")"
    )

    File.write!(
      Path.join(skill_path, "scripts/postScript.ts"),
      "await Bun.write(#{inspect(post_mix_env_path)}, Bun.env.MIX_ENV ?? \"unset\")"
    )

    File.write!(
      pi_path,
      "#!/bin/sh\nIFS= read -r line\nprintf '{\"type\":\"agent_settled\"}\\n'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    original_mix_env = System.fetch_env("MIX_ENV")
    System.put_env(%{"PATH" => "#{pi_dir}:#{original_path}", "MIX_ENV" => "prod"})

    on_exit(fn ->
      System.put_env("PATH", original_path)
      restore_mix_env(original_mix_env)
      File.rm_rf!(skill_path)
      File.rm(pre_mix_env_path)
      File.rm(post_mix_env_path)
      File.rm_rf!(pi_dir)
    end)

    AutomationRunner.run(automation(job_name, "* * * * *"))

    assert File.read!(pre_mix_env_path) == "unset"
    assert File.read!(post_mix_env_path) == "unset"
  end

  test "runs an agent when the pre-script returns work" do
    job_name = "automation-#{System.unique_integer([:positive])}"
    skill_path = Path.join([System.user_home!(), ".pi", "agent", "skills", job_name])
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    pi_marker = temp_path()
    File.mkdir_p!(Path.join(skill_path, "scripts"))
    File.mkdir_p!(pi_dir)
    File.write!(Path.join(skill_path, "scripts/preScript.ts"), "console.log(\"work\")")

    File.write!(
      pi_path,
      "#!/bin/sh\nIFS= read -r line\ntouch #{pi_marker}\nprintf '%s\\n' '{\"type\":\"tool_execution_start\",\"toolName\":\"bash\"}' '{\"type\":\"tool_execution_end\",\"toolName\":\"bash\",\"isError\":false}' '{\"type\":\"agent_settled\"}'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")

    on_exit(fn ->
      System.put_env("PATH", original_path)
      File.rm_rf!(skill_path)
      File.rm(pi_marker)
      File.rm_rf!(pi_dir)
    end)

    AutomationRunner.run(automation(job_name, "* * * * *"))
    assert File.exists?(pi_marker)
  end

  defp sync_subscription do
    {WebApp.AutomationSubscription, pid, _, _} =
      Enum.find(Supervisor.which_children(WebApp.Supervisor), fn {id, _, _, _} ->
        id == WebApp.AutomationSubscription
      end)

    _ = :sys.get_state(pid)
  end

  defp automation(job_name, schedule) do
    %Automation{
      job_name: job_name,
      enabled: true,
      schedule: schedule,
      user_prompt: "Run it",
      daily_session: false,
      can_overlap: false,
      model: "model",
      thinking_level: "off",
      use_skill: true
    }
  end

  defp restore_mix_env({:ok, value}), do: System.put_env("MIX_ENV", value)
  defp restore_mix_env(:error), do: System.delete_env("MIX_ENV")

  defp temp_path do
    suffix = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    Path.join(System.tmp_dir!(), "automations-#{suffix}.json")
  end
end
