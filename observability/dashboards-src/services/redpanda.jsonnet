local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local uptimeStat =
  g.panel.stat.new('Redpanda Uptime')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('vectorized_application_uptime'),
  ])
  + g.panel.stat.standardOptions.withUnit('s');

local throughputInStat =
  g.panel.stat.new('Bytes In/sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_produced_total[5m]))'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps');

local throughputOutStat =
  g.panel.stat.new('Bytes Out/sec')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_fetched_total[5m]))'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps');

local partitionStat =
  g.panel.stat.new('Partitions')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by(topic, partition) (vectorized_cluster_partition_leader))'),
  ]);

local throughputTs =
  g.panel.timeSeries.new('Throughput')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_produced_total[5m]))', 'produce'),
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_fetched_total[5m]))', 'fetch'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local lagTs =
  g.panel.timeSeries.new('Consumer Group Lag')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by(group, topic) (vectorized_cluster_partition_high_watermark - on(topic, partition) group_right(group) vectorized_kafka_group_offset)', '{{group}}/{{topic}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

g.dashboard.new('Services — Redpanda')
+ g.dashboard.withUid('services-redpanda')
+ g.dashboard.withDescription('Redpanda broker throughput, consumer lag, partition health.')
+ g.dashboard.withTags(['services', 'redpanda'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  uptimeStat, throughputInStat, throughputOutStat, partitionStat,
  g.panel.row.new('Throughput & Lag') + c.pos(0, 4, 24, 1),
  throughputTs, lagTs,
])
