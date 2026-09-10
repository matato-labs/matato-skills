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
  const pendingSkills: Array<string> = [];
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
    if (skill) pendingSkills.push(skill);
  });

  pi.on("before_agent_start", (event, ctx) => {
    promptStartedAt = Date.now();
    const skillIndex = pendingSkills.findIndex((skill) =>
      event.prompt.startsWith(`<skill name="${skill}" `),
    );
    const skill =
      skillIndex === -1 ? undefined : pendingSkills.splice(skillIndex, 1)[0];
    activeSkill = skill
      ? { name: skill, startedAt: promptStartedAt }
      : undefined;
    void exporter.exportMetrics([
      {
        name: "matato_agent_prompts_total",
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
      {
        name: "matato_agent_prompt_results_total",
        value: 1,
        labels: { result },
      },
      {
        name: "matato_agent_duration_seconds",
        type: "histogram",
        value: duration,
        labels: { result },
      },
    ];
    if (usage) {
      metrics.push(
        {
          name: "matato_agent_token_input_total",
          value: usage.input,
        },
        {
          name: "matato_agent_token_output_total",
          value: usage.output,
        },
        {
          name: "matato_agent_token_cache_read_total",
          value: usage.cacheRead,
        },
        {
          name: "matato_agent_token_cache_write_total",
          value: usage.cacheWrite,
        },
        { name: "matato_agent_cost_usd_total", value: usage.cost.total },
      );
    }
    void exporter.exportMetrics(metrics);
    void exporter.exportLogs([{ event: "agent_finished", labels: { result } }]);
  });

  pi.on("agent_settled", () => {
    if (promptStartedAt) {
      void exporter.exportMetrics([
        {
          name: "matato_agent_prompt_duration_seconds",
          type: "histogram",
          value: secondsSince(promptStartedAt),
          labels: { result: lastResult },
        },
      ]);
    }
    if (activeSkill) {
      void exporter.exportMetrics([
        {
          name: "matato_agent_skill_duration_seconds",
          type: "histogram",
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
        name: "matato_agent_tool_executions_total",
        value: 1,
        labels: { tool_name: event.toolName, result },
      },
      {
        name: "matato_agent_tool_duration_seconds",
        type: "histogram",
        value: startedAt ? secondsSince(startedAt) : 0,
        labels: { tool_name: event.toolName, result },
      },
    ]);
    void exporter.exportLogs([
      { event: "tool_finished", labels: { tool_name: event.toolName, result } },
    ]);
  });
}
