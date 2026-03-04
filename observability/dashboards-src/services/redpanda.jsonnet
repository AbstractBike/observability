local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// 5-stat layout: up(4w) + uptime(5w) + bytes-in(5w) + bytes-out(5w) + partitions(5w) = 24
local upStat =
  g.panel.stat.new('Redpanda Up')
  + c.pos(0, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('up{job="redpanda"}')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('value_and_name');

local uptimeStat =
  g.panel.stat.new('Broker Uptime')
  + c.pos(4, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('vectorized_application_uptime or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value');

local throughputInStat =
  g.panel.stat.new('Bytes In/sec')
  + c.pos(9, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_produced_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value');

local throughputOutStat =
  g.panel.stat.new('Bytes Out/sec')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_fetched_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value');

local partitionStat =
  g.panel.stat.new('Partitions')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by(topic, partition) (vectorized_cluster_partition_leader)) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

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

local logsPanel = c.serviceLogsPanel('Redpanda Logs', 'redpanda');

g.dashboard.new('Services — Redpanda')
+ g.dashboard.withUid('services-redpanda')
+ g.dashboard.withDescription('Redpanda broker throughput, consumer lag, partition health.')
+ g.dashboard.withTags(['services', 'redpanda'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  upStat, uptimeStat, throughputInStat, throughputOutStat, partitionStat,
  g.panel.row.new('📤 Throughput & Lag') + c.pos(0, 4, 24, 1),
  throughputTs, lagTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 12, 24, 1),
  logsPanel,
])
