defmodule WebApp.AutomationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias WebApp.{Automation, AutomationRunner, AutomationScheduler}

  setup do
    :ok = Automation.replace([])
  end


  test "stores replacement automations for the shared database" do
    automation = %{automation("stored", "* * * * *") | can_launch_sub_agents: true}

    assert :ok = Automation.replace([automation])

    assert [
             %Automation{job_name: "stored", can_launch_sub_agents: true}
           ] = Automation.list()
  end

  test "rejects replacement automations with duplicate job names" do
    assert {:error, "Automation job names must be unique"} =
             Automation.replace([
               automation("duplicate", "* * * * *"),
               automation("duplicate", "*/5 * * * *")
             ])
  end


  test "logs the failed automation and reason" do
    job_name = "missing-#{System.unique_integer([:positive])}"

    log = capture_log(fn -> AutomationRunner.run(automation(job_name, "* * * * *")) end)

    assert log =~ "Automation failed: #{job_name}. Reason: Skill not found: #{job_name}"
  end

  test "validates every schedule before atomically replacing enabled jobs" do
    previous = automation("previous", "*/5 * * * * *")
    invalid_disabled = %{automation("disabled", "not a cron expression") | enabled: false}

    assert :ok = AutomationScheduler.replace([previous])

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

  test "uses the seconds parser for six-field schedules" do
    assert :ok = AutomationScheduler.replace([automation("seconds", "*/5 * * * * *")])

    assert [{_, job}] = AutomationScheduler.jobs()
    assert inspect(job.schedule) == "~e[*/5 * * * * * *]e"
  end

  test "empty pre-script output skips Pi and post-script" do
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
      "#!/bin/sh\ntouch #{pi_marker}\nprintf '{\"type\":\"agent_settled\"}\\n'\n"
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
    end)

    AutomationRunner.run(automation(job_name, "* * * * *"))
    refute File.exists?(pi_marker)
    refute File.exists?(post_marker)
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
      "#!/bin/sh\ntouch #{pi_marker}\nprintf '%s\\n' '{\"type\":\"tool_execution_start\",\"toolName\":\"bash\"}' '{\"type\":\"tool_execution_end\",\"toolName\":\"bash\",\"isError\":false}' '{\"type\":\"agent_settled\"}'\n"
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


  defp automation(job_name, schedule) do
    %Automation{
      job_name: job_name,
      enabled: true,
      schedule: schedule,
      user_prompt: "Run it",
      daily_session: false,
      model: "model",
      thinking_level: "off"
    }
  end

  defp temp_path do
    suffix = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    Path.join(System.tmp_dir!(), "automations-#{suffix}.json")
  end
end
