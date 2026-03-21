// Dashboard: APM (merged)
//
// Consolidates:
//   apm/api-gateway-tracing  — API gateway distributed tracing
//   apm/pin-traces            — APM overview: all-service health via SkyWalking OAP
//   apm/postgres-query-tracing — PostgreSQL query latency & slow queries
//   apm/traces-unified        — OAP self-monitoring, SkyWalking UI links, trace-to-log correlation
//
// Data sources:
//   - VictoriaMetrics  ($datasource)   — skywalking_* metrics, meter_service_*, OAP self-monitoring
//   - VictoriaLogs     ($vlogs)        — application logs with trace_id
//   - SkyWalking OAP   ($swdatasource) — PromQL endpoint (port 9090)

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── apm/api-gateway-tracing panels ────────────────────────────────────────────

local agAlertPanel = c.alertCountPanel('api-gateway', col=0);

local agTracesPerMinStat =
  g.panel.stat.new('Traces/min')
  + c.pos(0, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(skywalking_trace_total{service="api-gateway"}[1m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

local agErrorRateStat =
  g.panel.stat.new('Error Rate')
  + c.pos(6, 1, 6, 3)
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

local agAvgLatencyStat =
  g.panel.stat.new('Avg Latency')
  + c.pos(12, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.50, sum by(le) (rate(skywalking_trace_latency_bucket{service="api-gateway"}[5m]))) or vector(0))'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local agP99LatencyStat =
  g.panel.stat.new('P99 Latency')
  + c.pos(18, 1, 6, 3)
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

local agTraceVolumeTs =
  g.panel.timeSeries.new('Trace Volume (Success/Error)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(skywalking_trace_status_total{service="api-gateway",status="success"}[5m])', 'Success'),
    c.vmQ('rate(skywalking_trace_status_total{service="api-gateway",status="error"}[5m])', 'Error'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local agLatencyDistributionTs =
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

local agOperationCountTs =
  g.panel.timeSeries.new('Operation Count (Top 10)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('topk(10, rate(skywalking_span_total{service="api-gateway"}[5m]))', '{{operation}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local agOperationErrorsTs =
  g.panel.timeSeries.new('Operation Error Rate (Top 5 with errors)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('topk(5, (count by (operation) (skywalking_span_status_total{service="api-gateway",status="error"}) / count by (operation) (skywalking_span_status_total{service="api-gateway"})) * 100)', '{{operation}}%'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local agSpanLatencyTable =
  g.panel.table.new('Operations by Avg Latency (5m)')
  + c.pos(0, 22, 24, 8)
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

local agGuidancePanel =
  g.panel.text.new('Service Tracing & Correlation Guide')
  + c.pos(0, 31, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Analyze Slow Traces

    1. **Identify slow operation** in "Operations by Avg Latency" table
    2. **Go to SkyWalking UI**: [Traces for api-gateway](http://traces.pin/general/trace?service=api-gateway)
    3. **Filter by operation** and sort by duration (slowest first)
    4. **Click trace** — See span waterfall (shows where time is spent)
    5. **Note Trace ID** (e.g., `abc123...def456`)

    ### Correlate with Logs

    6. **Open [Observability — Logs](/d/observability-logs)**
    7. **Search**: `service:"api-gateway" AND trace_id:"abc123"`
    8. **View full request context** across all services in request flow

    ### Investigate Errors

    - **Error Rate spike?** Check "Trace Volume" chart for timing
    - **Operation errors?** See "Operation Error Rate" for which operations are failing
    - **Check logs** for stack traces: `service:"api-gateway" AND level:"error"`
  |||);

local agLogsPanel = c.serviceLogsPanel('API Gateway Logs', 'api-gateway', y=37);

local agTroubleGuide = c.serviceTroubleshootingGuide('api-gateway', [
  { symptom: 'High Latency', runbook: 'api-gateway/latency', check: 'Check p99/p95 in "Latency Percentiles"' },
  { symptom: 'Error Rate Spike', runbook: 'api-gateway/errors', check: 'Monitor "Error Rate" stat and check "Trace Volume"' },
  { symptom: 'Slow Operations', runbook: 'api-gateway/slow-operations', check: 'Check "Operations by Avg Latency" table' },
  { symptom: 'High Trace Volume', runbook: 'api-gateway/volume', check: 'Monitor "Trace Volume (Success/Error)"' },
], y=48);

local apiGatewayPanels = [
  g.panel.row.new('API Gateway — Distributed Tracing') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  agAlertPanel, agTracesPerMinStat, agErrorRateStat, agAvgLatencyStat, agP99LatencyStat,
  g.panel.row.new('Trace Distribution & Performance') + c.pos(0, 6, 24, 1),
  agTraceVolumeTs, agLatencyDistributionTs,
  agOperationCountTs, agOperationErrorsTs,
  g.panel.row.new('Operation Analysis') + c.pos(0, 23, 24, 1),
  agSpanLatencyTable,
  g.panel.row.new('Correlation Guide') + c.pos(0, 32, 24, 1),
  agGuidancePanel,
  g.panel.row.new('Logs') + c.pos(0, 36, 24, 1),
  agLogsPanel,
  g.panel.row.new('Troubleshooting') + c.pos(0, 47, 24, 1),
  agTroubleGuide,
];
// max(y+h): troubleGuide y=48 h=5 → 53
local apiGatewayHeight = 53;

// ── apm/pin-traces panels ──────────────────────────────────────────────────────

local ptAlertPanel = c.alertCountPanel('pin-traces', col=0);

local ptReqRate =
  g.panel.stat.new('Requests / min')
  + c.pos(6, 1, 6, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(rate(meter_service_resp_time_count[5m])) or vector(0)) * 60'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqpm')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local ptErrorRate =
  g.panel.stat.new('Error %')
  + c.pos(12, 1, 6, 4)
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

local ptP99 =
  g.panel.stat.new('P99 Latency')
  + c.pos(18, 1, 6, 4)
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

local ptServiceCount =
  g.panel.stat.new('Services')
  + c.pos(0, 6, 6, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(count(count by(service) (meter_service_resp_time_count))) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value');

local ptThroughputSparkline =
  g.panel.timeSeries.new('Throughput')
  + c.pos(6, 6, 18, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(sum(rate(meter_service_resp_time_count[5m])) or vector(0)) * 60',
      'total req/min'
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
  + g.panel.timeSeries.options.legend.withPlacement('right')
  + {
    fieldConfig+: {
      overrides: [
        {
          matcher: { id: 'byName', options: 'errors/min' },
          properties: [
            { id: 'color', value: { mode: 'fixed', fixedColor: 'red' } },
            { id: 'custom.fillOpacity', value: 15 },
          ],
        },
      ],
    },
  };

local ptServiceHealthTable =
  g.panel.table.new('Service Health — Latency & Errors')
  + c.pos(0, 12, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'avg by(service) ((rate(meter_service_resp_time_sum[5m]) or vector(0)) / (rate(meter_service_resp_time_count[5m]) or vector(0))) or vector(0)',
      '{{service}}'
    ) + { refId: 'latency' },
    c.vmQ(
      |||
        ((sum by(service) (rate(meter_service_resp_time_count{status="ERROR"}[5m])) or vector(0))
        / (sum by(service) (rate(meter_service_resp_time_count[5m])) or vector(0))) * 100 or vector(0)
      |||,
      '{{service}}'
    ) + { refId: 'errors' },
    c.vmQ(
      '(sum by(service) (rate(meter_service_resp_time_count[5m])) or vector(0)) * 60',
      '{{service}}'
    ) + { refId: 'throughput' },
  ])
  + g.panel.table.queryOptions.withTransformations([
    {
      id: 'joinByField',
      options: { byField: 'service', mode: 'outer' },
    },
    {
      id: 'organize',
      options: {
        renameByName: {
          'Value #latency': 'Avg Latency (ms)',
          'Value #errors': 'Error %',
          'Value #throughput': 'Req/min',
        },
        excludeByName: {
          Time: true,
          'Time 1': true,
          'Time 2': true,
          'Time 3': true,
        },
      },
    },
    {
      id: 'sortBy',
      options: { sort: [{ field: 'Avg Latency (ms)', desc: true }] },
    },
  ])
  + {
    fieldConfig+: {
      overrides: [
        {
          matcher: { id: 'byName', options: 'Avg Latency (ms)' },
          properties: [
            { id: 'unit', value: 'ms' },
            { id: 'decimals', value: 1 },
            { id: 'thresholds', value: { mode: 'absolute', steps: [
              { color: 'green', value: null },
              { color: 'yellow', value: 100 },
              { color: 'red', value: 500 },
            ] } },
            { id: 'custom.cellOptions', value: { type: 'color-background', mode: 'basic' } },
          ],
        },
        {
          matcher: { id: 'byName', options: 'Error %' },
          properties: [
            { id: 'unit', value: 'percent' },
            { id: 'decimals', value: 2 },
            { id: 'thresholds', value: { mode: 'absolute', steps: [
              { color: 'green', value: null },
              { color: 'yellow', value: 1 },
              { color: 'red', value: 5 },
            ] } },
            { id: 'custom.cellOptions', value: { type: 'color-background', mode: 'basic' } },
          ],
        },
        {
          matcher: { id: 'byName', options: 'Req/min' },
          properties: [
            { id: 'unit', value: 'reqpm' },
            { id: 'decimals', value: 0 },
          ],
        },
      ],
    },
  };

local ptThroughputByService =
  g.panel.timeSeries.new('Throughput by Service')
  + c.pos(0, 20, 24, 7)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(sum by(service) (rate(meter_service_resp_time_count[5m])) or vector(0)) * 60',
      '{{service}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqpm')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5);

local ptErrorByService =
  g.panel.timeSeries.new('Error Rate by Service')
  + c.pos(0, 27, 24, 7)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      |||
        topk(5,
          ((sum by(service) (rate(meter_service_resp_time_count{status="ERROR"}[1m])) or vector(0))
          / (sum by(service) (rate(meter_service_resp_time_count[5m])) or vector(0))) * 100 or vector(0)
        )
      |||,
      '{{service}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5);

local ptTroubleGuide = c.serviceTroubleshootingGuide('pin-traces', [
  { symptom: 'Service Latency High', runbook: 'apm/latency-investigation', check: 'Expand Service Details row and check Service Health table for bottleneck' },
  { symptom: 'Error Rate Spike', runbook: 'apm/error-root-cause', check: 'Monitor Error % stat and expand Error Logs row for stack traces' },
  { symptom: 'Throughput Drop', runbook: 'apm/capacity-check', check: 'Check throughput sparkline trend and correlate with service health' },
  { symptom: 'New Service Down', runbook: 'apm/service-onboard', check: 'Verify service count and check instrumentation in SkyWalking UI' },
], y=38);

local ptErrorLogsPanel =
  g.panel.logs.new('Service Error Logs')
  + c.logPos(42)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{level=~"(error|critical)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local pinTracesPanels = [
  g.panel.row.new('Pin Traces — APM Overview') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=0, x=18),
  ptAlertPanel, ptReqRate, ptErrorRate, ptP99, ptServiceCount,
  ptThroughputSparkline,
  (g.panel.row.new('Service Details') + c.pos(0, 13, 24, 1) + { collapsed: true, panels: [
    ptServiceHealthTable, ptThroughputByService, ptErrorByService,
  ] }),
  (g.panel.row.new('Troubleshooting') + c.pos(0, 14, 24, 1) + { collapsed: true, panels: [ptTroubleGuide] }),
  (g.panel.row.new('Error Logs') + c.pos(0, 15, 24, 1) + { collapsed: true, panels: [ptErrorLogsPanel] }),
];
// max(y+h): collapsed rows at y=15, h=1 → 16
local pinTracesHeight = 16;

// ── apm/postgres-query-tracing panels ─────────────────────────────────────────

local pgAlertPanel = c.alertCountPanel('postgres-server', col=0);

local pgQueryRateStat =
  g.panel.stat.new('Queries/sec')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(skywalking_span_total{service="PostgreSQL",operation=~".*query.*"}[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value');

local pgAvgQueryLatencyStat =
  g.panel.stat.new('Avg Query Time')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.50, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m]))) or vector(0))'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local pgP95QueryLatencyStat =
  g.panel.stat.new('P95 Query Time')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.95, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m]))) or vector(0))'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local pgSlowQueryCountStat =
  g.panel.stat.new('Slow Queries (>1s)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}{le="+Inf"} > 1000) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

local pgQueryLatencyTs =
  g.panel.timeSeries.new('Query Latency Distribution (p50/p95/p99)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.50, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m])))', 'p50'),
    c.vmQ('histogram_quantile(0.95, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m])))', 'p95'),
    c.vmQ('histogram_quantile(0.99, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m])))', 'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pgSlowQueryVolumeTs =
  g.panel.timeSeries.new('Slow Queries Over Time')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('count(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}{le="1000"}) or vector(0)', '>1s'),
    c.vmQ('count(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}{le="5000"}) or vector(0)', '>5s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pgTroubleGuide = c.serviceTroubleshootingGuide('postgres-server', [
  { symptom: 'Slow Queries', runbook: 'postgres/slow-queries', check: 'Check "Slow Queries Over Time" and "Slow Queries (>1s)" stat' },
  { symptom: 'Query Latency Spike', runbook: 'postgres/latency', check: 'Monitor "Query Latency Distribution" percentiles' },
  { symptom: 'High Query Volume', runbook: 'postgres/volume', check: 'Check "Queries/sec" and correlate with app traces' },
  { symptom: 'Connection Pool Exhausted', runbook: 'postgres/connections', check: 'Check PostgreSQL dashboard for active connections' },
], y=16);

local postgresQueryPanels = [
  g.panel.row.new('PostgreSQL — Query Tracing & Performance') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  pgAlertPanel, pgQueryRateStat, pgAvgQueryLatencyStat, pgP95QueryLatencyStat, pgSlowQueryCountStat,
  g.panel.row.new('Analysis') + c.pos(0, 6, 24, 1),
  pgQueryLatencyTs, pgSlowQueryVolumeTs,
  g.panel.row.new('Troubleshooting') + c.pos(0, 15, 24, 1),
  pgTroubleGuide,
];
// max(y+h): troubleGuide y=16 h=5 → 21
local postgresQueryHeight = 21;

// ── apm/traces-unified panels ──────────────────────────────────────────────────

local tuAlertPanel = c.alertCountPanel('skywalking-oap', col=0);

local tuOapUptimeStat =
  g.panel.stat.new('OAP Uptime')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('time() - process_start_time_seconds{job="skywalking-oap"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value');

local tuTraceIngestRate =
  g.panel.stat.new('Trace Ingest Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(trace_in_latency_count{job="skywalking-oap"}[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local tuReqRate =
  g.panel.stat.new('Service Req / min')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(rate(meter_service_resp_time_count[5m])) or vector(0)) * 60'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqpm')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local tuErrorRateStat =
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

