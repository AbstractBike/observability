// SkyWalking Distributed Tracing Dashboard
//
// Provides comprehensive trace-level observability:
// - Recent traces with status and latency
// - Top services by error rate, latency, throughput
// - Span distribution and operation analysis
// - Trace-to-logs correlation via trace_id
// - Links to SkyWalking UI for detailed topology and trace inspection
//
// Data sources:
// - SkyWalking OAP GraphQL/REST API (traces, services, spans)
// - VictoriaLogs with trace_id field (correlate traces → logs)
// - VictoriaMetrics for service latency metrics

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Service Metrics ──────────────────────────────────────────────────────────

// Number of services currently traced
local serviceCountStat =
  g.panel.stat.new('Traced Services')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (job) ({__name__=~"skywalking.*"}))'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// Avg latency across all services (p95)
local avgLatencyStat =
  g.panel.stat.new('Avg Latency (p95)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.95, sum by(le) (rate(skywalking_trace_latency_bucket[5m]))) or vector(0))'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

// Error rate across all services
local errorRateStat =
  g.panel.stat.new('Trace Error Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(count(skywalking_trace_status_total{status="error"}) / count(skywalking_trace_status_total)) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

// Total traces in last 24h
local tracesTotal24hStat =
  g.panel.stat.new('Traces (24h)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(skywalking_trace_total[24h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

// ── Service Performance ──────────────────────────────────────────────────────

// Top services by error rate (potential issues)
local errorRateByServiceTs =
  g.panel.timeSeries.new('Error Rate by Service (Top 10)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (count by (service) (skywalking_trace_status_total{status="error"}) / count by (service) (skywalking_trace_status_total)) * 100)',
      '{{service}}%'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// Latency percentiles by service (top latency outliers)
local latencyByServiceTs =
  g.panel.timeSeries.new('Latency P95 by Service (Top 10)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, histogram_quantile(0.95, sum by(service,le) (rate(skywalking_trace_latency_bucket[5m]))))',
      '{{service}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Trace Volume & Status ────────────────────────────────────────────────────

local traceVolumeTs =
  g.panel.timeSeries.new('Trace Volume (Success/Error)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(skywalking_trace_status_total{status="success"}[5m])', 'Success'),
    c.vmQ('rate(skywalking_trace_status_total{status="error"}[5m])', 'Error'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// Span distribution (operation types)
local spanDistributionTs =
  g.panel.timeSeries.new('Span Count by Operation (Top 5)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(5, rate(skywalking_span_total[5m]))',
      '{{operation}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Recent Traces Table ──────────────────────────────────────────────────────

local recentTracesPanel =
  g.panel.text.new('Recent Traces & Correlation')
  + c.pos(0, 9, 24, 2)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Finding Recent Traces

    **In SkyWalking UI:**
    1. Open [SkyWalking Traces](http://traces.pin/general/trace)
    2. Filter by service or time range
    3. Click any trace to see span details, service dependencies, latency breakdown

    **In Grafana Logs:**
    - Use trace_id to correlate: `service:"svc-name" AND trace_id:"<id>"`
    - Paste trace ID from SkyWalking → search logs with same ID
    - See full request flow from application logs alongside trace spans

    **Trace Status Color Coding:**
    - 🟢 Green: Success (0 errors in any span)
    - 🔴 Red: Error (at least one span has error)
    - 🟡 Yellow: Degraded (latency > P95)
  |||);

// ── Top Endpoints (by latency impact) ─────────────────────────────────────

local topEndpointsTable =
  g.panel.table.new('Top 15 Operations by Latency Impact (5m)')
  + c.pos(0, 11, 24, 7)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(15, sort_desc(sum by (operation) (rate(skywalking_span_total[5m]) * histogram_quantile(0.95, sum by (operation,le) (rate(skywalking_span_latency_bucket[5m]))))))',
      'Latency Impact'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('ms')
  + g.panel.table.options.withSortBy([
    { displayName: 'Value', desc: true },
  ]);

// ── Trace-to-Logs Correlation Guide ──────────────────────────────────────────

local correlationGuidePanel =
  g.panel.text.new('📊 Distributed Tracing & Related Dashboards')
  + c.pos(0, 18, 24, 4)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Related Dashboards & Tools
    - **[Services Health](/d/services-health)** — Real-time service availability (complements trace data)
    - **[Performance & Optimization](/d/performance-optimization)** — Correlate trace latency with resource usage
    - **[Observability — Logs](/d/observability-logs)** — Logs indexed by service + trace_id for full request context
    - **[SkyWalking UI](http://traces.pin)** — Service topology, detailed trace inspection, span waterfall charts

    ### Trace-to-Logs Correlation Workflow

    **1. Find a slow trace in SkyWalking:**
    - Navigate to http://traces.pin/general/trace
    - Filter by service/time, sort by duration
    - Click trace → Note the **Trace ID** (e.g., `abc123...`)

    **2. Correlate with logs in Grafana:**
    - Open [Observability — Logs](/d/observability-logs)
    - Search: `trace_id:"abc123"`
    - See all application logs for this request across all services

    **3. Cross-reference with metrics:**
    - Use timestamp + service from trace
    - Check [Performance](/d/performance-optimization) for CPU/memory during trace time window
    - Correlate resource spikes with span latencies

    ### Instrumentation Status
    - **Java services**: SkyWalking Java Agent (`-javaagent:agent.jar`)
    - **Python services**: `apache-skywalking` SDK (manual setup)
    - **System-level**: SkyWalking Rover eBPF (automatic, no code changes)
    - **Manual correlation**: Always include `trace_id` in structured logs (JSON field)

    ### Key SkyWalking Endpoints
    - **OAP gRPC** (agent ingest): `192.168.0.4:11800`
    - **OAP HTTP/GraphQL** (APIs): `192.168.0.4:12800`
    - **SkyWalking UI**: `http://traces.pin` (service maps, trace details)
  |||);

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('SkyWalking OAP Logs', 'skywalking-oap', y=23);

// ── Dashboard ──────────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Distributed Tracing')
+ g.dashboard.withUid('skywalking-traces')
+ g.dashboard.withDescription('Distributed tracing across all services: trace volumes, error rates, latency, service dependencies. Includes trace-to-logs correlation guide.')
+ g.dashboard.withTags(['observability', 'tracing', 'skywalking', 'distributed-tracing', 'apm'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Service Overview') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  serviceCountStat, avgLatencyStat, errorRateStat, tracesTotal24hStat,

  g.panel.row.new('⚡ Performance Trends') + c.pos(0, 4, 24, 1),
  errorRateByServiceTs, latencyByServiceTs,
  traceVolumeTs, spanDistributionTs,

  g.panel.row.new('🔍 Analysis & Correlation') + c.pos(0, 8, 24, 1),
  recentTracesPanel,
  topEndpointsTable,

  g.panel.row.new('📝 Instrumentation Guide') + c.pos(0, 17, 24, 1),
  correlationGuidePanel,

  g.panel.row.new('📝 Logs') + c.pos(0, 22, 24, 1),
  logsPanel,
])
