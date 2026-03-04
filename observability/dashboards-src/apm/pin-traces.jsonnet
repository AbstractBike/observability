// Dashboard: Pin Traces — APM Overview
//
// Datadog APM-style overview using SkyWalking OAP PromQL endpoint.
// Rows:
//   0  Service Health — Req/min · Error % · P99 Latency · Service count
//   1  Top Services — by avg latency (bar gauge) | Error rate by service (ts)
//   2  Throughput — all services over time
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Row 1: Stats ─────────────────────────────────────────────────────────────

local reqRate =
  g.panel.stat.new('Requests / min')
  + c.pos(0, 1, 6, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('sum(rate(meter_service_resp_time_count[1m])) * 60'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqpm')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local errorRate =
  g.panel.stat.new('Error %')
  + c.pos(6, 1, 6, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ(|||
      sum(rate(meter_service_resp_time_count{status="ERROR"}[1m]))
      / sum(rate(meter_service_resp_time_count[1m])) * 100
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
  + c.pos(12, 1, 6, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('histogram_quantile(0.99, sum by(le) (rate(meter_service_resp_time_bucket[5m])))'),
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
  + c.pos(18, 1, 6, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('count(count by(service) (meter_service_resp_time_count))'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('background');

// ── Row 2: Top Services ──────────────────────────────────────────────────────

local topServicesByLatency =
  g.panel.barGauge.new('Top Services — Avg Latency')
  + c.pos(0, 6, 12, 8)
  + g.panel.barGauge.queryOptions.withTargets([
    c.swQ(
      'topk(10, avg by(service) (rate(meter_service_resp_time_sum[5m]) / rate(meter_service_resp_time_count[5m])))',
      '{{service}}'
    ),
  ])
  + g.panel.barGauge.standardOptions.withUnit('ms')
  + g.panel.barGauge.options.withOrientation('horizontal')
  + g.panel.barGauge.options.withDisplayMode('gradient');

local errorByService =
  g.panel.timeSeries.new('Error Rate by Service')
  + c.pos(12, 6, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ(
      |||
        topk(5,
          sum by(service) (rate(meter_service_resp_time_count{status="ERROR"}[1m]))
          / sum by(service) (rate(meter_service_resp_time_count[1m])) * 100
        )
      |||,
      '{{service}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5);

// ── Row 3: Throughput ────────────────────────────────────────────────────────

local throughputTs =
  g.panel.timeSeries.new('Throughput — Requests / min')
  + c.pos(0, 15, 24, 7)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ(
      'sum by(service) (rate(meter_service_resp_time_count[1m]) * 60)',
      '{{service}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqpm')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5);

// ── Row separators ───────────────────────────────────────────────────────────

local statsRow =
  g.panel.row.new('Service Health')
  + c.pos(0, 0, 24, 1);

local topRow =
  g.panel.row.new('Top Services')
  + c.pos(0, 5, 24, 1);

local throughputRow =
  g.panel.row.new('Throughput')
  + c.pos(0, 14, 24, 1);

// ── Dashboard assembly ───────────────────────────────────────────────────────

g.dashboard.new('Pin Traces — APM Overview')
+ g.dashboard.withUid('pin-traces')
+ g.dashboard.withDescription('Pin Soluciones Informáticas — Distributed Tracing & APM')
+ g.dashboard.withTags(['apm', 'pin-traces', 'skywalking'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withEditable(false)
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([c.swDsVar])
+ g.dashboard.withPanels([
    statsRow, reqRate, errorRate, p99, serviceCount,
    topRow, topServicesByLatency, errorByService,
    throughputRow, throughputTs,
  ])