local tuP99Stat =
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

local tuOapHeapStat =
  g.panel.stat.new('OAP Heap Used')
  + c.pos(16, 5, 8, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_memory_bytes_used{job="skywalking-oap",area="heap"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value');

local tuThroughputSparkline =
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

local tuTraceIngestLatencyTs =
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

local skyWalkingUrl = 'http://traces.pin';

local tuSwLinksPanel =
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
          SkyWalking UI
        </a>
        <a href="| + skyWalkingUrl + |/general/trace" target="_blank" style="
          padding:10px 18px;background:#f3f4f6;color:#374151;
          text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;">
          Traces
        </a>
        <a href="| + skyWalkingUrl + |/general/service" target="_blank" style="
          padding:10px 18px;background:#f3f4f6;color:#374151;
          text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;">
          Services
        </a>
        <a href="| + skyWalkingUrl + |/general/topology" target="_blank" style="
          padding:10px 18px;background:#f3f4f6;color:#374151;
          text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;">
          Topology
        </a>
        <a href="| + skyWalkingUrl + |/dashboard/list" target="_blank" style="
          padding:10px 18px;background:#f3f4f6;color:#374151;
          text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;">
          Dashboards
        </a>
      </div>
      <p style="color:#6b7280;font-size:12px;margin:0;text-align:center;">
        Service metrics (req/min, error%, latency) populate once services send traces via gRPC →
        <code style="background:#f3f4f6;padding:2px 6px;border-radius:3px;">192.168.0.4:11800</code>
      </p>
    </div>
  |||);

local tuCorrelationPanel =
  g.panel.text.new('Trace-to-Logs Correlation')
  + c.pos(0, 20, 24, 5)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Trace-to-Logs Correlation Workflow

    **1. Find a slow trace in SkyWalking:**
    Navigate to [traces.pin/general/trace](http://traces.pin/general/trace), filter by service/time, click trace — copy **Trace ID**.

    **2. Correlate in Grafana Logs:**
    Open [Observability — Logs](/d/observability-logs), search: `trace_id:"<paste-id>"`

    ---

    ### Instrument a New Service

    | Language | Method |
    |---|---|
    | Java | `-javaagent:skywalking-agent.jar` — OAP gRPC `192.168.0.4:11800` |
    | Python | `apache-skywalking` SDK |
    | System-level | SkyWalking Rover eBPF — no code changes |

    Always include `trace_id` as a JSON field in structured logs for full correlation.
  |||);

local tuErrorLogsPanel =
  g.panel.logs.new('Service Error Logs')
  + c.logPos(30)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",level=~"(error|critical)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local tracesUnifiedPanels = [
  g.panel.row.new('APM — Traces & Services') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  tuAlertPanel, tuOapUptimeStat, tuTraceIngestRate, tuReqRate,
  g.panel.row.new('Service Metrics') + c.pos(0, 6, 24, 1),
  tuErrorRateStat, tuP99Stat, tuOapHeapStat,
  tuThroughputSparkline, tuTraceIngestLatencyTs,
  g.panel.row.new('SkyWalking UI') + c.pos(0, 16, 24, 1),
  tuSwLinksPanel,
  g.panel.row.new('Trace Correlation') + c.pos(0, 21, 24, 1),
  tuCorrelationPanel,
  (g.panel.row.new('Error Logs') + c.pos(0, 27, 24, 1) + { collapsed: true, panels: [
    tuErrorLogsPanel,
  ] }),
];

// ── Dashboard ──────────────────────────────────────────────────────────────────

g.dashboard.new('APM')
+ g.dashboard.withUid('home-apm')
+ g.dashboard.withDescription('Application Performance Monitoring — API gateway, service traces, SkyWalking, Tempo.')
+ g.dashboard.withTags(['apm', 'traces', 'skywalking'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.swDsVar, c.vmAdhocVar, c.vlogsAdhocVar])
+ g.dashboard.withPanels(
    c.withYOffset(apiGatewayPanels, 0)
    + c.withYOffset(pinTracesPanels, apiGatewayHeight)
    + c.withYOffset(postgresQueryPanels, apiGatewayHeight + pinTracesHeight)
    + c.withYOffset(tracesUnifiedPanels, apiGatewayHeight + pinTracesHeight + postgresQueryHeight)
  )
