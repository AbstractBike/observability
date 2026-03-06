// Dashboard: Services — Redpanda
// Question:  "Is Redpanda healthy? Throughput, consumer lag, partition health."
//
// Data: vectorized_* from Redpanda Prometheus endpoint (job="redpanda")
// Confirmed metrics: vectorized_application_uptime, vectorized_cluster_partition_bytes_produced_total,
//   vectorized_cluster_partition_bytes_fetched_total, vectorized_cluster_partition_high_watermark,
//   vectorized_cluster_partition_leader, vectorized_kafka_group_offset, up{job="redpanda"}

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local alertPanel = c.alertCountPanel('redpanda', col=0);

// ── Row 0: Key Stats ──────────────────────────────────────────────────────────
// 5-stat layout: alert(6) + up(4) + uptime(4) + bytes-in(5) + bytes-out(5) = 24

local upStat =
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

local uptimeStat =
  g.panel.stat.new('Broker Uptime')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('vectorized_application_uptime or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value');

local throughputInStat =
  g.panel.stat.new('Bytes In/sec')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_produced_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local throughputOutStat =
  g.panel.stat.new('Bytes Out/sec')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_fetched_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Row 1: Throughput & Consumer Lag ──────────────────────────────────────────

local throughputTs =
  g.panel.timeSeries.new('Throughput')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_produced_total[5m])) or vector(0)', 'produce'),
    c.vmQ('sum(rate(vectorized_cluster_partition_bytes_fetched_total[5m])) or vector(0)', 'fetch'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local lagTs =
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

// ── Row 2: Logs ───────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Redpanda Logs', 'redpanda', y=14);

// ── Row 3: Troubleshooting ────────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('redpanda', [
  { symptom: 'Broker Down', runbook: 'redpanda/broker-down', check: '"Redpanda Up" = 0 — check service status and logs' },
  { symptom: 'High Consumer Lag', runbook: 'redpanda/consumer-lag', check: '"Consumer Group Lag" chart — lag means consumers are behind producers' },
  { symptom: 'Low Throughput', runbook: 'redpanda/throughput', check: '"Throughput" chart dropping — check producers, network, or disk' },
  { symptom: 'Produce Errors', runbook: 'redpanda/produce-errors', check: 'Check logs for kafka protocol errors' },
  { symptom: 'Partition Offline', runbook: 'redpanda/partitions', check: 'Check "Redpanda Up" and broker logs for partition election errors' },
], y=25);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Services — Redpanda')
+ g.dashboard.withUid('services-redpanda')
+ g.dashboard.withDescription('Redpanda broker throughput, consumer lag, partition health, and alerts.')
+ g.dashboard.withTags(['services', 'redpanda', 'kafka', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, upStat, uptimeStat, throughputInStat, throughputOutStat,

  g.panel.row.new('📤 Throughput & Lag') + c.pos(0, 4, 24, 1),
  throughputTs, lagTs,

  g.panel.row.new('📝 Logs') + c.pos(0, 13, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 24, 24, 1),
  troubleGuide,
])
