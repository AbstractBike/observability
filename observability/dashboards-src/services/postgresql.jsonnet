local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local upStat =
  g.panel.stat.new('PostgreSQL Up')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('pg_up')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local connStat =
  g.panel.stat.new('Active Connections')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('sum(pg_stat_activity_count)')])
  + c.percentThresholds;

local cacheHitStat =
  g.panel.stat.new('Cache Hit Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(pg_stat_database_blks_hit) / (sum(pg_stat_database_blks_hit) + sum(pg_stat_database_blks_read)) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + c.freeThresholds;

local txnStat =
  g.panel.stat.new('Transactions/sec')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(pg_stat_database_xact_commit[5m]) + rate(pg_stat_database_xact_rollback[5m]))'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps');

local connTs =
  g.panel.timeSeries.new('Connections by State')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_stat_activity_count', '{{state}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local txnTs =
  g.panel.timeSeries.new('Transactions/sec')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(pg_stat_database_xact_commit[5m])', 'commit'),
    c.vmQ('rate(pg_stat_database_xact_rollback[5m])', 'rollback'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local locksTs =
  g.panel.timeSeries.new('Locks')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_locks_count', '{{mode}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sizeTs =
  g.panel.timeSeries.new('Database Size')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_database_size_bytes', '{{datname}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel =
  g.panel.logs.new('PostgreSQL Logs')
  + c.logPos(21)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{service="postgresql.service"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true);

g.dashboard.new('Services — PostgreSQL')
+ g.dashboard.withUid('services-postgresql')
+ g.dashboard.withDescription('PostgreSQL connections, transactions, locks, and cache hit rate.')
+ g.dashboard.withTags(['services', 'postgresql'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  upStat, connStat, cacheHitStat, txnStat,
  g.panel.row.new('Activity') + c.pos(0, 4, 24, 1),
  connTs, txnTs,
  g.panel.row.new('Locks & Size') + c.pos(0, 12, 24, 1),
  locksTs, sizeTs,
  g.panel.row.new('Logs') + c.pos(0, 20, 24, 1),
  logsPanel,
])
