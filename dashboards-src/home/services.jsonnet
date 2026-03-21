local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── temporal panels ────────────────────────────────────────────────────────

local tmp_alertPanel = c.alertCountPanel('temporal', col=0);

local tmp_upStat =
  g.panel.stat.new('Temporal Up')
  + c.pos(6, 1, 3, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('up{job="temporal"} or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('value_and_name');

local tmp_workflowStartStat =
  g.panel.stat.new('Workflow Starts/sec')
  + c.pos(9, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(service_requests{operation="StartWorkflowExecution",service_name="frontend",job="temporal"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local tmp_taskQueueStat =
  g.panel.stat.new('Task Queue Backlog')
  + c.pos(14, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(approximate_backlog_count{job="temporal"}) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local tmp_schedLatStat =
  g.panel.stat.new('Schedule-to-Start p99')
  + c.pos(18, 1, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(histogram_quantile(0.99, rate(poll_latency_bucket{job="temporal"}[5m]))) * 1000 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local tmp_errorStat =
  g.panel.stat.new('Service Errors/sec')
  + c.pos(21, 1, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(service_error_with_type{job="temporal"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 0.1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local tmp_workflowTs =
  g.panel.timeSeries.new('Workflow Operations/sec')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(service_requests{operation="StartWorkflowExecution",service_name="frontend",job="temporal"}[5m]) or vector(0)', 'starts'),
    c.vmQ('rate(service_requests{operation="RespondWorkflowTaskCompleted",service_name="history",job="temporal"}[5m]) or vector(0)', 'completions'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tmp_latTs =
  g.panel.timeSeries.new('Request Latency p99 (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.99, sum by (le, operation) (rate(service_latency_bucket{job="temporal"}[5m]))) * 1000 or vector(0)',
      '{{operation}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tmp_logsPanel =
  g.panel.logs.new('Temporal Logs')
  + c.logPos(15)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"podman-temporal|podman-temporal-ui"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local tmp_troubleGuide = c.serviceTroubleshootingGuide('temporal', [
  { symptom: 'Service Down', runbook: 'temporal/service-down', check: '"Temporal Up" = 0 — check service status and logs' },
  { symptom: 'High Task Queue Backlog', runbook: 'temporal/queue-backlog', check: '"Task Queue Backlog" climbing = workers not keeping up with scheduled tasks' },
  { symptom: 'High Latency', runbook: 'temporal/latency', check: '"Request Latency p99" — slow operations or resource contention' },
  { symptom: 'Service Errors', runbook: 'temporal/errors', check: '"Service Errors/sec" — check logs for error type breakdown' },
  { symptom: 'Workflow Stuck', runbook: 'temporal/workflow-stuck', check: 'Backlog high + completions low = worker crashed or activity timeout' },
], y=26);

local temporalPanels = [
  g.panel.row.new('⏱️ Temporal') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  tmp_alertPanel, tmp_upStat, tmp_workflowStartStat, tmp_taskQueueStat, tmp_schedLatStat, tmp_errorStat,
  g.panel.row.new('⚡ Workflows & Latency') + c.pos(0, 6, 24, 1),
  tmp_workflowTs, tmp_latTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 14, 24, 1),
  tmp_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 25, 24, 1),
  tmp_troubleGuide,
];
local temporalHeight = 31;

// ── redis panels ───────────────────────────────────────────────────────────

local red_alertPanel = c.alertCountPanel('redis', col=0);

local red_upStat =
  g.panel.stat.new('Redis Up')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('redis_up or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local red_hitRateStat =
  g.panel.stat.new('Keyspace Hit Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(rate(redis_keyspace_hits_total[5m]) or vector(0)) / clamp_min((rate(redis_keyspace_hits_total[5m]) or vector(0)) + (rate(redis_keyspace_misses_total[5m]) or vector(0)), 0.001) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + c.freeThresholds;

local red_opsTs =
  g.panel.timeSeries.new('Operations/sec by Command')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_commands_total[5m]) or vector(0)', '{{cmd}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local red_memTs =
  g.panel.timeSeries.new('Memory Usage')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('redis_memory_used_bytes or vector(0)', 'used'),
    c.vmQ('redis_memory_max_bytes or vector(0)', 'max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local red_evictTs =
  g.panel.timeSeries.new('Evictions/sec')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_evicted_keys_total[5m]) or vector(0)', 'evictions'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

local red_hitsTs =
  g.panel.timeSeries.new('Keyspace Hits vs Misses')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_keyspace_hits_total[5m]) or vector(0)', 'hits'),
    c.vmQ('rate(redis_keyspace_misses_total[5m]) or vector(0)', 'misses'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local red_troubleGuide = c.serviceTroubleshootingGuide('redis', [
  { symptom: 'High Memory Usage', runbook: 'redis/memory-pressure', check: '"Memory Used" near max = risk of evictions or OOM' },
  { symptom: 'High Eviction Rate', runbook: 'redis/eviction', check: '"Evictions/sec" — evictions mean memory is full, keys being dropped' },
  { symptom: 'Low Hit Rate', runbook: 'redis/cache-opt', check: '"Keyspace Hit Rate" below 90% = cache miss problem or cold cache' },
  { symptom: 'Spike in Operations', runbook: 'redis/performance', check: '"Operations/sec by Command" — look for unexpected command patterns' },
  { symptom: 'Redis Down', runbook: 'redis/down', check: '"Redis Up" = 0 — check service status and logs' },
], y=24);

local redisPanels = [
  g.panel.row.new('🔴 Redis') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  red_alertPanel, red_upStat, red_hitRateStat,
  g.panel.row.new('⚡ Operations') + c.pos(0, 6, 24, 1),
  red_opsTs, red_memTs,
  g.panel.row.new('💾 Evictions & Keyspace') + c.pos(0, 14, 24, 1),
  red_evictTs, red_hitsTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 23, 24, 1),
  red_troubleGuide,
];
local redisHeight = 29;

// ── postgresql panels ──────────────────────────────────────────────────────

local pg_alertPanel = c.alertCountPanel('postgresql', col=0);

local pg_upStat =
  g.panel.stat.new('PostgreSQL Up')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('pg_up or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local pg_connStat =
  g.panel.stat.new('Active Connections')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('sum(pg_stat_activity_count) or vector(0)')])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local pg_cacheHitStat =
  g.panel.stat.new('Cache Hit Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(pg_stat_database_blks_hit) / (sum(pg_stat_database_blks_hit) + sum(pg_stat_database_blks_read)) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + c.freeThresholds;

local pg_connTs =
  g.panel.timeSeries.new('Connections by State')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_stat_activity_count or vector(0)', '{{state}}'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pg_txnTs =
  g.panel.timeSeries.new('Transactions/sec')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(pg_stat_database_xact_commit[5m]) or vector(0)', 'commit'),
    c.vmQ('rate(pg_stat_database_xact_rollback[5m]) or vector(0)', 'rollback'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pg_locksTs =
  g.panel.timeSeries.new('Locks by Mode')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_locks_count or vector(0)', '{{mode}}'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pg_sizeTs =
  g.panel.timeSeries.new('Database Size')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pg_database_size_bytes or vector(0)', '{{datname}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pg_logsPanel =
  g.panel.logs.new('PostgreSQL Logs')
  + c.logPos(24)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"prometheus-postgres-exporter|postgres_exporter"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local pg_troubleGuide = c.serviceTroubleshootingGuide('postgresql', [
  { symptom: 'Connection Pool Exhausted', runbook: 'postgresql/conn-pool', check: 'Check "Connections by State" — look for idle-in-transaction or waiting states' },
  { symptom: 'High Rollback Rate', runbook: 'postgresql/rollbacks', check: 'Check "Transactions/sec" — rollback spike = app errors or deadlocks' },
  { symptom: 'Cache Hit Rate Low', runbook: 'postgresql/cache', check: '"Cache Hit Rate" below 95% = disk I/O pressure, review shared_buffers' },
  { symptom: 'Lock Contention', runbook: 'postgresql/locks', check: '"Locks by Mode" — shareLock + ExclusiveLock spikes = contention' },
  { symptom: 'DB Size Growing Fast', runbook: 'postgresql/bloat', check: '"Database Size" chart — check VACUUM schedule' },
], y=36);

local pgPanels = [
  g.panel.row.new('🐘 PostgreSQL') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  pg_alertPanel, pg_upStat, pg_connStat, pg_cacheHitStat,
  g.panel.row.new('⚡ Activity') + c.pos(0, 6, 24, 1),
  pg_connTs, pg_txnTs,
  g.panel.row.new('🔒 Locks & Size') + c.pos(0, 14, 24, 1),
  pg_locksTs, pg_sizeTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  pg_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 35, 24, 1),
  pg_troubleGuide,
];
local pgHeight = 41;

// ── clickhouse panels ──────────────────────────────────────────────────────

local ch_alertPanel = c.alertCountPanel('clickhouse', col=0);

local ch_upStat =
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

local ch_memStat =
  g.panel.stat.new('Memory Used')
  + c.pos(14, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_MemoryTracking or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value');

local ch_errorRateStat =
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

local ch_partsStat =
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

local ch_queryTs =
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

local ch_insertTs =
  g.panel.timeSeries.new('Insert Throughput')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(ClickHouseProfileEvents_InsertedRows[5m])', 'rows/s'),
    c.vmQ('rate(ClickHouseProfileEvents_InsertedBytes[5m])', 'bytes/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ch_memTs =
  g.panel.timeSeries.new('Memory & Storage')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_MemoryTracking', 'memory tracked'),
    c.vmQ('ClickHouseAsyncMetrics_TotalBytesOfMergeTreeTables', 'mergetree disk'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ch_mergesTs =
  g.panel.timeSeries.new('Background Operations')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('ClickHouseMetrics_Merge', 'merges'),
    c.vmQ('ClickHouseMetrics_BackgroundPoolTask', 'bg pool tasks'),
    c.vmQ('ClickHouseMetrics_PartsActive', 'active parts'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ch_troubleGuide = c.serviceTroubleshootingGuide('clickhouse', [
  { symptom: 'Service Down', runbook: 'clickhouse/service-down', check: '"ClickHouse Up" = 0 — check service status and logs' },
  { symptom: 'High Memory', runbook: 'clickhouse/memory-usage', check: '"Memory Used" stat and "Memory & Storage" chart — check max_memory_usage setting' },
  { symptom: 'Query Failures', runbook: 'clickhouse/query-errors', check: '"Failed Queries/sec" spike — check logs for error details' },
  { symptom: 'Too Many Parts', runbook: 'clickhouse/parts-management', check: '"Active Parts" over 1000 = merge not keeping up, check INSERT rate' },
  { symptom: 'Slow Inserts', runbook: 'clickhouse/slow-inserts', check: '"Insert Throughput" drop — check "Background Operations" for merge backlog' },
], y=24);

local chPanels = [
  g.panel.row.new('🏠 ClickHouse') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  ch_alertPanel, ch_upStat, ch_memStat, ch_errorRateStat, ch_partsStat,
  g.panel.row.new('⚡ Query Activity') + c.pos(0, 6, 24, 1),
  ch_queryTs, ch_insertTs,
  g.panel.row.new('🏗️ Resources') + c.pos(0, 14, 24, 1),
  ch_memTs, ch_mergesTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 23, 24, 1),
  ch_troubleGuide,
];
local chHeight = 29;

// ── matrix panels ──────────────────────────────────────────────────────────

local mat_alertPanel = c.alertCountPanel('continuwuity', col=0);

local mat_upStat =
  g.panel.stat.new('Matrix Up')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('matrix_up or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red',   value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local mat_rttTs =
  g.panel.timeSeries.new('Message Round-Trip Time')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('matrix_probe_send_rtt_seconds or vector(0)', 'RTT'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('single')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'green',  value: null },
    { color: 'yellow', value: 1 },
    { color: 'red',    value: 5 },
  ]);

local mat_errorsTs =
  g.panel.timeSeries.new('Probe Errors')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(matrix_probe_send_errors_total[5m]) or vector(0)', 'errors/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('single')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red',   value: 0.01 },
  ]);

local mat_usersTs =
  g.panel.timeSeries.new('Local Users over Time')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('matrix_local_users or vector(0)', 'users'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('single');

local mat_roomsTs =
  g.panel.timeSeries.new('Rooms over Time')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('matrix_rooms_joined or vector(0)', 'rooms'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('single');

local mat_troubleGuide = c.serviceTroubleshootingGuide('continuwuity', [
  { symptom: 'Matrix Down',        runbook: 'matrix/down',        check: '"Matrix Up" = 0 — check container@continuwuity systemd service' },
  { symptom: 'High RTT',           runbook: 'matrix/high-rtt',    check: '"Message Round-Trip Time" above 1s — check server load and disk I/O' },
  { symptom: 'Probe Errors',       runbook: 'matrix/probe-error', check: '"Probe Errors" > 0 — check matrix-exporter logs and credentials' },
], y=25);

local matrixPanels = [
  g.panel.row.new('💬 Matrix') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  mat_alertPanel, mat_upStat,
  g.panel.row.new('🔁 Probe — RTT & Errors') + c.pos(0, 6, 24, 1),
  mat_rttTs, mat_errorsTs,
  g.panel.row.new('👥 Growth')             + c.pos(0, 15, 24, 1),
  mat_usersTs, mat_roomsTs,
  g.panel.row.new('🔧 Troubleshooting')    + c.pos(0, 24, 24, 1),
  mat_troubleGuide,
];
local matrixHeight = 30;

// ── sbtcp panels ───────────────────────────────────────────────────────────

local sb_metricsDsVar =
  g.dashboard.variable.datasource.new('sbtcpmetrics', 'victoriametrics-metrics-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('SBTCP Metrics');

local sb_logsDsVar =
  g.dashboard.variable.datasource.new('sbtcplogs', 'victoriametrics-logs-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('SBTCP Logs');

local sb_entityIDVar =
  g.dashboard.variable.query.new('entity_id')
  + g.dashboard.variable.query.generalOptions.withLabel('Entity ID')
  + g.dashboard.variable.query.withDatasourceFromVariable(sb_metricsDsVar)
  + g.dashboard.variable.query.queryTypes.withLabelValues('entity_id', 'sbtcp_decision_thread_cycles_total')
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
  + g.dashboard.variable.query.generalOptions.withCurrent('All');

local sb_mQ(expr, legend='') =
  g.query.prometheus.new('$sbtcpmetrics', expr)
  + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {});

local sb_logsQ(expr) = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${sbtcplogs}' },
  expr: expr,
  refId: 'A',
  queryType: 'range',
  legendFormat: '',
  editorMode: 'code',
};

local sb_decisionCyclesStat =
  g.panel.stat.new('Decision Cycles')
  + c.pos(0, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    sb_mQ('increase(sbtcp_decision_thread_cycles_total[24h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local sb_interruptsStat =
  g.panel.stat.new('Interrupts (24h)')
  + c.pos(4, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    sb_mQ('increase(sbtcp_interrupt_received_total[24h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 5 },
    { color: 'red', value: 20 },
  ])
  + g.panel.stat.options.withColorMode('background');

local sb_tokensStat =
  g.panel.stat.new('LLM Tokens (24h)')
  + c.pos(8, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    sb_mQ('increase(sbtcp_llm_tokens_input_total[24h]) + increase(sbtcp_llm_tokens_output_total[24h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local sb_compactionsStat =
  g.panel.stat.new('Compactions (7d)')
  + c.pos(12, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    sb_mQ('increase(sbtcp_state_compaction_total[7d]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value');

local sb_anomaliesStat =
  g.panel.stat.new('Anomalies (24h)')
  + c.pos(16, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    sb_mQ('sum(increase(sbtcp_monitor_mesh_anomalies_total[24h])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 3 },
    { color: 'red', value: 10 },
  ])
  + g.panel.stat.options.withColorMode('background');

local sb_dtCycleRateTs =
  g.panel.timeSeries.new('Decision Thread Cycle Rate')
  + c.pos(0, 4, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sb_mQ('rate(sbtcp_decision_thread_cycles_total[5m])', 'cycles/s'),
    sb_mQ('rate(sbtcp_decision_thread_skipped_total[5m])', 'skipped/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sb_dtDurationTs =
  g.panel.timeSeries.new('Decision Thread Reasoning Duration')
  + c.pos(12, 4, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sb_mQ('histogram_quantile(0.50, rate(sbtcp_decision_thread_reasoning_duration_seconds_bucket[5m]))', 'P50'),
    sb_mQ('histogram_quantile(0.95, rate(sbtcp_decision_thread_reasoning_duration_seconds_bucket[5m]))', 'P95'),
    sb_mQ('histogram_quantile(0.99, rate(sbtcp_decision_thread_reasoning_duration_seconds_bucket[5m]))', 'P99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sb_llmTokensTs =
  g.panel.timeSeries.new('LLM Token Usage')
  + c.pos(0, 12, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sb_mQ('rate(sbtcp_llm_tokens_input_total[5m])', 'input tokens/s'),
    sb_mQ('rate(sbtcp_llm_tokens_output_total[5m])', 'output tokens/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sb_llmDurationTs =
  g.panel.timeSeries.new('LLM Reasoning Duration')
  + c.pos(12, 12, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sb_mQ('histogram_quantile(0.50, rate(sbtcp_llm_reasoning_duration_seconds_bucket[5m]))', 'P50'),
    sb_mQ('histogram_quantile(0.95, rate(sbtcp_llm_reasoning_duration_seconds_bucket[5m]))', 'P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sb_meshChecksTs =
  g.panel.timeSeries.new('Monitor Mesh Checks by Monitor')
  + c.pos(0, 20, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sb_mQ('rate(sbtcp_monitor_mesh_checks_total[5m])', '{{monitor}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sb_interruptRateTs =
  g.panel.timeSeries.new('Interrupt Rate (received vs handled)')
  + c.pos(12, 20, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sb_mQ('rate(sbtcp_interrupt_received_total[5m])', 'received'),
    sb_mQ('rate(sbtcp_interrupt_handled_total[5m])', 'handled'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sb_resultStatusTs =
  g.panel.timeSeries.new('Activity Result Status Distribution')
  + c.pos(0, 28, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sb_mQ('rate(sbtcp_result_status_total[5m])', '{{status}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sb_compactionTs =
  g.panel.timeSeries.new('State Compaction Events')
  + c.pos(12, 28, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sb_mQ('increase(sbtcp_state_compaction_total[1h])', 'compactions/h'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10);

local sb_logsPanel =
  g.panel.logs.new('SBTCP Entity Logs')
  + c.pos(0, 36, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    sb_logsQ('{service="sbtcp"} | json | limit 200'),
  ])
  + g.panel.logs.options.withShowTime(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withDedupStrategy('none');

local sbtcpPanels = [
  g.panel.row.new('⚙️ SBTCP') + c.pos(0, 0, 24, 1),
  sb_decisionCyclesStat,
  sb_interruptsStat,
  sb_tokensStat,
  sb_compactionsStat,
  sb_anomaliesStat,
  sb_dtCycleRateTs,
  sb_dtDurationTs,
  sb_llmTokensTs,
  sb_llmDurationTs,
  sb_meshChecksTs,
  sb_interruptRateTs,
  sb_resultStatusTs,
  sb_compactionTs,
  sb_logsPanel,
];
local sbtcpHeight = 46;

// ── elasticsearch panels ───────────────────────────────────────────────────

local es_alertPanel = c.alertCountPanel('elasticsearch', col=0) + c.pos(0, 1, 4, 3);

local es_upStat =
  g.panel.stat.new('Elasticsearch Up')
  + c.pos(4, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('up{job="elasticsearch-exporter"} or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('value_and_name');

local es_healthStat =
  g.panel.stat.new('Cluster Health')
  + c.pos(8, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('elasticsearch_cluster_health_status{color="green"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local es_nodesStat =
  g.panel.stat.new('Nodes')
  + c.pos(13, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('elasticsearch_cluster_health_number_of_nodes or vector(0)')])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value');

local es_searchLatStat =
  g.panel.stat.new('Search Latency (avg)')
  + c.pos(21, 1, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(elasticsearch_indices_search_query_time_seconds / clamp_min(elasticsearch_indices_search_query_total, 1) * 1000) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local es_indexTs =
  g.panel.timeSeries.new('Indexing Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(elasticsearch_indices_indexing_index_total[5m])) or vector(0)', 'index/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

local es_searchTs =
  g.panel.timeSeries.new('Search Rate')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(elasticsearch_indices_search_query_total[5m])) or vector(0)', 'query/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

local es_jvmTs =
  g.panel.timeSeries.new('JVM Heap Used')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('elasticsearch_jvm_memory_used_bytes{area="heap"} or vector(0)', 'heap used'),
    c.vmQ('elasticsearch_jvm_memory_max_bytes{area="heap"} or vector(0)', 'heap max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local es_diskTs =
  g.panel.timeSeries.new('Disk Store Size')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(elasticsearch_indices_store_size_bytes) or vector(0)', 'total store'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

local es_logsPanel =
  g.panel.logs.new('Elasticsearch Logs')
  + c.logPos(24)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service="prometheus-elasticsearch-exporter"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local es_troubleGuide = c.serviceTroubleshootingGuide('elasticsearch', [
  { symptom: 'Cluster Not Green', runbook: 'elasticsearch/cluster-health', check: '"Cluster Health" = 0 (not green) — check shard allocation and logs' },
  { symptom: 'High JVM Memory', runbook: 'elasticsearch/jvm-tuning', check: '"JVM Heap Used" near max — check GC pressure, consider heap_size setting' },
  { symptom: 'Slow Searches', runbook: 'elasticsearch/search-perf', check: '"Search Latency" high — check slow search log, query patterns, shard count' },
  { symptom: 'Disk Space Low', runbook: 'elasticsearch/disk-management', check: '"Disk Store Size" growing fast — check index retention policies' },
  { symptom: 'Index Failures', runbook: 'elasticsearch/indexing', check: '"Indexing Rate" dropped — check bulk API errors in logs' },
], y=35);

local esPanels = [
  g.panel.row.new('🔍 Elasticsearch') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  es_alertPanel, es_upStat, es_healthStat, es_nodesStat, es_searchLatStat,
  g.panel.row.new('🔍 Indexing & Search') + c.pos(0, 6, 24, 1),
  es_indexTs, es_searchTs,
  g.panel.row.new('🏗️ JVM & Disk') + c.pos(0, 14, 24, 1),
  es_jvmTs, es_diskTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  es_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  es_troubleGuide,
];
local esHeight = 40;

// ── redpanda panels ────────────────────────────────────────────────────────

local rp_alertPanel = c.alertCountPanel('redpanda', col=0);

local rp_upStat =
  g.panel.stat.new('Redpanda Up')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('up{job="redpanda"} or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('value_and_name');

local rp_uptimeStat =
  g.panel.stat.new('Broker Uptime')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('vectorized_application_uptime or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value');

local rp_throughputInStat =
  g.panel.stat.new('Bytes In/sec')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_produced_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local rp_throughputOutStat =
  g.panel.stat.new('Bytes Out/sec')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_fetched_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local rp_throughputTs =
  g.panel.timeSeries.new('Throughput')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_produced_total[5m])) or vector(0)', 'produce'),
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_fetched_total[5m])) or vector(0)', 'fetch'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local rp_lagTs =
  g.panel.timeSeries.new('Consumer Group Lag')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(sum by(group, topic) (vectorized_cluster_partition_high_watermark - on(topic, partition) group_right(group) vectorized_kafka_group_offset)) or vector(0)',
      '{{group}}/{{topic}}'
    ),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local rp_troubleGuide = c.serviceTroubleshootingGuide('redpanda', [
  { symptom: 'Broker Down', runbook: 'redpanda/broker-down', check: '"Redpanda Up" = 0 — check service status and logs' },
  { symptom: 'High Consumer Lag', runbook: 'redpanda/consumer-lag', check: '"Consumer Group Lag" chart — lag means consumers are behind producers' },
  { symptom: 'Low Throughput', runbook: 'redpanda/throughput', check: '"Throughput" chart dropping — check producers, network, or disk' },
  { symptom: 'Produce Errors', runbook: 'redpanda/produce-errors', check: 'Check logs for kafka protocol errors' },
  { symptom: 'Partition Offline', runbook: 'redpanda/partitions', check: 'Check "Redpanda Up" and broker logs for partition election errors' },
], y=16);

local redpandaPanels = [
  g.panel.row.new('🐼 Redpanda') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  rp_alertPanel, rp_upStat, rp_uptimeStat, rp_throughputInStat, rp_throughputOutStat,
  g.panel.row.new('📤 Throughput & Lag') + c.pos(0, 6, 24, 1),
  rp_throughputTs, rp_lagTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 15, 24, 1),
  rp_troubleGuide,
];
local redpandaHeight = 21;

// ── mcp-vanguard panels ────────────────────────────────────────────────────

local mv_alertPanel = c.alertCountPanel('mcp-vanguard', col=0);

local mv_totalCallsStat =
  g.panel.stat.new('Requests (1h)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(mcp_vanguard_requests_total[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local mv_successRateStat =
  g.panel.stat.new('Success Rate (15m)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(
      '(sum(rate(mcp_vanguard_requests_total{status="ok"}[15m])) / sum(rate(mcp_vanguard_requests_total[15m]))) or vector(1)',
    ),
  ])
  + g.panel.stat.standardOptions.withUnit('percentunit')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 0.9 },
    { color: 'green', value: 0.99 },
  ])
  + g.panel.stat.options.withColorMode('background');

local mv_totalTokensStat =
  g.panel.stat.new('Tokens Consumed (1h)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(mcp_vanguard_anthropic_tokens_total[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local mv_requestRateTs =
  g.panel.timeSeries.new('Request Rate by Status')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(mcp_vanguard_requests_total[5m])', '{{tool}} / {{status}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local mv_latencyTs =
  g.panel.timeSeries.new('Request Latency p50 / p95 / p99 (seconds)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.50, sum by(le, tool) (rate(mcp_vanguard_request_duration_seconds_bucket[5m])))',
      'p50 {{tool}}'
    ),
    c.vmQ(
      'histogram_quantile(0.95, sum by(le, tool) (rate(mcp_vanguard_request_duration_seconds_bucket[5m])))',
      'p95 {{tool}}'
    ),
    c.vmQ(
      'histogram_quantile(0.99, sum by(le, tool) (rate(mcp_vanguard_request_duration_seconds_bucket[5m])))',
      'p99 {{tool}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local mv_tokensTs =
  g.panel.timeSeries.new('Anthropic Tokens / min (by type and model)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(mcp_vanguard_anthropic_tokens_total[5m]) * 60', '{{type}} / {{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local mv_errorRateTs =
  g.panel.timeSeries.new('Error Rate %')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(sum(rate(mcp_vanguard_requests_total{status="error"}[5m])) / sum(rate(mcp_vanguard_requests_total[5m]))) * 100 or vector(0)',
      'error %'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.options.tooltip.withMode('single');

local mv_troubleGuide = c.serviceTroubleshootingGuide('mcp-vanguard', [
  { symptom: 'No metrics', runbook: 'mcp-vanguard/down', check: 'Dashboard empty = service not running; check port 9196 and service status' },
  { symptom: 'Authentication failures', runbook: 'mcp-vanguard/auth', check: 'Check API key file at configured path or ANTHROPIC_API_KEY env' },
  { symptom: 'High latency / timeouts', runbook: 'mcp-vanguard/latency', check: '"Request Latency p95/p99" — default timeout is 30s' },
  { symptom: 'High error rate', runbook: 'mcp-vanguard/errors', check: '"Error Rate %" above 1% — check logs for error type' },
  { symptom: 'Rate limit errors (429)', runbook: 'mcp-vanguard/rate-limits', check: 'Reduce request frequency or upgrade Anthropic plan' },
], y=35);

local mcpVanguardPanels = [
  g.panel.row.new('🤖 MCP Vanguard') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  mv_alertPanel, mv_totalCallsStat, mv_successRateStat, mv_totalTokensStat,
  g.panel.row.new('⚡ Request Activity') + c.pos(0, 6, 24, 1),
  mv_requestRateTs, mv_latencyTs,
  g.panel.row.new('🤖 Anthropic API') + c.pos(0, 14, 24, 1),
  mv_tokensTs, mv_errorRateTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  mv_troubleGuide,
];
local mcpVanguardHeight = 23;

// ── nixos-mcp panels ───────────────────────────────────────────────────────

local nm_alertPanel = c.alertCountPanel('nixos-mcp', col=0);

local nm_totalCallsStat =
  g.panel.stat.new('Tool Calls (1h)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(nixos_mcp_tool_calls_total[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local nm_successRateStat =
  g.panel.stat.new('Success Rate (15m)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(
      '(sum(rate(nixos_mcp_tool_calls_total{status="success"}[15m])) / sum(rate(nixos_mcp_tool_calls_total[15m]))) or vector(1)',
    ),
  ])
  + g.panel.stat.standardOptions.withUnit('percentunit')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 0.9 },
    { color: 'green', value: 0.99 },
  ])
  + g.panel.stat.options.withColorMode('background');

local nm_activeConnectionsStat =
  g.panel.stat.new('Active Connections')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nixos_mcp_active_connections or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local nm_toolCallsTs =
  g.panel.timeSeries.new('Tool Calls by Tool and Status')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(nixos_mcp_tool_calls_total[5m])', '{{tool}} / {{status}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local nm_durationTs =
  g.panel.timeSeries.new('Tool Duration p95 (seconds)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.95, sum by(le, tool) (rate(nixos_mcp_tool_duration_seconds_bucket[5m]))) or vector(0)',
      'p95 {{tool}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local nm_troubleGuide = c.serviceTroubleshootingGuide('nixos-mcp', [
  { symptom: 'No metrics', runbook: 'nixos-mcp/down', check: 'Dashboard empty = service not running; metrics bind to 127.0.0.1:9122, check VM scrape config' },
  { symptom: 'Deploy failures', runbook: 'nixos-mcp/deploy-failures', check: '"Tool Calls by Status" — filter tool=nixos_deploy for deploy-specific errors' },
  { symptom: 'High error rate', runbook: 'nixos-mcp/high-errors', check: '"Success Rate" below 99% — check logs for error messages' },
  { symptom: 'Slow tool calls', runbook: 'nixos-mcp/performance', check: '"Tool Duration p95" — deploy is expected slow (minutes), other tools should be sub-second' },
], y=26);

local nixosMcpPanels = [
  g.panel.row.new('🔧 NixOS MCP') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  nm_alertPanel, nm_totalCallsStat, nm_successRateStat, nm_activeConnectionsStat,
  g.panel.row.new('🔧 Tool Activity') + c.pos(0, 6, 24, 1),
  nm_toolCallsTs, nm_durationTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 25, 24, 1),
  nm_troubleGuide,
];
local nixosMcpHeight = 14;

// ── victorialogs-general panels ────────────────────────────────────────────

local vl_i = 'instance=~".*:9435"';

local vl_uptimeStat =
  g.panel.stat.new('Uptime')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('vm_app_uptime_seconds{' + vl_i + '}')])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local vl_pendingRowsStat =
  g.panel.stat.new('Pending Rows')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('sum(vl_pending_rows{' + vl_i + '}) or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1000 },
    { color: 'red', value: 10000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local vl_ingestRateStat =
  g.panel.stat.new('Ingest Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('rate(vl_rows_ingested_total{' + vl_i + '}[1m]) or vector(0)')])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local vl_httpErrorsStat =
  g.panel.stat.new('HTTP Errors (5m)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('increase(vl_http_errors_total{' + vl_i + '}[5m]) or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local vl_ingestTs =
  g.panel.timeSeries.new('Ingestion Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(vl_rows_ingested_total{' + vl_i + '}[1m]) or vector(0)', 'rows/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vl_pendingRowsTs =
  g.panel.timeSeries.new('Pending Rows by Type')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vl_pending_rows{type="storage",' + vl_i + '} or vector(0)', 'storage (data)'),
    c.vmQ('vl_pending_rows{type="indexdb",' + vl_i + '} or vector(0)', 'indexdb'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vl_partsTs =
  g.panel.timeSeries.new('Parts Count')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vl_storage_parts{type="storage/inmemory",' + vl_i + '} or vector(0)', 'inmemory'),
    c.vmQ('vl_storage_parts{type="storage/small",' + vl_i + '} or vector(0)', 'small'),
    c.vmQ('vl_storage_parts{type="storage/big",' + vl_i + '} or vector(0)', 'big'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vl_mergeDurationTs =
  g.panel.timeSeries.new('Merge Duration (p50/p95)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vl_merge_duration_seconds{quantile="0.5",' + vl_i + '} or vector(0)', 'p50'),
    c.vmQ('vl_merge_duration_seconds{quantile="0.95",' + vl_i + '} or vector(0)', 'p95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(3)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vl_httpRequestsTs =
  g.panel.timeSeries.new('HTTP Request Rate')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (path) (rate(vl_http_requests_total{' + vl_i + '}[1m])) or vector(0)', '{{path}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vl_dataSizeTs =
  g.panel.timeSeries.new('Storage Size')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vl_data_size_bytes{type="storage",' + vl_i + '} or vector(0)', 'data'),
    c.vmQ('vl_data_size_bytes{type="indexdb",' + vl_i + '} or vector(0)', 'index'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vl_logsPanel = c.serviceLogsPanel('victorialogs-general Logs', 'victorialogs-general', y=29);

local victorialogsPanels = [
  g.panel.row.new('📊 VictoriaLogs General') + c.pos(0, 0, 24, 1),
  vl_uptimeStat,
  vl_pendingRowsStat,
  vl_ingestRateStat,
  vl_httpErrorsStat,
  vl_ingestTs,
  vl_pendingRowsTs,
  vl_partsTs,
  vl_mergeDurationTs,
  vl_httpRequestsTs,
  vl_dataSizeTs,
  vl_logsPanel,
];
local victorialogsHeight = 39;

// ── nixos-deployer panels ──────────────────────────────────────────────────

local nd_alertPanel = c.alertCountPanel('nixos-deployer', col=0);

local nd_deploySuccessRateStat =
  g.panel.stat.new('Deploy Success Rate')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(nixos_deploy_total{status="success"}[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local nd_stagingLagStat =
  g.panel.stat.new('Staging Lag (commits)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nixos_staging_lag_commits or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 3 },
    { color: 'red', value: 6 },
  ])
  + g.panel.stat.options.withColorMode('background');

local nd_generationsStat =
  g.panel.stat.new('NixOS Generations')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nixos_generations_total or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local nd_deploysByStatusTs =
  g.panel.timeSeries.new('Deploys by Status')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('increase(nixos_deploy_total[10m])', '{{status}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local nd_deployDurationTs =
  g.panel.timeSeries.new('Deploy Duration p95')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.95, sum by(le, stage) (rate(nixos_deploy_duration_seconds_bucket[30m]))) or vector(0)',
      'p95 {{stage}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local nd_troubleGuide = c.serviceTroubleshootingGuide('nixos-deployer', [
  { symptom: 'Deploy Failures', runbook: 'nixos-deployer/deploy-failures', check: '"Deploys by Status" — failure rate climbing means config or build error' },
  { symptom: 'High Staging Lag', runbook: 'nixos-deployer/staging-lag', check: '"Staging Lag (commits)" — 3+ commits undeployed = poller or deploy blocked' },
  { symptom: 'Slow Deployments', runbook: 'nixos-deployer/performance', check: '"Deploy Duration p95" — which stage is slow (build/activate/switch)?' },
  { symptom: 'Deployer Down', runbook: 'nixos-deployer/down', check: 'No data in dashboard — check service status and port 9110' },
], y=26);

local nixosDeployerPanels = [
  g.panel.row.new('🚀 NixOS Deployer') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  nd_alertPanel, nd_deploySuccessRateStat, nd_stagingLagStat, nd_generationsStat,
  g.panel.row.new('🚀 Deploy Activity') + c.pos(0, 6, 24, 1),
  nd_deploysByStatusTs, nd_deployDurationTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 25, 24, 1),
  nd_troubleGuide,
];
local nixosDeployerHeight = 14;

// ── serena-backends panels ─────────────────────────────────────────────────

local sr_serenaService = 'serena-standalone-rs';

local sr_alertPanel = c.alertCountPanel('serena-backends', col=0);

local sr_cpmStat =
  g.panel.stat.new('Calls/min')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_cpm{service="' + sr_serenaService + '"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short');

local sr_respTimeStat =
  g.panel.stat.new('Avg Response Time')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_resp_time{service="' + sr_serenaService + '"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ]);

local sr_slaStat =
  g.panel.stat.new('Success Rate (SLA)')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_sla{service="' + sr_serenaService + '"} / 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 99 },
  ])
  + g.panel.stat.options.withColorMode('background');

local sr_errorRateStat =
  g.panel.stat.new('Error Rate')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_error_rate{service="' + sr_serenaService + '"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local sr_cpmTs =
  g.panel.timeSeries.new('Calls/min — History')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_cpm{service="' + sr_serenaService + '"}) or vector(0)', 'cpm'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('single');

local sr_latencyTs =
  g.panel.timeSeries.new('Response Time Percentiles (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_percentile{service="' + sr_serenaService + '",le="50"}) or vector(0)',  'p50'),
    c.swQ('(service_percentile{service="' + sr_serenaService + '",le="75"}) or vector(0)',  'p75'),
    c.swQ('(service_percentile{service="' + sr_serenaService + '",le="90"}) or vector(0)',  'p90'),
    c.swQ('(service_percentile{service="' + sr_serenaService + '",le="99"}) or vector(0)',  'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sr_errorRateTs =
  g.panel.timeSeries.new('Error Rate (%)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_error_rate{service="' + sr_serenaService + '"}) or vector(0)', 'error %'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.options.tooltip.withMode('single');

local sr_toolCpmTs =
  g.panel.timeSeries.new('Calls/min per Tool')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('topk(10, (endpoint_cpm{service="' + sr_serenaService + '"}) or vector(0))', '{{endpoint}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sr_toolLatencyTs =
  g.panel.timeSeries.new('Avg Latency per Tool (ms)')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('topk(10, (endpoint_resp_time{service="' + sr_serenaService + '"}) or vector(0))', '{{endpoint}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sr_troubleGuide = c.serviceTroubleshootingGuide('serena-backends', [
  { symptom: 'Serena Latency High', runbook: 'serena/latency-spike', check: 'Check Avg Response Time stat and per-tool latency breakdown' },
  { symptom: 'Serena Error Rate Up', runbook: 'serena/error-investigation', check: 'Review Error Rate stat and check error logs for stack traces' },
  { symptom: 'Backend Service Down', runbook: 'serena/backend-outage', check: 'Check Backend Services grid for red status indicators' },
  { symptom: 'MCP Connection Lost', runbook: 'serena/mcp-reconnect', check: 'Verify Serena MCP process running and check SLA metric' },
], y=42);

local sr_errorLogs =
  g.panel.logs.new('Recent Errors & Warnings')
  + c.logPos(28)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{level=~"(error|warning)"} or _msg:~"(Exception|Error)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local serenaPanels = [
  g.panel.row.new('🐉 Serena & Backends') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  sr_alertPanel, sr_cpmStat, sr_respTimeStat, sr_slaStat, sr_errorRateStat,
  g.panel.row.new('📈 Serena MCP — Trends') + c.pos(0, 6, 24, 1),
  sr_cpmTs, sr_latencyTs,
  sr_errorRateTs, sr_toolCpmTs,
  g.panel.row.new('🔧 Serena — Per-Tool Breakdown') + c.pos(0, 22, 24, 1),
  sr_toolLatencyTs,
  g.panel.row.new('❌ Error Logs') + c.pos(0, 30, 24, 1),
  sr_errorLogs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 41, 24, 1),
  sr_troubleGuide,
];
local serenaHeight = 47;

// ── Dashboard assembly ─────────────────────────────────────────────────────

local offset0  = 0;
local offset1  = offset0  + temporalHeight;
local offset2  = offset1  + redisHeight;
local offset3  = offset2  + pgHeight;
local offset4  = offset3  + chHeight;
local offset5  = offset4  + matrixHeight;
local offset6  = offset5  + sbtcpHeight;
local offset7  = offset6  + esHeight;
local offset8  = offset7  + redpandaHeight;
local offset9  = offset8  + mcpVanguardHeight;
local offset10 = offset9  + nixosMcpHeight;
local offset11 = offset10 + victorialogsHeight;
local offset12 = offset11 + nixosDeployerHeight;

g.dashboard.new('Services')
+ g.dashboard.withUid('home-services')
+ g.dashboard.withDescription('All homelab services — Temporal, Redis, PostgreSQL, ClickHouse, Matrix, SBTCP, Elasticsearch, Redpanda, MCP Vanguard, NixOS MCP, VictoriaLogs, NixOS Deployer, and Serena.')
+ g.dashboard.withTags(['services', 'homelab'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.swDsVar, sb_metricsDsVar, sb_logsDsVar, sb_entityIDVar, c.vmAdhocVar, c.vlogsAdhocVar])
+ g.dashboard.withPanels(
    c.withYOffset(temporalPanels,      offset0)
    + c.withYOffset(redisPanels,       offset1)
    + c.withYOffset(pgPanels,          offset2)
    + c.withYOffset(chPanels,          offset3)
    + c.withYOffset(matrixPanels,      offset4)
    + c.withYOffset(sbtcpPanels,       offset5)
    + c.withYOffset(esPanels,          offset6)
    + c.withYOffset(redpandaPanels,    offset7)
    + c.withYOffset(mcpVanguardPanels, offset8)
    + c.withYOffset(nixosMcpPanels,    offset9)
    + c.withYOffset(victorialogsPanels, offset10)
    + c.withYOffset(nixosDeployerPanels, offset11)
    + c.withYOffset(serenaPanels,      offset12)
  )
