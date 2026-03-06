local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Alert count panel (colored by alert state)
local alertCountPanel =
  g.panel.stat.new('🚨 Active Alerts')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(ALERTS{service="redis",alertstate="firing"}) or vector(0)'),
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
    <a href="/d/services-redis">🔴 Redis</a>
    | <a href="/d/redis-cluster">🔗 Cluster Status</a>
  |||);

local upStat =
  g.panel.stat.new('Redis Up')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('redis_up')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local memStat =
  g.panel.stat.new('Memory Used')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('redis_memory_used_bytes')])
  + g.panel.stat.standardOptions.withUnit('bytes');

local hitRateStat =
  g.panel.stat.new('Keyspace Hit Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    // clamp_min prevents division-by-zero when both hits and misses are 0.
    c.vmQ('(rate(redis_keyspace_hits_total[5m]) or vector(0)) / clamp_min((rate(redis_keyspace_hits_total[5m]) or vector(0)) + (rate(redis_keyspace_misses_total[5m]) or vector(0)), 0.001) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + c.freeThresholds;

local connStat =
  g.panel.stat.new('Connected Clients')
  + c.statPos(4)
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

// Troubleshooting guide with runbook links
local troubleshootingPanel =
  g.panel.text.new('🔧 Troubleshooting Guide')
  + c.pos(0, 28, 24, 5)
  + g.panel.text.panelOptions.withTransparent(false)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Symptom | Runbook | Quick Check |
    |---------|---------|------------|
    | **High Memory Usage** | [Memory Pressure](https://wiki.pin/runbooks/redis/memory-pressure) | Check "Memory Used" stat or "Memory Usage" graph |
    | **High Eviction Rate** | [Eviction Management](https://wiki.pin/runbooks/redis/eviction) | Look at "Evictions/sec" chart |
    | **Low Hit Ratio** | [Cache Optimization](https://wiki.pin/runbooks/redis/cache-opt) | Check "Keyspace Hit Rate" stat |
    | **Connection Spikes** | [Connection Handling](https://wiki.pin/runbooks/redis/connections) | Look at "Connected Clients" stat |
    | **Slow Operations** | [Performance Tuning](https://wiki.pin/runbooks/redis/performance) | Check "Operations/sec" and latency |

    **On-Call Workflow:**
    1. Click alert notification → opens this dashboard
    2. Check "Active Alerts" panel (top-left)
    3. Find symptom in troubleshooting table above
    4. Click runbook link to follow resolution steps
    5. Monitor metrics improve in real-time
  |||);

g.dashboard.new('Services — Redis')
+ g.dashboard.withUid('services-redis')
+ g.dashboard.withDescription('Redis operations, memory, hit rate, evictions, and alerts.')
+ g.dashboard.withTags(['services', 'redis', 'cache', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  breadcrumbs,
  alertCountPanel, upStat, memStat, hitRateStat, connStat,
  g.panel.row.new('⚡ Operations') + c.pos(0, 5, 24, 1),
  opsTs, memTs,
  g.panel.row.new('💾 Evictions & Keyspace') + c.pos(0, 13, 24, 1),
  evictTs, hitsTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 27, 24, 1),
  troubleshootingPanel,
])
