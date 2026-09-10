type AttributeValue = { stringValue: string } | { intValue: string };
type Attribute = { key: string; value: AttributeValue };
type Labels = Record<string, string>;
type CounterMetric = {
  type?: never;
  name: string;
  value: number;
  labels?: Labels;
};
type HistogramMetric = Omit<CounterMetric, "type"> & {
  type: "histogram";
};
type Metric = CounterMetric | HistogramMetric;
type Log = {
  event: string;
  labels?: Labels;
};

export type TelemetryFetch = (
  input: string,
  init: RequestInit,
) => Promise<Response>;

const serviceAttributes: Array<Attribute> = [
  { key: "service.name", value: { stringValue: "matato" } },
  { key: "service.version", value: { stringValue: "0.1.0" } },
];

const now = (): string => (BigInt(Date.now()) * 1_000_000n).toString();

const attributes = (labels: Labels = {}): Array<Attribute> =>
  Object.entries(labels).map(([key, value]) => ({
    key,
    value: { stringValue: value },
  }));

const collectorUrl = (endpoint: string, signal: "metrics" | "logs"): string =>
  `${endpoint.replace(/\/$/, "")}/v1/${signal}`;

const metricBody = (metric: Metric, timestamp: string): object => ({
  name: metric.name,
  unit: metric.name.endsWith("_seconds") ? "s" : undefined,
  ...(metric.type === "histogram"
    ? {
        histogram: {
          aggregationTemporality: 2,
          dataPoints: [
            {
              attributes: attributes(metric.labels),
              bucketCounts: [
                metric.value <= 1 ? 1 : 0,
                metric.value > 1 && metric.value <= 5 ? 1 : 0,
                metric.value > 5 ? 1 : 0,
              ],
              count: 1,
              explicitBounds: [1, 5],
              sum: metric.value,
              timeUnixNano: timestamp,
            },
          ],
        },
      }
    : {
        sum: {
          aggregationTemporality: 2,
          isMonotonic: true,
          dataPoints: [
            {
              attributes: attributes(metric.labels),
              asDouble: metric.value,
              timeUnixNano: timestamp,
            },
          ],
        },
      }),
});

export class OtlpExporter {
  constructor(
    private readonly endpoint: string | undefined,
    private readonly request: TelemetryFetch = fetch,
  ) {}

  exportMetrics(metrics: Array<Metric>): Promise<void> {
    if (!this.endpoint || !metrics.length) return Promise.resolve();
    const timestamp = now();
    return this.send("metrics", {
      resourceMetrics: [
        {
          resource: { attributes: serviceAttributes },
          scopeMetrics: [
            {
              scope: { name: "matato-pi.telemetry" },
              metrics: metrics.map((metric) => metricBody(metric, timestamp)),
            },
          ],
        },
      ],
    });
  }

  exportLogs(logs: Array<Log>): Promise<void> {
    if (!this.endpoint || !logs.length) return Promise.resolve();
    const timestamp = now();
    return this.send("logs", {
      resourceLogs: [
        {
          resource: { attributes: serviceAttributes },
          scopeLogs: [
            {
              scope: { name: "matato-pi.telemetry" },
              logRecords: logs.map((log) => ({
                timeUnixNano: timestamp,
                severityNumber: 9,
                severityText: "INFO",
                body: { stringValue: "Matato Pi lifecycle event" },
                attributes: attributes({ event: log.event, ...log.labels }),
              })),
            },
          ],
        },
      ],
    });
  }

  private async send(
    signal: "metrics" | "logs",
    body: Record<string, object>,
  ): Promise<void> {
    try {
      await this.request(collectorUrl(this.endpoint ?? "", signal), {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch {
      // Telemetry is best-effort and must never interrupt an agent run.
    }
  }
}

export type { Labels, Log, Metric };
