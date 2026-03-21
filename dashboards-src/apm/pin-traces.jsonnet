// Dashboard: Pin Traces — APM Overview
//
// Datadog APM-style overview using SkyWalking OAP PromQL endpoint.
// Rows:
//   0  Service Health — Req/min · Error % · P99 Latency · Service count (always visible)
//   1  Top Services — combined latency + error table (collapsed for debugging)
//   2  Throughput — all services over time (collapsed for debugging)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Row 0: Overview stats (the "is everything OK?" view) ─────────────────────

local alertPanel = c.alertCountPanel('pin-traces', col=0);

local reqRate =
  g.panel.stat.new('Requests / min')
  + c.pos(6, 1, 6, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(rate(meter_service_resp_time_count[5m])) or vector(0)) * 60'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqpm')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local errorRate =
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

local p99 =
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

local serviceCount =
  g.panel.stat.new('Services')
  + c.pos(0, 6, 6, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(count(count by(service) (meter_service_resp_time_count))) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value');

// ── Throughput sparkline (always visible — quick health check) ────────────────

local throughputSparkline =
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

// ── Debugging section (collapsed by default) ─────────────────────────────────

// Consolidated table: service latency + error rate in one view
local serviceHealthTable =
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

// Per-service throughput breakdown
local throughputByService =
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

// Error rate by service over time
local errorByService =
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

// ── Troubleshooting & Logs (collapsed) ──────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('pin-traces', [
  { symptom: 'Service Latency High', runbook: 'apm/latency-investigation', check: 'Expand Service Details row and check Service Health table for bottleneck' },
  { symptom: 'Error Rate Spike', runbook: 'apm/error-root-cause', check: 'Monitor Error % stat and expand Error Logs row for stack traces' },
  { symptom: 'Throughput Drop', runbook: 'apm/capacity-check', check: 'Check throughput sparkline trend and correlate with service health' },
  { symptom: 'New Service Down', runbook: 'apm/service-onboard', check: 'Verify service count and check instrumentation in SkyWalking UI' },
], y=38);

local errorLogsPanel =
  g.panel.logs.new('Service Error Logs')
  + c.logPos(42)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{level=~"(error|critical)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard assembly ───────────────────────────────────────────────────────

g.dashboard.new('Pin Traces — APM Overview')
+ g.dashboard.withUid('pin-traces')
+ g.dashboard.withDescription('Pin Soluciones Informaticas — Distributed Tracing & APM')
+ g.dashboard.withTags(['apm', 'pin-traces', 'skywalking', 'critical'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withEditable(false)
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.swDsVar])
+ g.dashboard.withPanels([
    // Always-visible: overview stats + throughput sparkline
    g.panel.row.new('Service Health') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

    c.externalLinksPanel(y=0, x=18),
    alertPanel, reqRate, errorRate, p99, serviceCount,
    throughputSparkline,

    // Collapsed: detailed debugging
    (g.panel.row.new('Service Details') + c.pos(0, 13, 24, 1) + { collapsed: true, panels: [
      serviceHealthTable, throughputByService, errorByService,
    ] }),

    // Collapsed: troubleshooting
    (g.panel.row.new('Troubleshooting') + c.pos(0, 14, 24, 1) + { collapsed: true, panels: [troubleGuide] }),

    // Collapsed: error logs
    (g.panel.row.new('Error Logs') + c.pos(0, 15, 24, 1) + { collapsed: true, panels: [errorLogsPanel] }),
  ])
