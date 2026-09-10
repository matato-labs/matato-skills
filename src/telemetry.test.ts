import { describe, expect, test } from "bun:test";
import { OtlpExporter } from "./telemetry.ts";

type ReceivedRequest = { path: string; body: string };

const withCollector = async (
  run: (endpoint: string, requests: Array<ReceivedRequest>) => Promise<void>,
): Promise<void> => {
  const requests: Array<ReceivedRequest> = [];
  const server = Bun.serve({
    port: 0,
    async fetch(request) {
      requests.push({
        path: new URL(request.url).pathname,
        body: await request.text(),
      });
      return new Response(null, { status: 200 });
    },
  });
  try {
    await run(server.url.toString().slice(0, -1), requests);
  } finally {
    server.stop();
  }
};

describe("OTLP telemetry exporter", () => {
  test("exports privacy-safe metrics and lifecycle logs to a local collector", async () => {
    await withCollector(async (endpoint, requests) => {
      const exporter = new OtlpExporter(endpoint);
      await exporter.exportMetrics([
        {
          name: "matato_pi_tools_total",
          value: 1,
          labels: { tool_name: "bash", result: "success" },
        },
      ]);
      await exporter.exportLogs([
        { event: "tool_finished", labels: { result: "success" } },
      ]);

      expect(requests.map((request) => request.path)).toEqual([
        "/v1/metrics",
        "/v1/logs",
      ]);
      const metrics = JSON.parse(requests[0]?.body ?? "{}") as {
        resourceMetrics: Array<{
          scopeMetrics: Array<{
            metrics: Array<{
              name: string;
              sum: { dataPoints: Array<{ asDouble: number }> };
            }>;
          }>;
        }>;
      };
      expect(metrics.resourceMetrics[0]?.scopeMetrics[0]?.metrics[0]).toEqual(
        expect.objectContaining({
          name: "matato_pi_tools_total",
          sum: expect.objectContaining({
            dataPoints: [expect.objectContaining({ asDouble: 1 })],
          }),
        }),
      );
      const exported = requests.map((request) => request.body).join("\n");
      expect(exported).toContain("matato-pi");
      expect(exported).not.toContain("/home/");
      expect(exported).not.toContain("tool arguments");
    });
  });

  test("swallows collector failures", async () => {
    const exporter = new OtlpExporter("http://127.0.0.1:1", async () => {
      throw new Error("collector unavailable");
    });

    await expect(
      exporter.exportMetrics([{ name: "matato_pi_prompts_total", value: 1 }]),
    ).resolves.toBeUndefined();
  });

  test("does nothing without OTEL_ENDPOINT", async () => {
    let calls = 0;
    const exporter = new OtlpExporter(undefined, async () => {
      calls += 1;
      return new Response();
    });

    await exporter.exportLogs([{ event: "agent_started" }]);
    expect(calls).toBe(0);
  });
});
