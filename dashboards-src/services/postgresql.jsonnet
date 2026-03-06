local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Alert count panel (colored by alert state)
local alertCountPanel =
  g.panel.stat.new('🚨 Active Alerts')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(ALERTS{service="postgresql",alertstate="firing"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 3 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

// Breadcrumbs navigation (transparent)
local breadcrumbs =
  g.panel.text.new('Navigation')
  + c.pos(7, 1, 17, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <a href="/d/service-catalog">📚 Service Catalog</a> →
    <a href="/d/services-postgresql">🐘 PostgreSQL</a>
    | <a href="/d/postgres-query-tracing">🔍 Query Tracing</a>
    | <a href="/d/postgres-replication">📡 Replication</a>
  |||);

local upStat =
  g.panel.stat.new('PostgreSQL Up')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('pg_up or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local connStat =
  g.panel.stat.new('Active Connections')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('sum(pg_stat_activity_count) or vector(0)')])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local cacheHitStat =
  g.panel.stat.new('Cache Hit Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(pg_stat_database_blks_hit) / (sum(pg_stat_database_blks_hit) + sum(pg_stat_database_blks_read)) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + c.freeThresholds;

local txnStat =
  g.panel.stat.new('Transactions/sec')
  + c.statPos(4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(rate(pg_stat_database_xact_commit[5m]) + rate(pg_stat_database_xact_rollback[5m]))) or vector(0)'),
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
  g.panel.timeSeries.new('Transactions/sec — History')
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

local logsPanel = c.serviceLogsPanel('PostgreSQL Logs', 'postgres');

// Troubleshooting guide with runbook links
local troubleshootingPanel =
  g.panel.text.new('🔧 Troubleshooting Guide')
  + c.pos(0, 24, 24, 5)
  + g.panel.text.panelOptions.withTransparent(false)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Symptom | Runbook | Quick Check |
    |---------|---------|------------|
    | **High CPU** | [CPU Troubleshooting](https://wiki.pin/runbooks/postgresql/high-cpu) | Check `cpu_usage` graph above |
    | **Connection Pool Exhausted** | [Connection Pool](https://wiki.pin/runbooks/postgresql/conn-pool) | Look at "Connections by State" chart |
    | **Slow Queries** | [Query Performance](https://wiki.pin/runbooks/postgresql/slow-queries) | Check [Query Tracing Dashboard](/d/postgres-query-tracing) |
    | **Replication Lag** | [Replication Issues](https://wiki.pin/runbooks/postgresql/replication) | View [Replication Dashboard](/d/postgres-replication) |
    | **High Memory** | [Memory Optimization](https://wiki.pin/runbooks/postgresql/memory) | Check database size in "Database Size" chart |
    
    **On-Call Workflow:**
    1. Click alert notification → opens this dashboard
    2. Check "Firing Alerts" panel (top-left)
    3. Click alert → see runbook link above
    4. Follow runbook steps (with dashboard screenshots)
    5. Monitor metrics return to normal
  |||);

g.dashboard.new('Services — PostgreSQL')
+ g.dashboard.withUid('services-postgresql')
+ g.dashboard.withDescription('PostgreSQL connections, transactions, locks, cache hit rate, and alerts.')
+ g.dashboard.withTags(['services', 'postgresql', 'database', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  breadcrumbs,
  alertCountPanel, upStat, connStat, cacheHitStat, txnStat,
  g.panel.row.new('⚡ Activity') + c.pos(0, 5, 24, 1),
  connTs, txnTs,
  g.panel.row.new('🔒 Locks & Size') + c.pos(0, 13, 24, 1),
  locksTs, sizeTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 29, 24, 1),
  troubleshootingPanel,
])
