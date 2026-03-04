// Dashboard: Serena — All Backends
//
// Shows RED metrics for the Serena MCP server (via SkyWalking PromQL),
// per-tool breakdown, backend services health grid, and recent error logs.
//
// Rows:
//   0  Serena MCP — 4 stats: CPM, Response Time, SLA, Error Rate
//   1  Serena MCP — time series: CPM trend, Latency percentiles, Error Rate
//   2  Per-Tool Breakdown — CPM per endpoint, Latency per endpoint
//   3  Backend Services — up{job=...} health grid (11 services)
//   4  Error Logs — recent ERROR/WARN from VictoriaLogs

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local serenaService = 'serena-standalone-rs';

// ── Row 0: Serena MCP stats ───────────────────────────────────────────────

local cpmStat =
  g.panel.stat.new('Calls/min')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_cpm{service="' + serenaService + '"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short');

local respTimeStat =
  g.panel.stat.new('Avg Response Time')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_resp_time{service="' + serenaService + '"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ]);

local slaStat =
  g.panel.stat.new('Success Rate (SLA)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('((service_sla{service="' + serenaService + '"} / 100)) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 99 },
  ])
  + g.panel.stat.options.withColorMode('background');

local errorRateStat =
  g.panel.stat.new('Error Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_error_rate{service="' + serenaService + '"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Row 1: Serena MCP time series ────────────────────────────────────────

local cpmTs =
  g.panel.timeSeries.new('Calls/min')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_cpm{service="' + serenaService + '"}) or vector(0)', 'cpm'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('single');

local latencyTs =
  g.panel.timeSeries.new('Response Time Percentiles (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_percentile{service="' + serenaService + '",le="50"}) or vector(0)',  'p50'),
    c.swQ('(service_percentile{service="' + serenaService + '",le="75"}) or vector(0)',  'p75'),
    c.swQ('(service_percentile{service="' + serenaService + '",le="90"}) or vector(0)',  'p90'),
    c.swQ('(service_percentile{service="' + serenaService + '",le="99"}) or vector(0)',  'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local errorRateTs =
  g.panel.timeSeries.new('Error Rate (%)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_error_rate{service="' + serenaService + '"}) or vector(0)', 'error %'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.options.tooltip.withMode('single');

// ── Row 2: Per-Tool Breakdown ─────────────────────────────────────────────

local toolCpmTs =
  g.panel.timeSeries.new('Calls/min per Tool')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('topk(10, (endpoint_cpm{service="' + serenaService + '"}) or vector(0))', '{{endpoint}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local toolLatencyTs =
  g.panel.timeSeries.new('Avg Latency per Tool (ms)')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('topk(10, (endpoint_resp_time{service="' + serenaService + '"}) or vector(0))', '{{endpoint}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: Backend Services health grid ─────────────────────────────────
// One stat panel per scrape job using the standard up{job=...} metric.
// 6 wide × 3 tall per panel, 4 per row.

local upPanel(title, job, col, row) =
  g.panel.stat.new(title)
  + c.pos(col * 6, 29 + row * 4, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('up{job="' + job + '"}'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withReduceOptions(
    g.panel.stat.options.reduceOptions.withCalcs(['lastNotNull'])
  );

// ── Row 4: Error logs ─────────────────────────────────────────────────────

local errorLogs =
  g.panel.logs.new('Recent Errors & Warnings')
  + c.logPos(41)
  + g.panel.logs.queryOptions.withTargets([
    // Query VictoriaLogs for ERROR/WARN level logs or Exception mentions.
    c.vlogsQ('{level=~"(error|warning)"} or _msg:~"(Exception|Error)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard assembly ────────────────────────────────────────────────────

g.dashboard.new('Overview — Serena & Backends')
+ g.dashboard.withUid('overview-serena-backends')
+ g.dashboard.withDescription('Serena MCP server RED metrics (SkyWalking) and backend services health grid.')
+ g.dashboard.withTags(['overview', 'serena', 'backends', 'mcp'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.swDsVar])
+ g.dashboard.withPanels([

  // Row 0: Serena RED stats
  g.panel.row.new('Serena MCP — RED Metrics') + c.pos(0, 0, 24, 1),
  cpmStat, respTimeStat, slaStat, errorRateStat,

  // Row 1: Serena time series
  g.panel.row.new('Serena MCP — Trends') + c.pos(0, 4, 24, 1),
  cpmTs, latencyTs,
  errorRateTs, toolCpmTs,

  // Row 2: Per-tool breakdown
  g.panel.row.new('Serena — Per-Tool Breakdown') + c.pos(0, 21, 24, 1),
  toolLatencyTs,

  // Row 3: Backend health grid
  g.panel.row.new('Backend Services — Health') + c.pos(0, 28, 24, 1),
  upPanel('Serena MCP',         'serena-mcp',           0, 0),
  upPanel('Arbitraje',          'arbitraje',            1, 0),
  upPanel('PostgreSQL',         'postgres-exporter',    2, 0),
  upPanel('Redis',              'redis-exporter',       3, 0),
  upPanel('Elasticsearch',      'elasticsearch-exporter', 0, 1),
  upPanel('ClickHouse',         'clickhouse',           1, 1),
  upPanel('Redpanda',           'redpanda',             2, 1),
  upPanel('Temporal',           'temporal',             3, 1),
  upPanel('VictoriaMetrics',    'victoriametrics-self', 0, 2),
  upPanel('Alertmanager',       'alertmanager',         1, 2),
  upPanel('VMAlert',            'vmalert',              2, 2),

  // Row 4: Error logs
  g.panel.row.new('Error Logs') + c.pos(0, 40, 24, 1),
  errorLogs,
])
