local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// process-exporter metric names (process_exporter project):
// namedprocess_namegroup_cpu_seconds_total{groupname, mode}
// namedprocess_namegroup_memory_bytes{groupname, memtype}
// namedprocess_namegroup_num_procs{groupname}
// namedprocess_namegroup_num_threads{groupname}
// namedprocess_namegroup_read_bytes_total{groupname}
// namedprocess_namegroup_write_bytes_total{groupname}

local alertPanel = c.alertCountPanel('heater-processes', col=0);

// 5-stat layout: alert(6) + procs(4) + threads(4) + topCpu(5) + topMem(5) = 24
local totalProcs =
  g.panel.stat.new('Total Processes')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(namedprocess_namegroup_num_procs{host="heater"}) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local totalThreads =
  g.panel.stat.new('Total Threads')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(namedprocess_namegroup_num_threads{host="heater"}) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local topCpuStat =
  g.panel.stat.new('Top CPU Process')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(
      '(topk(1, sum by (groupname) (rate(namedprocess_namegroup_cpu_seconds_total{host="heater"}[5m]))) * 100) or vector(0)',
      '{{groupname}}'
    ),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.options.withColorMode('value');

local topMemStat =
  g.panel.stat.new('Top Memory Process')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(
      'topk(1, sum by (groupname) (namedprocess_namegroup_memory_bytes{host="heater",memtype="resident"})) or vector(0)',
      '{{groupname}}'
    ),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value');

local cpuByProcessTs =
  g.panel.timeSeries.new('CPU by Process (top 10)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (sum by (groupname) (rate(namedprocess_namegroup_cpu_seconds_total{host="heater"}[5m])) or vector(0))) * 100',
      '{{groupname}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local memByProcessTs =
  g.panel.timeSeries.new('RSS Memory by Process (top 10)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (sum by (groupname) (namedprocess_namegroup_memory_bytes{host="heater",memtype="resident"})) or vector(0))',
      '{{groupname}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cpuTable =
  g.panel.table.new('Process CPU % Now')
  + c.pos(0, 13, 12, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(20, (sum by (groupname) (rate(namedprocess_namegroup_cpu_seconds_total{host="heater"}[5m])) or vector(0))) * 100',
      '{{groupname}}'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('percent')
  + g.panel.table.options.withSortBy([{ displayName: 'Value', desc: true }]);

local memTable =
  g.panel.table.new('Process Memory Now')
  + c.pos(12, 13, 12, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(20, (sum by (groupname) (namedprocess_namegroup_memory_bytes{host="heater",memtype="resident"})) or vector(0))',
      '{{groupname}}'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('bytes')
  + g.panel.table.options.withSortBy([{ displayName: 'Value', desc: true }]);

local logsPanel =
  g.panel.logs.new('Process Events (OOM / Segfaults / Kills)')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    // Kernel logs for OOM kills, segfaults and process termination events.
    c.vlogsQ('{host="heater",service="kernel"} | _msg:~"(killed|oom|OOM|segfault|segmentation|out of memory|Killed process|oom_kill)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('processes', [
  { symptom: 'Process Resource Spike', runbook: 'processes/resource-leak', check: 'Check Top CPU/Memory tables and review trend panels' },
  { symptom: 'Process Count High', runbook: 'processes/fork-bomb', check: 'Monitor Total Processes stat and review historical data' },
  { symptom: 'OOM Killer Active', runbook: 'processes/oom-response', check: 'Check Process Events logs for killed processes' },
  { symptom: 'Zombie Processes', runbook: 'processes/zombie-cleanup', check: 'Review process logs for segfaults or unreaped children' },
], y=35);

g.dashboard.new('Heater — Processes')
+ g.dashboard.withUid('heater-processes')
+ g.dashboard.withDescription('Per-process CPU, memory, threads and process logs for the heater machine.')
+ g.dashboard.withTags(['heater', 'processes', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, totalProcs, totalThreads, topCpuStat, topMemStat,
  g.panel.row.new('⚡ Top Processes') + c.pos(0, 6, 24, 1),
  cpuByProcessTs, memByProcessTs,
  cpuTable, memTable,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  troubleGuide,
])
