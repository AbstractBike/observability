local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local upStat =
  g.panel.stat.new('Redis Up')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('redis_up')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local memStat =
  g.panel.stat.new('Memory Used')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('redis_memory_used_bytes')])
  + g.panel.stat.standardOptions.withUnit('bytes');

local hitRateStat =
  g.panel.stat.new('Keyspace Hit Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    // clamp_min prevents division-by-zero when both hits and misses are 0.
    c.vmQ('(rate(redis_keyspace_hits_total[5m]) or vector(0)) / clamp_min((rate(redis_keyspace_hits_total[5m]) or vector(0)) + (rate(redis_keyspace_misses_total[5m]) or vector(0)), 0.001) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + c.freeThresholds;

local connStat =
  g.panel.stat.new('Connected Clients')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('redis_connected_clients')])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local opsTs =
  g.panel.timeSeries.new('Operations/sec')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_commands_total[5m])', '{{cmd}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local memTs =
  g.panel.timeSeries.new('Memory Usage')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('redis_memory_used_bytes', 'used'),
    c.vmQ('redis_memory_max_bytes', 'max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local evictTs =
  g.panel.timeSeries.new('Evictions/sec')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_evicted_keys_total[5m])', 'evictions'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps');

local hitsTs =
  g.panel.timeSeries.new('Keyspace Hits vs Misses')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(redis_keyspace_hits_total[5m])', 'hits'),
    c.vmQ('rate(redis_keyspace_misses_total[5m])', 'misses'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel = c.serviceLogsPanel('Redis Logs', 'redis');

g.dashboard.new('Services — Redis')
+ g.dashboard.withUid('services-redis')
+ g.dashboard.withDescription('Redis operations, memory, hit rate, and evictions.')
+ g.dashboard.withTags(['services', 'redis'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  upStat, memStat, hitRateStat, connStat,
  g.panel.row.new('Operations') + c.pos(0, 4, 24, 1),
  opsTs, memTs,
  g.panel.row.new('Evictions & Keyspace') + c.pos(0, 12, 24, 1),
  evictTs, hitsTs,
  g.panel.row.new('Logs') + c.pos(0, 20, 24, 1),
  logsPanel,
])
