// api-gateway — Distributed Tracing & Performance
//
// Service-specific tracing dashboard showing:
// - Trace latency distribution and percentiles
// - Error rates and failure patterns
// - Span analysis (operation breakdown, duration)
// - Request flow and dependency tracing
// - Correlation with logs via trace_id
//
// Data sources:
// - SkyWalking OAP API (traces, spans)
// - VictoriaMetrics (trace metrics)
// - VictoriaLogs (application logs with trace_id)

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Service Tracing Stats ──────────────────────────────────────────────────

local tracesPerMinStat =
  g.panel.stat.new('Traces/min')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(skywalking_trace_total{service="api-gateway"}[1m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

local errorRateStat =
  g.panel.stat.new('Error Rate')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(count(skywalking_trace_status_total{service="api-gateway",status="error"}) / count(skywalking_trace_status_total{service="api-gateway"})) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local avgLatencyStat =
  g.panel.stat.new('Avg Latency')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.50, sum by(le) (rate(skywalking_trace_latency_bucket{service="api-gateway"}[5m]))) or vector(0))'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local p99LatencyStat =
  g.panel.stat.new('P99 Latency')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.99, sum by(le) (rate(skywalking_trace_latency_bucket{service="api-gateway"}[5m]))) or vector(0))'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1000 },
    { color: 'red', value: 5000 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Trace Distribution ──────────────────────────────────────────────────────

local traceVolumeTs =
  g.panel.timeSeries.new('Trace Volume (Success/Error)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(skywalking_trace_status_total{service="api-gateway",status="success"}[5m])', 'Success'),
    c.vmQ('rate(skywalking_trace_status_total{service="api-gateway",status="error"}[5m])', 'Error'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local latencyDistributionTs =
  g.panel.timeSeries.new('Latency Percentiles (p50/p95/p99)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.50, sum by(le) (rate(skywalking_trace_latency_bucket{service="api-gateway"}[5m])))', 'p50'),
    c.vmQ('histogram_quantile(0.95, sum by(le) (rate(skywalking_trace_latency_bucket{service="api-gateway"}[5m])))', 'p95'),
    c.vmQ('histogram_quantile(0.99, sum by(le) (rate(skywalking_trace_latency_bucket{service="api-gateway"}[5m])))', 'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Operation Breakdown ────────────────────────────────────────────────────

local operationCountTs =
  g.panel.timeSeries.new('Operation Count (Top 10)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('topk(10, rate(skywalking_span_total{service="api-gateway"}[5m]))', '{{operation}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local operationErrorsTs =
  g.panel.timeSeries.new('Operation Error Rate (Top 5 with errors)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('topk(5, (count by (operation) (skywalking_span_status_total{service="api-gateway",status="error"}) / count by (operation) (skywalking_span_status_total{service="api-gateway"})) * 100)', '{{operation}}%'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Span Analysis ──────────────────────────────────────────────────────────

local spanLatencyTable =
  g.panel.table.new('Operations by Avg Latency (5m)')
  + c.pos(0, 7, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(20, sort_desc(avg by (operation) (skywalking_span_latency_total{service="api-gateway"}) / avg by (operation) (skywalking_span_total{service="api-gateway"})))',
      'Avg Latency'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('ms')
  + g.panel.table.options.withSortBy([
    { displayName: 'Avg Latency', desc: true },
  ]);

// ── Dependency & Correlation Guide ─────────────────────────────────────────

local guidancePanel =
  g.panel.text.new('📊 Service Tracing & Correlation Guide')
  + c.pos(0, 15, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### 🔍 Analyze Slow Traces

    1. **Identify slow operation** in "Operations by Avg Latency" table
    2. **Go to SkyWalking UI**: [Traces for api-gateway](http://traces.pin/general/trace?service=api-gateway)
    3. **Filter by operation** and sort by duration (slowest first)
    4. **Click trace** → See span waterfall (shows where time is spent)
    5. **Note Trace ID** (e.g., `abc123...def456`)

    ### 🔗 Correlate with Logs

    6. **Open [Observability — Logs](/d/observability-logs)**
    7. **Search**: `service:"api-gateway" AND trace_id:"abc123"`
    8. **View full request context** across all services in request flow

    ### ⚠️ Investigate Errors

    - **Error Rate spike?** Check "Trace Volume" chart for timing
    - **Operation errors?** See "Operation Error Rate" for which operations are failing
    - **Check logs** for stack traces: `service:"api-gateway" AND level:"error"`
    - **Related alerts**: Check if error exceeded configured thresholds

    ### 📈 Performance Optimization

    - **High p99?** Look for outlier operations in latency distribution
    - **CPU spike correlation?** Compare with [Performance](/d/performance-optimization)
    - **Cache misses?** Check cache hit rates during slow traces
    - **Database queries?** Correlate with slow query logs
  |||);

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel(`${serviceName} Logs`, 'api-gateway', y=19);

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('api-gateway — Distributed Tracing')
+ g.dashboard.withUid('tracing-api-gateway')
+ g.dashboard.withDescription('Distributed tracing for api-gateway: trace latency, error rates, operation breakdown, span analysis, and logs correlation.')
+ g.dashboard.withTags(['observability', 'tracing', 'service', 'apm', 'api-gateway'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Overview') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  tracesPerMinStat, errorRateStat, avgLatencyStat, p99LatencyStat,

  g.panel.row.new('⚡ Trace Distribution & Performance') + c.pos(0, 4, 24, 1),
  traceVolumeTs, latencyDistributionTs,
  operationCountTs, operationErrorsTs,

  g.panel.row.new('🔍 Operation Analysis') + c.pos(0, 6, 24, 1),
  spanLatencyTable,

  g.panel.row.new('🛠️ Troubleshooting') + c.pos(0, 14, 24, 1),
  guidancePanel,

  g.panel.row.new('📝 Logs') + c.pos(0, 18, 24, 1),
  logsPanel,
])
