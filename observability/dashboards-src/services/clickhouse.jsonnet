local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local queryStat =
  g.panel.stat.new('Queries/sec')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(ClickHouseProfileEvents_Query[5m])'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps');

local memStat =
  g.panel.stat.new('Memory Used')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_MemoryTracking'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes');

local mergesStat =
  g.panel.stat.new('Active Merges')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_Merge'),
  ]);

local connStat =
  g.panel.stat.new('TCP Connections')
  + c.statPos(3)
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

g.dashboard.new('Services — ClickHouse')
+ g.dashboard.withUid('services-clickhouse')
+ g.dashboard.withDescription('ClickHouse queries/sec, memory, merges, disk.')
+ g.dashboard.withTags(['services', 'clickhouse'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  queryStat, memStat, mergesStat, connStat,
  g.panel.row.new('Activity') + c.pos(0, 4, 24, 1),
  queryTs, memTs,
])
