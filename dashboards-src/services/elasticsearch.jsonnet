local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Alert panel (4 wide to leave room for 5 stats in 24 columns: 4+4+5+5+3+3=24)
local alertPanel = c.alertCountPanel('elasticsearch', col=0) + c.pos(0, 1, 4, 3);

// 6-stat layout: alert(4) + up(4) + health(5) + nodes(4) + indexRate(4) + searchLat(3) = 24
local upStat =
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

local healthStat =
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

local nodesStat =
  g.panel.stat.new('Nodes')
  + c.pos(13, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('elasticsearch_cluster_health_number_of_nodes or vector(0)')])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value');

local indexRateStat =
  g.panel.stat.new('Indexing Rate')
  + c.pos(18, 1, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(elasticsearch_indices_indexing_index_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local searchLatStat =
  g.panel.stat.new('Search Latency (avg)')
  + c.pos(21, 1, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    // avg latency = total_time / total_count (not a percentile)
    c.vmQ('(elasticsearch_indices_search_query_time_seconds / clamp_min(elasticsearch_indices_search_query_total, 1) * 1000) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local indexTs =
  g.panel.timeSeries.new('Indexing Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(elasticsearch_indices_indexing_index_total[5m])) or vector(0)', 'index/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

local searchTs =
  g.panel.timeSeries.new('Search Rate')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(elasticsearch_indices_search_query_total[5m])) or vector(0)', 'query/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

local jvmTs =
  g.panel.timeSeries.new('JVM Heap Used')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('elasticsearch_jvm_memory_used_bytes{area="heap"} or vector(0)', 'heap used'),
    c.vmQ('elasticsearch_jvm_memory_max_bytes{area="heap"} or vector(0)', 'heap max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local diskTs =
  g.panel.timeSeries.new('Disk Store Size')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(elasticsearch_indices_store_size_bytes) or vector(0)', 'total store'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

local logsPanel = c.serviceLogsPanel('Elasticsearch Logs', 'elasticsearch', y=24);

local troubleGuide = c.serviceTroubleshootingGuide('elasticsearch', [
  { symptom: 'Cluster Not Green', runbook: 'elasticsearch/cluster-health', check: '"Cluster Health" = 0 (not green) — check shard allocation and logs' },
  { symptom: 'High JVM Memory', runbook: 'elasticsearch/jvm-tuning', check: '"JVM Heap Used" near max — check GC pressure, consider heap_size setting' },
  { symptom: 'Slow Searches', runbook: 'elasticsearch/search-perf', check: '"Search Latency" high — check slow search log, query patterns, shard count' },
  { symptom: 'Disk Space Low', runbook: 'elasticsearch/disk-management', check: '"Disk Store Size" growing fast — check index retention policies' },
  { symptom: 'Index Failures', runbook: 'elasticsearch/indexing', check: '"Indexing Rate" dropped — check bulk API errors in logs' },
], y=35);

g.dashboard.new('Services — Elasticsearch')
+ g.dashboard.withUid('services-elasticsearch')
+ g.dashboard.withDescription('Elasticsearch cluster health, indexing rate, search latency, JVM heap, and alerts.')
+ g.dashboard.withTags(['services', 'elasticsearch', 'search', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, upStat, healthStat, nodesStat, indexRateStat, searchLatStat,
  g.panel.row.new('🔍 Indexing & Search') + c.pos(0, 6, 24, 1),
  indexTs, searchTs,
  g.panel.row.new('🏗️ JVM & Disk') + c.pos(0, 14, 24, 1),
  jvmTs, diskTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  troubleGuide,
])
