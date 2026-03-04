local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Queries ───────────────────────────────────────────────────────────────────

local cpuUsagePct =
  '(100 - avg(rate(node_cpu_seconds_total{mode="idle",host="heater"}[5m])) * 100) or vector(0)';

local memUsedPct =
  '((1 - node_memory_MemAvailable_bytes{host="heater"} / node_memory_MemTotal_bytes{host="heater"}) * 100) or vector(0)';

local diskRootPct =
  '((1 - node_filesystem_avail_bytes{host="heater",mountpoint="/"} / node_filesystem_size_bytes{host="heater",mountpoint="/"}) * 100) or vector(0)';

local load1 =
  'node_load1{host="heater"} or vector(0)';

// ── Stat panels (row y=0) ─────────────────────────────────────────────────────

local cpuStat =
  g.panel.stat.new('CPU Usage')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(cpuUsagePct)])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local memStat =
  g.panel.stat.new('Memory Used')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(memUsedPct)])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local diskStat =
  g.panel.stat.new('Root Disk Used')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(diskRootPct)])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local loadStat =
  g.panel.stat.new('Load Avg (1m)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(load1)])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Time-series panels (rows y=5..20) ─────────────────────────────────────────

local cpuTs =
  g.panel.timeSeries.new('CPU Usage by Mode')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(node_cpu_seconds_total{mode!="idle",host="heater"}[5m]) * 100', '{{cpu}} {{mode}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withGradientMode('opacity')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local memTs =
  g.panel.timeSeries.new('Memory Breakdown')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('node_memory_MemTotal_bytes{host="heater"}', 'Total'),
    c.vmQ('node_memory_MemTotal_bytes{host="heater"} - node_memory_MemAvailable_bytes{host="heater"}', 'Used'),
    c.vmQ('node_memory_Buffers_bytes{host="heater"}', 'Buffers'),
    c.vmQ('node_memory_Cached_bytes{host="heater"}', 'Cached'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local diskIoTs =
  g.panel.timeSeries.new('Disk I/O')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(node_disk_read_bytes_total{host="heater"}[5m])', 'Read {{device}}'),
    c.vmQ('rate(node_disk_written_bytes_total{host="heater"}[5m])', 'Write {{device}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local netIoTs =
  g.panel.timeSeries.new('Network I/O')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(node_network_receive_bytes_total{host="heater",device!~"lo|veth.*|docker.*|br.*"}[5m])', 'RX {{device}}'),
    c.vmQ('rate(node_network_transmit_bytes_total{host="heater",device!~"lo|veth.*|docker.*|br.*"}[5m])', 'TX {{device}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Logs panel (y=21) ─────────────────────────────────────────────────────────

local logsPanel =
  g.panel.logs.new('System Logs')
  + c.logPos(21)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service=~"(kernel|systemd|NetworkManager|sudo|sshd)"}'),
  ])
  + g.panel.logs.options.withDedupStrategy('none')
  + g.panel.logs.options.withShowLabels(false)
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Heater — System')
+ g.dashboard.withUid('heater-system')
+ g.dashboard.withDescription('CPU, memory, disk I/O, network and system logs for the heater machine.')
+ g.dashboard.withTags(['heater', 'system'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Stats') + c.pos(0, 0, 24, 1),
  cpuStat, memStat, diskStat, loadStat,
  g.panel.row.new('Metrics') + c.pos(0, 4, 24, 1),
  cpuTs, memTs, diskIoTs, netIoTs,
  g.panel.row.new('Logs') + c.pos(0, 20, 24, 1),
  logsPanel,
])
