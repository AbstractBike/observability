local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local healthStat =
  g.panel.stat.new('Cluster Health')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('elasticsearch_cluster_health_status{color="green"}'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local nodesStat =
  g.panel.stat.new('Nodes')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('elasticsearch_cluster_health_number_of_nodes')]);

local indexRateStat =
  g.panel.stat.new('Indexing Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(elasticsearch_indices_indexing_index_total[5m]))'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps');

local searchLatStat =
  g.panel.stat.new('Search Latency p99')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('elasticsearch_indices_search_query_time_seconds / elasticsearch_indices_search_query_total * 1000'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms');

local indexTs =
  g.panel.timeSeries.new('Indexing Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(elasticsearch_indices_indexing_index_total[5m]))', 'index/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps');

local searchTs =
  g.panel.timeSeries.new('Search Rate')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(elasticsearch_indices_search_query_total[5m]))', 'query/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps');

local jvmTs =
  g.panel.timeSeries.new('JVM Heap Used')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('elasticsearch_jvm_memory_used_bytes{area="heap"}', 'heap used'),
    c.vmQ('elasticsearch_jvm_memory_max_bytes{area="heap"}', 'heap max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local diskTs =
  g.panel.timeSeries.new('Disk Store Size')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(elasticsearch_indices_store_size_bytes)', 'total store'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes');

g.dashboard.new('Services — Elasticsearch')
+ g.dashboard.withUid('services-elasticsearch')
+ g.dashboard.withDescription('Elasticsearch cluster health, indexing rate, search latency, JVM heap.')
+ g.dashboard.withTags(['services', 'elasticsearch'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  healthStat, nodesStat, indexRateStat, searchLatStat,
  g.panel.row.new('Indexing & Search') + c.pos(0, 4, 24, 1),
  indexTs, searchTs,
  g.panel.row.new('JVM & Disk') + c.pos(0, 12, 24, 1),
  jvmTs, diskTs,
])
