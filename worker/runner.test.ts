import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import {
  AgentSession,
  loadSkillsFromDir,
  type ResourceLoader,
} from "@earendil-works/pi-coding-agent";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { dailySessionArgs, resolveSkillPath, runAutomation } from "./runner.ts";
import type { Execute, ExecutionOptions } from "./process.ts";
import { automation, piEvents } from "./testFixtures.ts";

let root = "";
beforeEach(async () => {
  root = await mkdtemp(join(tmpdir(), "workerTest"));
});
afterEach(async () => {
  await rm(root, { recursive: true, force: true });
});

type Call = { command: string; args: Array<string>; options: ExecutionOptions };
function fakeRun(preOutput = "context", events = piEvents()) {
  const calls: Array<Call> = [];
  const execute: Execute = async (command, args, options) => {
    calls.push({ command, args, options });
    if (command === "pi") {
      options.onStdout?.(events);
      return "";
    }
    return args[0].endsWith("preScript.ts") ? preOutput : "";
  };
  return { execute, calls };
}

async function scripts(): Promise<string> {
  const skill = join(root, "example");
  await mkdir(join(skill, "scripts"), { recursive: true });
  await writeFile(join(skill, "scripts", "preScript.ts"), "");
  await writeFile(join(skill, "scripts", "postScript.ts"), "");
  return skill;
}

