local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Homelab VM system metrics — sourced from Vector host_metrics source.
// Metric prefix: host_* (not node_* — homelab uses Vector, not node_exporter).
// Labels always include host="homelab".

// ── Stat panels (y=1) ────────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('homelab', col=0);

// 5-stat layout: alert(6) + cpu(4) + mem(4) + disk(5) + load(5) = 24
local cpuStat =
  g.panel.stat.new('CPU Usage')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(100 - avg(rate(host_cpu_seconds_total{mode="idle",host="homelab"}[5m])) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local memStat =
  g.panel.stat.new('Memory Used')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((1 - host_memory_available_bytes{host="homelab"} / (host_memory_free_bytes{host="homelab"} + host_memory_available_bytes{host="homelab"} + host_memory_active_bytes{host="homelab"} + host_memory_buffers_bytes{host="homelab"} + host_memory_cached_bytes{host="homelab"})) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local diskStat =
  g.panel.stat.new('Root Disk Used')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(host_filesystem_used_ratio{host="homelab",mountpoint="/"} * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local loadStat =
  g.panel.stat.new('Load Avg (1m)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('host_load1{host="homelab"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Time series (y=5) ────────────────────────────────────────────────────────

local cpuTs =
  g.panel.timeSeries.new('CPU Usage by Mode')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'sum by (mode) (rate(host_cpu_seconds_total{mode!="idle",host="homelab"}[5m])) * 100',
      '{{mode}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local memTs =
  g.panel.timeSeries.new('Memory Breakdown')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('host_memory_active_bytes{host="homelab"}', 'active'),
    c.vmQ('host_memory_buffers_bytes{host="homelab"}', 'buffers'),
    c.vmQ('host_memory_cached_bytes{host="homelab"}', 'cached'),
    c.vmQ('host_memory_free_bytes{host="homelab"}', 'free'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local diskIoTs =
  g.panel.timeSeries.new('Disk I/O')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(host_disk_read_bytes_total{host="homelab"}[5m])', 'read {{device}}'),
    c.vmQ('rate(host_disk_written_bytes_total{host="homelab"}[5m])', 'write {{device}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local netIoTs =
  g.panel.timeSeries.new('Network I/O')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(host_network_receive_bytes_total{host="homelab",interface!~"lo|veth.*|docker.*|br.*"}[5m])',
      'RX {{interface}}'
    ),
    c.vmQ(
      'rate(host_network_transmit_bytes_total{host="homelab",interface!~"lo|veth.*|docker.*|br.*"}[5m])',
      'TX {{interface}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Logs ─────────────────────────────────────────────────────────────────────

local logsPanel =
  g.panel.logs.new('System Logs')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"(kernel|systemd|NetworkManager|sshd|sudo)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard ─────────────────────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('homelab', [
  { symptom: 'High CPU Usage', runbook: 'homelab/high-cpu', check: 'Monitor "CPU Usage by Mode" graph' },
  { symptom: 'Memory Pressure', runbook: 'homelab/memory', check: 'Check "Memory Breakdown" and "Memory Used" stat' },
  { symptom: 'Disk I/O Bottleneck', runbook: 'homelab/disk-io', check: 'Look at "Disk I/O" chart' },
  { symptom: 'Network Issues', runbook: 'homelab/networking', check: 'Monitor "Network I/O" graph' },
], y=33);

g.dashboard.new('Services — Homelab System')
+ g.dashboard.withUid('services-homelab-system')
+ g.dashboard.withDescription('Homelab VM host system metrics: CPU, memory, disk I/O, network (via Vector host_metrics).')
+ g.dashboard.withTags(['services', 'homelab', 'system', 'host', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, cpuStat, memStat, diskStat, loadStat,
  g.panel.row.new('⚡ Performance') + c.pos(0, 4, 24, 1),
  cpuTs, memTs,
  g.panel.row.new('🏗️ Storage & Networking') + c.pos(0, 12, 24, 1),
  diskIoTs, netIoTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 32, 24, 1),
  troubleGuide,
])
