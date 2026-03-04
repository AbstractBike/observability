local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// 5-stat layout: up(4w) + queries(5w) + memory(5w) + merges(5w) + connections(5w) = 24
local upStat =
  g.panel.stat.new('ClickHouse Up')
  + c.pos(0, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('up{job="clickhouse"}')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('value_and_name');

local queryStat =
  g.panel.stat.new('Queries/sec')
  + c.pos(4, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(ClickHouseProfileEvents_Query[5m])'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps');

local memStat =
  g.panel.stat.new('Memory Used')
  + c.pos(9, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_MemoryTracking'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes');

local mergesStat =
  g.panel.stat.new('Active Merges')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_Merge'),
  ]);

local connStat =
  g.panel.stat.new('TCP Connections')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_TCPConnection'),
  ]);

local queryTs =
  g.panel.timeSeries.new('Query Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(ClickHouseProfileEvents_Query[5m])', 'queries/s'),
    c.vmQ('rate(ClickHouseProfileEvents_SelectQuery[5m])', 'selects/s'),
    c.vmQ('rate(ClickHouseProfileEvents_InsertQuery[5m])', 'inserts/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local memTs =
  g.panel.timeSeries.new('Memory & Disk')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_MemoryTracking', 'memory'),
    c.vmQ('ClickHouseAsyncMetrics_TotalBytesOfMergeTreeTables', 'mergetree bytes'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel = c.serviceLogsPanel('ClickHouse Logs', 'clickhouse-server.service');

g.dashboard.new('Services — ClickHouse')
+ g.dashboard.withUid('services-clickhouse')
+ g.dashboard.withDescription('ClickHouse queries/sec, memory, merges, disk.')
+ g.dashboard.withTags(['services', 'clickhouse'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  upStat, queryStat, memStat, mergesStat, connStat,
  g.panel.row.new('Activity') + c.pos(0, 4, 24, 1),
  queryTs, memTs,
  g.panel.row.new('Logs') + c.pos(0, 12, 24, 1),
  logsPanel,
])
