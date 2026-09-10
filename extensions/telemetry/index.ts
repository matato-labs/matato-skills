import type {
  AgentEndEvent,
  ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { OtlpExporter, type Metric } from "../../src/telemetry.ts";

type ActiveSkill = { name: string; startedAt: number };

const secondsSince = (startedAt: number): number =>
  (Date.now() - startedAt) / 1_000;

const resultFor = (event: AgentEndEvent): string => {
  const assistant = [...event.messages]
    .reverse()
    .find((message) => message.role === "assistant");
  return assistant?.role === "assistant" ? assistant.stopReason : "unknown";
};

export default function (pi: ExtensionAPI): void {
  const exporter = new OtlpExporter(process.env.OTEL_ENDPOINT);
  const pendingSkills: Array<string | undefined> = [];
  const toolStarts = new Map<string, number>();
  let promptStartedAt: number | undefined;
  let activeSkill: ActiveSkill | undefined;
  let agentStartedAt: number | undefined;
  let lastResult = "unknown";

  pi.on("session_start", (event) => {
    void exporter.exportLogs([
      { event: "session_started", labels: { reason: event.reason } },
    ]);
  });

  pi.on("session_shutdown", (event) => {
    void exporter.exportLogs([
      { event: "session_stopped", labels: { reason: event.reason } },
    ]);
  });

  pi.on("input", (event) => {
    const skill = event.text.match(/^\/skill:([\w-]+)(?:\s|$)/)?.[1];
    pendingSkills.push(skill);
  });

  pi.on("before_agent_start", (_event, ctx) => {
    promptStartedAt = Date.now();
    const skill = pendingSkills.shift();
    activeSkill = skill
      ? { name: skill, startedAt: promptStartedAt }
      : undefined;
    void exporter.exportMetrics([
      {
        name: "matato_pi_prompts_total",
        value: 1,
        labels: { source: ctx.mode },
      },
    ]);
    void exporter.exportLogs([
      { event: "prompt_started", labels: { source: ctx.mode } },
    ]);
  });

  pi.on("agent_start", () => {
    agentStartedAt = Date.now();
    void exporter.exportLogs([{ event: "agent_started" }]);
  });

  pi.on("agent_end", (event) => {
    const result = resultFor(event);
    lastResult = result;
    const duration = agentStartedAt ? secondsSince(agentStartedAt) : 0;
    const assistant = [...event.messages]
      .reverse()
      .find((message) => message.role === "assistant");
    const usage = assistant?.role === "assistant" ? assistant.usage : undefined;
    const metrics: Array<Metric> = [
      { name: "matato_pi_agent_runs_total", value: 1, labels: { result } },
      {
        name: "matato_pi_agent_duration_seconds",
        value: duration,
        labels: { result },
      },
    ];
    if (usage) {
      metrics.push(
        {
          name: "matato_pi_tokens_total",
          value: usage.input,
          labels: { type: "input" },
        },
        {
          name: "matato_pi_tokens_total",
          value: usage.output,
          labels: { type: "output" },
        },
        {
          name: "matato_pi_tokens_total",
          value: usage.cacheRead,
          labels: { type: "cache_read" },
        },
        {
          name: "matato_pi_tokens_total",
          value: usage.cacheWrite,
          labels: { type: "cache_write" },
        },
        { name: "matato_pi_cost_dollars_total", value: usage.cost.total },
      );
    }
    void exporter.exportMetrics(metrics);
    void exporter.exportLogs([{ event: "agent_finished", labels: { result } }]);
  });

  pi.on("agent_settled", () => {
    if (promptStartedAt) {
      void exporter.exportMetrics([
        {
          name: "matato_pi_prompt_duration_seconds",
          value: secondsSince(promptStartedAt),
          labels: { result: lastResult },
        },
      ]);
    }
    if (activeSkill) {
      void exporter.exportMetrics([
        {
          name: "matato_pi_explicit_skill_duration_seconds",
          value: secondsSince(activeSkill.startedAt),
          labels: { skill_name: activeSkill.name },
        },
      ]);
      void exporter.exportLogs([
        {
          event: "explicit_skill_finished",
          labels: { skill_name: activeSkill.name },
        },
      ]);
    }
    promptStartedAt = undefined;
    activeSkill = undefined;
  });

  pi.on("tool_execution_start", (event) => {
    toolStarts.set(event.toolCallId, Date.now());
  });

  pi.on("tool_execution_end", (event) => {
    const startedAt = toolStarts.get(event.toolCallId);
    toolStarts.delete(event.toolCallId);
    const result = event.isError ? "error" : "success";
    void exporter.exportMetrics([
      {
        name: "matato_pi_tools_total",
        value: 1,
        labels: { tool_name: event.toolName, result },
      },
      {
        name: "matato_pi_tool_duration_seconds",
        value: startedAt ? secondsSince(startedAt) : 0,
        labels: { tool_name: event.toolName, result },
      },
    ]);
    void exporter.exportLogs([
      { event: "tool_finished", labels: { tool_name: event.toolName, result } },
    ]);
  });
}