describe("standalone automation runner", () => {
  test("skill lookup prefers user skills then package paths, never cwd", async () => {
    const packageSkills = join(root, "package", "skills");
    const local = join(root, ".pi", "agent", "skills", "example");
    await mkdir(join(packageSkills, "example"), { recursive: true });
    expect(await resolveSkillPath("example", root, packageSkills)).toBe(
      join(packageSkills, "example"),
    );
    await mkdir(local, { recursive: true });
    expect(await resolveSkillPath("example", root, packageSkills)).toBe(local);
    expect(await resolveSkillPath("web-search", root)).toBe(
      fileURLToPath(new URL("../skills/web-search", import.meta.url)),
    );
    await expect(
      resolveSkillPath("missing", root, packageSkills),
    ).rejects.toThrow("Skill not found");
    await expect(
      resolveSkillPath("../example", root, packageSkills),
    ).rejects.toThrow("Invalid skill name");
  });

  test("prompt-only jobs need no skill and inherit env with storage/subagent controls", async () => {
    const fake = fakeRun();
    await runAutomation(automation(), {
      execute: fake.execute,
      configPath: root,
      env: { TEST_VALUE: "inherited", PI_SUBAGENT_DEPTH: "0" },
      resolveSkill: async () => {
        throw new Error("must not resolve a skill");
      },
    });
    expect(fake.calls).toHaveLength(1);
    expect(fake.calls[0].command).toBe("pi");
    expect(fake.calls[0].args).toContain("--print");
    expect(fake.calls[0].args).not.toContain("rpc");
    expect(fake.calls[0].args.at(-1)).toBe("Run the job");
    expect(fake.calls[0].args).not.toContain("--skill");
    expect(fake.calls[0].options.env).toMatchObject({
      MATATO_PI_CONFIG: root,
      TEST_VALUE: "inherited",
      PI_SUBAGENT_DEPTH: "1",
    });
  });

  test("allowing subagents preserves inherited depth", async () => {
    const fake = fakeRun();
    await runAutomation(automation({ canLaunchSubAgents: true }), {
      execute: fake.execute,
      env: { PI_SUBAGENT_DEPTH: "2" },
    });
    expect(fake.calls[0].options.env.PI_SUBAGENT_DEPTH).toBe("2");
  });

  test("pre-script context, explicit skill, daily session, post-script order", async () => {
    const skill = await scripts();
    const fake = fakeRun("  useful context\n");
    const date = new Date(2026, 0, 2);
    expect(
      await runAutomation(automation({ useSkill: true, dailySession: true }), {
        execute: fake.execute,
        resolveSkill: async () => skill,
        configPath: root,
        now: () => date,
      }),
    ).toBe("completed");
    expect(fake.calls.map((call) => call.command)).toEqual([
      "bun",
      "pi",
      "bun",
    ]);
    expect(fake.calls[1].args).toContain(skill);
    expect(fake.calls[1].args.at(-1)).toBe(
      "/skill:example Run the job\n\nPre-script output:\nuseful context",
    );
    expect(fake.calls[1].args).toContain("example-2026-01-02");
    expect(fake.calls[1].args).toContain(join(root, "sessions"));
    for (const call of fake.calls)
      expect(call.options.env.MATATO_PI_CONFIG).toBe(root);
    expect(fake.calls[0].options.cwd).toBe(skill);
    expect(fake.calls[2].args[0]).toBe(join(skill, "scripts", "postScript.ts"));
  });

  test("Pi's actual skill parser expands the prompt and preserves multiline context", async () => {
    const skill = await scripts();
    await writeFile(
      join(skill, "SKILL.md"),
      "---\nname: example\ndescription: Test skill\n---\nFollow the skill instructions.",
    );
    const fake = fakeRun("first context line\nsecond context line");
    await runAutomation(
      automation({ useSkill: true, userPrompt: "Run the job\nKeep this line" }),
      { execute: fake.execute, resolveSkill: async () => skill },
    );
    const prompt = fake.calls[1].args.at(-1);
    if (!prompt) throw new Error("Missing Pi prompt");
    const resourceLoader: Pick<ResourceLoader, "getSkills"> = {
      getSkills: () => loadSkillsFromDir({ dir: skill, source: "test" }),
    };
    // Invoke the installed parser only: no session startup or model requests.
    const expanded = AgentSession.prototype["_expandSkillCommand"].call(
      { resourceLoader },
      prompt,
    );
    expect(expanded).toBe(
      `<skill name="example" location="${join(skill, "SKILL.md")}">\nReferences are relative to ${skill}.\n\nFollow the skill instructions.\n</skill>\n\nRun the job\nKeep this line\n\nPre-script output:\nfirst context line\nsecond context line`,
    );
  });

  test("trim-empty pre-script skips Pi and post-script", async () => {
    const skill = await scripts();
    const fake = fakeRun(" \n\t");
    expect(
      await runAutomation(automation({ useSkill: true }), {
        execute: fake.execute,
        resolveSkill: async () => skill,
      }),
    ).toBe("skipped");
    expect(fake.calls).toHaveLength(1);
  });

  test("scripts are optional and non-daily jobs omit daily session flags", async () => {
    const fake = fakeRun();
    await runAutomation(automation({ useSkill: true }), {
      execute: fake.execute,
      resolveSkill: async () => root,
    });
    expect(fake.calls).toHaveLength(1);
    expect(fake.calls[0].args.at(-1)).toBe("/skill:example Run the job");
    expect(dailySessionArgs(automation())).toEqual([]);
  });

  test("zero-exit JSON provider failure prevents post-script", async () => {
    const skill = await scripts();
    const fake = fakeRun("context", piEvents("error", "provider failed"));
    await expect(
      runAutomation(automation({ useSkill: true }), {
        execute: fake.execute,
        resolveSkill: async () => skill,
      }),
    ).rejects.toThrow("provider failed");
    expect(fake.calls.map((call) => call.command)).toEqual(["bun", "pi"]);
  });

  test("subprocess failures propagate and do not launch later steps", async () => {
    const skill = await scripts();
    const calls: Array<string> = [];
    const execute: Execute = async (command) => {
      calls.push(command);
      throw new Error("failed child");
    };
    await expect(
      runAutomation(automation({ useSkill: true }), {
        execute,
        resolveSkill: async () => skill,
      }),
    ).rejects.toThrow("failed child");
    expect(calls).toEqual(["bun"]);
    await expect(runAutomation(automation(), { execute })).rejects.toThrow(
      "failed child",
    );
    expect(calls).toEqual(["bun", "pi"]);
  });

  test("standalone monitor cannot launch Pi", async () => {
    const fake = fakeRun();
    await expect(
      runAutomation(automation({ monitor: true }), { execute: fake.execute }),
    ).rejects.toThrow("not supported");
    expect(fake.calls).toEqual([]);
  });
});
