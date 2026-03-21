// Dashboard: APM — Traces & Services
// Question:  "How are my distributed services performing?"
//
// Consolidates: apm/pin-traces (service metrics), apm/skywalking.json (links),
//               observability/skywalking-traces (correlation guide)
//
// Data sources:
//   - VictoriaMetrics: OAP self-monitoring (job=skywalking-oap, scrapes :1234)
//                      meter_service_resp_time_* (OAP MAL — shows 0 until services send traces)
//   - VictoriaLogs: error logs
//   - SkyWalking UI: http://traces.pin (trace details, topology, span waterfall)

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Row 0: Status ─────────────────────────────────────────────────────────────
// OAP self-monitoring stats — always populated from :1234 scrape.

local alertPanel = c.alertCountPanel('skywalking-oap', col=0);

local oapUptimeStat =
  g.panel.stat.new('OAP Uptime')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('time() - process_start_time_seconds{job="skywalking-oap"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value');

local traceIngestRate =
  g.panel.stat.new('Trace Ingest Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(trace_in_latency_count{job="skywalking-oap"}[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local reqRate =
  g.panel.stat.new('Service Req / min')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(rate(meter_service_resp_time_count[5m])) or vector(0)) * 60'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqpm')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Row 1: Service Metrics ────────────────────────────────────────────────────
// meter_service_resp_time_* from OAP MAL — shows 0 until services send traces.

local errorRateStat =
  g.panel.stat.new('Service Error %')
  + c.pos(0, 5, 8, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(|||
      (((sum(rate(meter_service_resp_time_count{status="ERROR"}[1m])) or vector(0))
      / (sum(rate(meter_service_resp_time_count[5m])) or vector(0)))) * 100 or vector(0)
    |||),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local p99Stat =
  g.panel.stat.new('Service P99 Latency')
  + c.pos(8, 5, 8, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.99, sum by(le) (rate(meter_service_resp_time_bucket[5m])))) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 200 },
    { color: 'red', value: 1000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local oapHeapStat =
  g.panel.stat.new('OAP Heap Used')
  + c.pos(16, 5, 8, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_memory_bytes_used{job="skywalking-oap",area="heap"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value');

local throughputSparkline =
  g.panel.timeSeries.new('Service Throughput')
  + c.pos(0, 8, 16, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(sum(rate(meter_service_resp_time_count[5m])) or vector(0)) * 60',
      'req/min'
    ),
    c.vmQ(
      '(sum(rate(meter_service_resp_time_count{status="ERROR"}[5m])) or vector(0)) * 60',
      'errors/min'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqpm')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi')
  + {
    fieldConfig+: {
      overrides: [{
        matcher: { id: 'byName', options: 'errors/min' },
        properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'red' } }],
      }],
    },
  };

local traceIngestLatencyTs =
  g.panel.timeSeries.new('OAP Trace Ingestion Latency')
  + c.pos(16, 8, 8, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.99, sum by(le) (rate(trace_in_latency_bucket{job="skywalking-oap"}[5m]))) or vector(0)',
      'p99'
    ),
    c.vmQ(
      'histogram_quantile(0.5, sum by(le) (rate(trace_in_latency_bucket{job="skywalking-oap"}[5m]))) or vector(0)',
      'p50'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: SkyWalking UI ──────────────────────────────────────────────────────

local skyWalkingUrl = c.config.skywalking_ui_url;

local swLinksPanel =
  g.panel.text.new('SkyWalking UI — Trace Explorer')
  + c.pos(0, 15, 24, 4)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;padding:16px;">
      <div style="display:flex;align-items:center;gap:16px;flex-wrap:wrap;justify-content:center;">
        <a href="| + skyWalkingUrl + |" target="_blank" style="
          padding:12px 28px;background:linear-gradient(135deg,#7c3aed,#5b21b6);
          color:#fff;text-decoration:none;border-radius:8px;font-weight:700;font-size:15px;
          box-shadow:0 2px 8px rgba(124,58,237,0.3);">
          🔍 SkyWalking UI
        </a>
        <a href="| + skyWalkingUrl + |/general/trace" target="_blank" style="
          padding:10px 18px;background:#f3f4f6;color:#374151;
          text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;">
          📍 Traces
        </a>
        <a href="| + skyWalkingUrl + |/general/service" target="_blank" style="
          padding:10px 18px;background:#f3f4f6;color:#374151;
          text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;">
          🗂️ Services
        </a>
        <a href="| + skyWalkingUrl + |/general/topology" target="_blank" style="
          padding:10px 18px;background:#f3f4f6;color:#374151;
          text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;">
          🕸️ Topology
        </a>
        <a href="| + skyWalkingUrl + |/dashboard/list" target="_blank" style="
          padding:10px 18px;background:#f3f4f6;color:#374151;
          text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;">
          📊 Dashboards
        </a>
      </div>
      <p style="color:#6b7280;font-size:12px;margin:0;text-align:center;">
        Service metrics (req/min, error%, latency) populate once services send traces via gRPC →
        <code style="background:#f3f4f6;padding:2px 6px;border-radius:3px;">192.168.0.4:11800</code>
      </p>
    </div>
  |||);

// ── Row 3: Trace-to-Logs Correlation ──────────────────────────────────────────

local correlationPanel =
  g.panel.text.new('Trace-to-Logs Correlation')
  + c.pos(0, 20, 24, 5)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Trace-to-Logs Correlation Workflow

    **1. Find a slow trace in SkyWalking:**
    Navigate to [traces.pin/general/trace](http://traces.pin/general/trace), filter by service/time, click trace → copy **Trace ID**.

    **2. Correlate in Grafana Logs:**
    Open [Observability — Logs](/d/observability-logs), search: `trace_id:"<paste-id>"`

    ---

    ### Instrument a New Service

    | Language | Method |
    |---|---|
    | Java | `-javaagent:skywalking-agent.jar` → OAP gRPC `192.168.0.4:11800` |
    | Python | `apache-skywalking` SDK |
    | System-level | SkyWalking Rover eBPF — no code changes |

    Always include `trace_id` as a JSON field in structured logs for full correlation.
  |||);

// ── Row 4: Error Logs (collapsed) ────────────────────────────────────────────

local errorLogsPanel =
  g.panel.logs.new('Service Error Logs')
  + c.logPos(30)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",level=~"(error|critical)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('APM — Traces & Services')
+ g.dashboard.withUid('apm-traces')
+ g.dashboard.withDescription('APM overview: OAP health, service throughput and error rates, SkyWalking UI entry points, trace-to-logs correlation.')
+ g.dashboard.withTags(['apm', 'traces', 'skywalking', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, oapUptimeStat, traceIngestRate, reqRate,

  g.panel.row.new('📈 Service Metrics') + c.pos(0, 6, 24, 1),
  errorRateStat, p99Stat, oapHeapStat,
  throughputSparkline, traceIngestLatencyTs,

  g.panel.row.new('🔍 SkyWalking UI') + c.pos(0, 16, 24, 1),
  swLinksPanel,

  g.panel.row.new('🔗 Trace Correlation') + c.pos(0, 21, 24, 1),
  correlationPanel,

  (g.panel.row.new('📝 Error Logs') + c.pos(0, 27, 24, 1) + { collapsed: true, panels: [
    errorLogsPanel,
  ] }),
])
