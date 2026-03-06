// Dashboard: Services — Redis
// Question:  "Is Redis healthy? Memory, operations, hit rate, evictions."
//
// Data: redis_* from redis_exporter (service="redis")
// Confirmed metrics: redis_up, redis_memory_used_bytes, redis_memory_max_bytes,
//   redis_commands_total, redis_keyspace_hits_total, redis_keyspace_misses_total,
//   redis_evicted_keys_total, redis_connected_clients, redis_rejected_connections_total

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local alertPanel = c.alertCountPanel('redis', col=0);

// ── Row 0: Key Stats ──────────────────────────────────────────────────────────

local upStat =
  g.panel.stat.new('Redis Up')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('redis_up or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local memStat =
  g.panel.stat.new('Memory Used')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('redis_memory_used_bytes or vector(0)')])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local hitRateStat =
  g.panel.stat.new('Keyspace Hit Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    // clamp_min prevents division-by-zero when both hits and misses are 0.
    c.vmQ('(rate(redis_keyspace_hits_total[5m]) or vector(0)) / clamp_min((rate(redis_keyspace_hits_total[5m]) or vector(0)) + (rate(redis_keyspace_misses_total[5m]) or vector(0)), 0.001) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + c.freeThresholds;

// ── Row 1: Operations & Memory ────────────────────────────────────────────────

local opsTs =
  g.panel.timeSeries.new('Operations/sec by Command')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_commands_total[5m]) or vector(0)', '{{cmd}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local memTs =
  g.panel.timeSeries.new('Memory Usage')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('redis_memory_used_bytes or vector(0)', 'used'),
    c.vmQ('redis_memory_max_bytes or vector(0)', 'max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Evictions & Keyspace ───────────────────────────────────────────────

local evictTs =
  g.panel.timeSeries.new('Evictions/sec')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_evicted_keys_total[5m]) or vector(0)', 'evictions'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

local hitsTs =
  g.panel.timeSeries.new('Keyspace Hits vs Misses')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_keyspace_hits_total[5m]) or vector(0)', 'hits'),
    c.vmQ('rate(redis_keyspace_misses_total[5m]) or vector(0)', 'misses'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: Logs ───────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Redis Logs', 'redis', y=22);

// ── Row 4: Troubleshooting ────────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('redis', [
  { symptom: 'High Memory Usage', runbook: 'redis/memory-pressure', check: '"Memory Used" near max = risk of evictions or OOM' },
  { symptom: 'High Eviction Rate', runbook: 'redis/eviction', check: '"Evictions/sec" — evictions mean memory is full, keys being dropped' },
  { symptom: 'Low Hit Rate', runbook: 'redis/cache-opt', check: '"Keyspace Hit Rate" below 90% = cache miss problem or cold cache' },
  { symptom: 'Spike in Operations', runbook: 'redis/performance', check: '"Operations/sec by Command" — look for unexpected command patterns' },
  { symptom: 'Redis Down', runbook: 'redis/down', check: '"Redis Up" = 0 — check service status and logs' },
], y=34);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Services — Redis')
+ g.dashboard.withUid('services-redis')
+ g.dashboard.withDescription('Redis operations, memory, hit rate, evictions, and alerts.')
+ g.dashboard.withTags(['services', 'redis', 'cache', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, upStat, memStat, hitRateStat,

  g.panel.row.new('⚡ Operations') + c.pos(0, 4, 24, 1),
  opsTs, memTs,

  g.panel.row.new('💾 Evictions & Keyspace') + c.pos(0, 13, 24, 1),
  evictTs, hitsTs,

  g.panel.row.new('📝 Logs') + c.pos(0, 22, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 33, 24, 1),
  troubleGuide,
])
