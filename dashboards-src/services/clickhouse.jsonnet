local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ClickHouse metrics come from the Prometheus endpoint (port 9363).
// Key metric families:
//   ClickHouseProfileEvents_*   — event counters (use rate() for per-second)
//   ClickHouseMetrics_*         — current gauges
//   ClickHouseAsyncMetrics_*    — background gauges (sampled at ~5s intervals)

// ── Stats (y=1) ─────────────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('clickhouse', col=0);

// 6-stat layout: alert(6) + up(4) + query(4) + mem(4) + errorRate(4) + parts(2) = 24
local upStat =
  g.panel.stat.new('ClickHouse Up')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('up{job="clickhouse"} or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('value_and_name');

local queryStat =
  g.panel.stat.new('Queries/sec')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(ClickHouseProfileEvents_Query[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local memStat =
  g.panel.stat.new('Memory Used')
  + c.pos(14, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_MemoryTracking or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value');

local errorRateStat =
  g.panel.stat.new('Failed Queries/sec')
  + c.pos(18, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(ClickHouseProfileEvents_FailedQuery[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 0.01 },
    { color: 'red', value: 0.1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local partsStat =
  g.panel.stat.new('Active Parts')
  + c.pos(22, 1, 2, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_PartsActive or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1000 },
    { color: 'red', value: 3000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local connStat =
  g.panel.stat.new('TCP Connections')
  + c.pos(22, 1, 2, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_TCPConnection or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

// ── Time series (y=5) ────────────────────────────────────────────────────────

local queryTs =
  g.panel.timeSeries.new('Query Rate (Read vs Write)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(ClickHouseProfileEvents_SelectQuery[5m])', 'selects/s'),
    c.vmQ('rate(ClickHouseProfileEvents_InsertQuery[5m])', 'inserts/s'),
    c.vmQ('rate(ClickHouseProfileEvents_FailedQuery[5m])', 'failed/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local insertTs =
  g.panel.timeSeries.new('Insert Throughput')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(ClickHouseProfileEvents_InsertedRows[5m])', 'rows/s'),
    c.vmQ('rate(ClickHouseProfileEvents_InsertedBytes[5m])', 'bytes/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local memTs =
  g.panel.timeSeries.new('Memory & Storage')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_MemoryTracking', 'memory tracked'),
    c.vmQ('ClickHouseAsyncMetrics_TotalBytesOfMergeTreeTables', 'mergetree disk'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local mergesTs =
  g.panel.timeSeries.new('Background Operations')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_Merge', 'merges'),
    c.vmQ('ClickHouseMetrics_BackgroundPoolTask', 'bg pool tasks'),
    c.vmQ('ClickHouseMetrics_PartsActive', 'active parts'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Logs ─────────────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('ClickHouse Logs', 'clickhouse-server');

local troubleGuide = c.serviceTroubleshootingGuide('clickhouse', [
  { symptom: 'Service Down', runbook: 'clickhouse/service-down', check: '"ClickHouse Up" = 0 — check service status and logs' },
  { symptom: 'High Memory', runbook: 'clickhouse/memory-usage', check: '"Memory Used" stat and "Memory & Storage" chart — check max_memory_usage setting' },
  { symptom: 'Query Failures', runbook: 'clickhouse/query-errors', check: '"Failed Queries/sec" spike — check logs for error details' },
  { symptom: 'Too Many Parts', runbook: 'clickhouse/parts-management', check: '"Active Parts" over 1000 = merge not keeping up, check INSERT rate' },
  { symptom: 'Slow Inserts', runbook: 'clickhouse/slow-inserts', check: '"Insert Throughput" drop — check "Background Operations" for merge backlog' },
], y=33);

g.dashboard.new('Services — ClickHouse')
+ g.dashboard.withUid('services-clickhouse')
+ g.dashboard.withDescription('ClickHouse queries/sec, inserts, memory, parts and errors.')
+ g.dashboard.withTags(['services', 'clickhouse', 'analytics', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, upStat, queryStat, memStat, errorRateStat, partsStat,
  g.panel.row.new('⚡ Query Activity') + c.pos(0, 4, 24, 1),
  queryTs, insertTs,
  g.panel.row.new('🏗️ Resources') + c.pos(0, 12, 24, 1),
  memTs, mergesTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 32, 24, 1),
  troubleGuide,
])
