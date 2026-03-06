// Dashboard: Services — PostgreSQL
// Question:  "Is PostgreSQL healthy? Connections, transactions, locks, cache hit rate."
//
// Data: pg_* from postgres_exporter (service="postgresql")
// Confirmed metrics: pg_up, pg_stat_activity_count, pg_stat_database_blks_hit,
//   pg_stat_database_blks_read, pg_stat_database_xact_commit, pg_stat_database_xact_rollback,
//   pg_locks_count, pg_database_size_bytes, pg_replication_lag_seconds

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local alertPanel = c.alertCountPanel('postgresql', col=0);

// ── Row 0: Key Stats ──────────────────────────────────────────────────────────

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
  + g.panel.stat.options.withGraphMode('area');

local cacheHitStat =
  g.panel.stat.new('Cache Hit Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(pg_stat_database_blks_hit) / (sum(pg_stat_database_blks_hit) + sum(pg_stat_database_blks_read)) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + c.freeThresholds;

// ── Row 1: Activity ───────────────────────────────────────────────────────────

local connTs =
  g.panel.timeSeries.new('Connections by State')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_stat_activity_count or vector(0)', '{{state}}'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local txnTs =
  g.panel.timeSeries.new('Transactions/sec')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(pg_stat_database_xact_commit[5m]) or vector(0)', 'commit'),
    c.vmQ('rate(pg_stat_database_xact_rollback[5m]) or vector(0)', 'rollback'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Locks & Size ───────────────────────────────────────────────────────

local locksTs =
  g.panel.timeSeries.new('Locks by Mode')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_locks_count or vector(0)', '{{mode}}'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sizeTs =
  g.panel.timeSeries.new('Database Size')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_database_size_bytes or vector(0)', '{{datname}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: Logs ───────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('PostgreSQL Logs', 'postgres', y=22);

// ── Row 4: Troubleshooting ────────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('postgresql', [
  { symptom: 'Connection Pool Exhausted', runbook: 'postgresql/conn-pool', check: 'Check "Connections by State" — look for idle-in-transaction or waiting states' },
  { symptom: 'High Rollback Rate', runbook: 'postgresql/rollbacks', check: 'Check "Transactions/sec" — rollback spike = app errors or deadlocks' },
  { symptom: 'Cache Hit Rate Low', runbook: 'postgresql/cache', check: '"Cache Hit Rate" below 95% = disk I/O pressure, review shared_buffers' },
  { symptom: 'Lock Contention', runbook: 'postgresql/locks', check: '"Locks by Mode" — shareLock + ExclusiveLock spikes = contention' },
  { symptom: 'DB Size Growing Fast', runbook: 'postgresql/bloat', check: '"Database Size" chart — check VACUUM schedule' },
], y=34);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Services — PostgreSQL')
+ g.dashboard.withUid('services-postgresql')
+ g.dashboard.withDescription('PostgreSQL connections, transactions, locks, cache hit rate, and alerts.')
+ g.dashboard.withTags(['services', 'postgresql', 'database', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, upStat, connStat, cacheHitStat,

  g.panel.row.new('⚡ Activity') + c.pos(0, 4, 24, 1),
  connTs, txnTs,

  g.panel.row.new('🔒 Locks & Size') + c.pos(0, 12, 24, 1),
  locksTs, sizeTs,

  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 33, 24, 1),
  troubleGuide,
])
