local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ═══════════════════════════════════════════════════════════════════════════
// heater/system.jsonnet panels
// ═══════════════════════════════════════════════════════════════════════════

local sysAlertPanel = c.alertCountPanel('heater', col=0);

local sysCpuUsagePct =
  '(100 - avg(rate(node_cpu_seconds_total{mode="idle",host="heater"}[5m])) * 100) or vector(0)';

local sysMemUsedPct =
  '((1 - node_memory_MemAvailable_bytes{host="heater"} / node_memory_MemTotal_bytes{host="heater"}) * 100) or vector(0)';

local sysDiskRootPct =
  '((1 - node_filesystem_avail_bytes{host="heater",mountpoint="/"} / node_filesystem_size_bytes{host="heater",mountpoint="/"}) * 100) or vector(0)';

local sysLoad1 =
  'node_load1{host="heater"} or vector(0)';

local sysCpuStat =
  g.panel.stat.new('CPU Usage')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(sysCpuUsagePct)])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local sysMemStat =
  g.panel.stat.new('Memory Used')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(sysMemUsedPct)])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local sysDiskStat =
  g.panel.stat.new('Root Disk Used')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(sysDiskRootPct)])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local sysLoadStat =
  g.panel.stat.new('Load Avg (1m)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(sysLoad1)])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local sysCpuTs =
  g.panel.timeSeries.new('CPU Usage by Mode')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(rate(node_cpu_seconds_total{mode!="idle",host="heater"}[5m]) or vector(0)) * 100', '{{cpu}} {{mode}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withGradientMode('opacity')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sysMemTs =
  g.panel.timeSeries.new('Memory Breakdown')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(node_memory_MemTotal_bytes{host="heater"}) or vector(0)', 'Total'),
    c.vmQ('((node_memory_MemTotal_bytes{host="heater"} - node_memory_MemAvailable_bytes{host="heater"}) or vector(0))', 'Used'),
    c.vmQ('(node_memory_Buffers_bytes{host="heater"}) or vector(0)', 'Buffers'),
    c.vmQ('(node_memory_Cached_bytes{host="heater"}) or vector(0)', 'Cached'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sysDiskIoTs =
  g.panel.timeSeries.new('Disk I/O')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(rate(node_disk_read_bytes_total{host="heater"}[5m]) or vector(0))', 'Read {{device}}'),
    c.vmQ('(rate(node_disk_written_bytes_total{host="heater"}[5m]) or vector(0))', 'Write {{device}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sysNetIoTs =
  g.panel.timeSeries.new('Network I/O')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(rate(node_network_receive_bytes_total{host="heater",device!~"lo|veth.*|docker.*|br.*"}[5m]) or vector(0))', 'RX {{device}}'),
    c.vmQ('(rate(node_network_transmit_bytes_total{host="heater",device!~"lo|veth.*|docker.*|br.*"}[5m]) or vector(0))', 'TX {{device}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sysLogsPanel =
  g.panel.logs.new('System Logs')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service=~"(kernel|systemd|NetworkManager|sudo|sshd)"}'),
  ])
  + g.panel.logs.options.withDedupStrategy('none')
  + g.panel.logs.options.withShowLabels(false)
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local sysTroubleGuide = c.serviceTroubleshootingGuide('heater', [
  { symptom: 'High CPU Usage', runbook: 'heater/cpu-spike', check: 'Check CPU Usage stat and Performance trends panel' },
  { symptom: 'Memory Pressure', runbook: 'heater/memory-pressure', check: 'Monitor Memory Used stat and swap usage' },
  { symptom: 'Disk Space Low', runbook: 'heater/disk-cleanup', check: 'Review Root Disk Used and disk I/O trends' },
  { symptom: 'System Overload', runbook: 'heater/load-average', check: 'Check Load Avg stat and correlate with Process grid' },
], y=35);

// system: max(y+h) = troubleGuide y=35 h=5 → 40
local systemPanels = [
  g.panel.row.new('🖥️ System') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  sysAlertPanel, sysCpuStat, sysMemStat, sysDiskStat, sysLoadStat,
  g.panel.row.new('⚡ Performance') + c.pos(0, 6, 24, 1),
  sysCpuTs, sysMemTs, sysDiskIoTs, sysNetIoTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  sysLogsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  sysTroubleGuide,
];
local systemHeight = 40;

// ═══════════════════════════════════════════════════════════════════════════
// heater/gpu.jsonnet panels
// ═══════════════════════════════════════════════════════════════════════════

local gpuAlertPanel = c.alertCountPanel('heater-gpu', col=0);

local gpuUtil =
  g.panel.gauge.new('GPU Utilization')
  + c.pos(6, 1, 4, 3)
  + g.panel.gauge.queryOptions.withTargets([
    c.vmQ('(nvidia_smi_utilization_gpu_ratio{host="heater"} * 100) or vector(0)', '{{name}}'),
  ])
  + g.panel.gauge.standardOptions.withUnit('percent')
  + g.panel.gauge.standardOptions.withMax(100)
  + g.panel.gauge.standardOptions.withMin(0)
  + g.panel.gauge.standardOptions.thresholds.withMode('absolute')
  + g.panel.gauge.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 70 },
    { color: 'red', value: 90 },
  ]);

local vramUtil =
  g.panel.gauge.new('VRAM Used')
  + c.pos(10, 1, 4, 3)
  + g.panel.gauge.queryOptions.withTargets([
    c.vmQ('(nvidia_smi_memory_used_bytes{host="heater"} / nvidia_smi_memory_total_bytes{host="heater"} * 100) or vector(0)', '{{name}}'),
  ])
  + g.panel.gauge.standardOptions.withUnit('percent')
  + g.panel.gauge.standardOptions.withMax(100)
  + g.panel.gauge.standardOptions.withMin(0)
  + g.panel.gauge.standardOptions.thresholds.withMode('absolute')
  + g.panel.gauge.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 75 },
    { color: 'red', value: 90 },
  ]);

local tempStat =
  g.panel.stat.new('Temperature')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nvidia_smi_temperature_gpu{host="heater"} or vector(0)', '{{name}}'),
  ])
  + g.panel.stat.standardOptions.withUnit('celsius')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 75 },
    { color: 'red', value: 85 },
  ])
  + g.panel.stat.options.withColorMode('background');

local powerStat =
  g.panel.stat.new('Power Draw')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nvidia_smi_power_draw_watts{host="heater"} or vector(0)', '{{name}}'),
  ])
  + g.panel.stat.standardOptions.withUnit('watt')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local gpuUtilTs =
  g.panel.timeSeries.new('GPU & Memory Utilization')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(nvidia_smi_utilization_gpu_ratio{host="heater"} * 100) or vector(0)', 'GPU {{name}}'),
    c.vmQ('(nvidia_smi_utilization_memory_ratio{host="heater"} * 100) or vector(0)', 'Memory {{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vramTs =
  g.panel.timeSeries.new('VRAM Used vs Total')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_memory_used_bytes{host="heater"} or vector(0)', 'Used {{name}}'),
    c.vmQ('nvidia_smi_memory_total_bytes{host="heater"} or vector(0)', 'Total {{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tempTs =
  g.panel.timeSeries.new('Temperature & Fan')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_temperature_gpu{host="heater"} or vector(0)', 'Temp °C {{name}}'),
    c.vmQ('(nvidia_smi_fan_speed_ratio{host="heater"} * 100) or vector(0)', 'Fan % {{name}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local powerTs =
  g.panel.timeSeries.new('Power Draw — History')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_power_draw_watts{host="heater"} or vector(0)', '{{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('watt')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gpuLogsPanel =
  g.panel.logs.new('GPU / CUDA Logs')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="kernel"} | _msg:~"(NVIDIA|nvidia|NVRM|cuda|CUDA|GPU|drm)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local gpuTroubleGuide = c.serviceTroubleshootingGuide('gpu', [
  { symptom: 'GPU Utilization High', runbook: 'gpu/high-utilization', check: 'Monitor GPU Utilization gauge and check active CUDA processes in logs' },
  { symptom: 'VRAM Exhausted', runbook: 'gpu/memory-pressure', check: 'Review VRAM Used gauge and clear GPU memory cache if needed' },
  { symptom: 'Temperature High', runbook: 'gpu/thermal-throttle', check: 'Check Temperature & Fan trend panel and improve cooling' },
  { symptom: 'Power Spike', runbook: 'gpu/power-anomaly', check: 'Review Power Draw trends and adjust workloads' },
], y=35);

// gpu: max(y+h) = troubleGuide y=35 h=5 → 40
local gpuPanels = [
  g.panel.row.new('🎮 GPU') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  gpuAlertPanel, gpuUtil, vramUtil, tempStat, powerStat,
  g.panel.row.new('⚡ Metrics') + c.pos(0, 6, 24, 1),
  gpuUtilTs, vramTs, tempTs, powerTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  gpuLogsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  gpuTroubleGuide,
];
local gpuHeight = 40;

// ═══════════════════════════════════════════════════════════════════════════
// heater/jvm.jsonnet panels
// ═══════════════════════════════════════════════════════════════════════════

local jvmAlertPanel = c.alertCountPanel('heater-jvm', col=0);

local heapUsedPct =
  g.panel.gauge.new('Heap Used %')
  + c.pos(6, 1, 4, 3)
  + g.panel.gauge.queryOptions.withTargets([
    c.vmQ(
      '(sum(jvm_memory_used_bytes{host="heater",area="heap"}) or vector(0)) / (sum(jvm_memory_max_bytes{host="heater",area="heap"}) or vector(0)) * 100'
    ),
  ])
  + g.panel.gauge.standardOptions.withUnit('percent')
  + g.panel.gauge.standardOptions.withMax(100)
  + g.panel.gauge.standardOptions.withMin(0)
  + g.panel.gauge.standardOptions.thresholds.withMode('absolute')
  + g.panel.gauge.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 70 },
    { color: 'red', value: 90 },
  ]);

local heapUsedBytes =
  g.panel.stat.new('Heap Used')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(jvm_memory_used_bytes{host="heater",area="heap"})) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local gcRate =
  g.panel.stat.new('GC Collections/min')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(jvm_gc_collection_seconds_count{host="heater"}[5m]) or vector(0)) * 60'),
  ])
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local threadCount =
  g.panel.stat.new('Live Threads')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(jvm_threads_current{host="heater"}) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local heapTs =
  g.panel.timeSeries.new('Heap Memory (Used / Committed / Max)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(sum(jvm_memory_used_bytes{host="heater",area="heap"})) or vector(0)', 'Used'),
    c.vmQ('(sum(jvm_memory_committed_bytes{host="heater",area="heap"})) or vector(0)', 'Committed'),
    c.vmQ('(sum(jvm_memory_max_bytes{host="heater",area="heap"})) or vector(0)', 'Max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local nonHeapTs =
  g.panel.timeSeries.new('Non-Heap Memory (Used / Committed)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(sum(jvm_memory_used_bytes{host="heater",area="nonheap"})) or vector(0)', 'Used'),
    c.vmQ('(sum(jvm_memory_committed_bytes{host="heater",area="nonheap"})) or vector(0)', 'Committed'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gcPauseTs =
  g.panel.timeSeries.new('GC Pause Time (rate)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(rate(jvm_gc_collection_seconds_sum{host="heater"}[5m]) or vector(0))', '{{gc}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local threadsTs =
  g.panel.timeSeries.new('Threads')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(jvm_threads_current{host="heater"}) or vector(0)', 'Total'),
    c.vmQ('(jvm_threads_daemon{host="heater"}) or vector(0)', 'Daemon'),
    c.vmQ('(jvm_threads_deadlocked{host="heater"}) or vector(0)', 'Deadlocked'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local jvmLogsPanel =
  g.panel.logs.new('IntelliJ / JVM Logs')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater"} | _msg:~"(?i)(exception|error|jvm|java|intellij)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local jvmTroubleGuide = c.serviceTroubleshootingGuide('jvm', [
  { symptom: 'High Heap Usage', runbook: 'jvm/memory-leak', check: 'Check Heap Used % gauge and review memory trend panel' },
  { symptom: 'GC Pauses', runbook: 'jvm/gc-tuning', check: 'Monitor GC Collections/min stat and GC Pause Time trends' },
  { symptom: 'Thread Leaks', runbook: 'jvm/thread-exhaustion', check: 'Review Live Threads stat and Threads panel for deadlocks' },
  { symptom: 'OutOfMemoryError', runbook: 'jvm/oom-recovery', check: 'Check Heap Max boundary and review exception logs' },
], y=35);

// jvm: max(y+h) = troubleGuide y=35 h=5 → 40
local jvmPanels = [
  g.panel.row.new('☕ JVM / IntelliJ') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  jvmAlertPanel, heapUsedPct, heapUsedBytes, gcRate, threadCount,
  g.panel.row.new('💾 Memory') + c.pos(0, 6, 24, 1),
  heapTs, nonHeapTs,
  g.panel.row.new('♻️ GC & Threads') + c.pos(0, 14, 24, 1),
  gcPauseTs, threadsTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  jvmLogsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  jvmTroubleGuide,
];
local jvmHeight = 40;

// ═══════════════════════════════════════════════════════════════════════════
// heater/networking.jsonnet panels
// ═══════════════════════════════════════════════════════════════════════════

local netAlertPanel = c.alertCountPanel('heater-network', col=0);

local netHost = 'host="heater"';
local physIfaces = 'eno1np0|eno2np1';
local vmIfaces = 'br0|macvtap4|macvlan0';

local rxBwStat =
  g.panel.stat.new('LAN RX (eno1)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(node_network_receive_bytes_total{' + netHost + ',device="eno1np0"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local txBwStat =
  g.panel.stat.new('LAN TX (eno1)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(node_network_transmit_bytes_total{' + netHost + ',device="eno1np0"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local dropRateStat =
  g.panel.stat.new('Drop Rate (all ifaces)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(node_network_receive_drop_total{' + netHost + ',device!="lo"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('pps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 10 },
    { color: 'red', value: 100 },
  ])
  + g.panel.stat.options.withColorMode('background');

local physRxTs =
  g.panel.timeSeries.new('Physical Interface — Receive')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(node_network_receive_bytes_total{' + netHost + ',device=~"' + physIfaces + '"}[5m]) or vector(0)',
      '{{device}} rx'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local physTxTs =
  g.panel.timeSeries.new('Physical Interface — Transmit')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(node_network_transmit_bytes_total{' + netHost + ',device=~"' + physIfaces + '"}[5m]) or vector(0)',
      '{{device}} tx'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vmRxTs =
  g.panel.timeSeries.new('VM Bridge — Receive (br0 / macvtap)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(node_network_receive_bytes_total{' + netHost + ',device=~"' + vmIfaces + '"}[5m]) or vector(0)',
      '{{device}} rx'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vmTxTs =
  g.panel.timeSeries.new('VM Bridge — Transmit (br0 / macvtap)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(node_network_transmit_bytes_total{' + netHost + ',device=~"' + vmIfaces + '"}[5m]) or vector(0)',
      '{{device}} tx'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local topIfacesTable =
  g.panel.table.new('Top Interfaces by Bandwidth (5m avg)')
  + c.pos(0, 22, 24, 7)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(10, sum by(device) (rate(node_network_receive_bytes_total{' + netHost + ',device!="lo"}[5m]) or vector(0)))',
      '{{device}}'
    ) + { refId: 'rx' },
    c.vmQ(
      'topk(10, sum by(device) (rate(node_network_transmit_bytes_total{' + netHost + ',device!="lo"}[5m]) or vector(0)))',
      '{{device}}'
    ) + { refId: 'tx' },
  ])
  + g.panel.table.queryOptions.withTransformations([
    {
      id: 'joinByField',
      options: { byField: 'device', mode: 'outer' },
    },
    {
      id: 'organize',
      options: {
        renameByName: { 'Value #rx': 'RX (bytes/s)', 'Value #tx': 'TX (bytes/s)' },
        excludeByName: { Time: true, 'Time 1': true, 'Time 2': true },
      },
    },
  ])
  + {
    fieldConfig+: {
      overrides: [
        {
          matcher: { id: 'byName', options: 'RX (bytes/s)' },
          properties: [{ id: 'unit', value: 'Bps' }],
        },
        {
          matcher: { id: 'byName', options: 'TX (bytes/s)' },
          properties: [{ id: 'unit', value: 'Bps' }],
        },
      ],
    },
  };

local errorsTs =
  g.panel.timeSeries.new('Receive Errors & Drops')
  + c.pos(0, 30, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'sum by(device) (rate(node_network_receive_errs_total{' + netHost + ',device!="lo"}[5m]) or vector(0))',
      '{{device}} errors'
    ),
    c.vmQ(
      'sum by(device) (rate(node_network_receive_drop_total{' + netHost + ',device!="lo"}[5m]) or vector(0))',
      '{{device}} drops'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('pps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local txErrTs =
  g.panel.timeSeries.new('Transmit Errors & Drops')
  + c.pos(12, 30, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'sum by(device) (rate(node_network_transmit_errs_total{' + netHost + ',device!="lo"}[5m]) or vector(0))',
      '{{device}} errors'
    ),
    c.vmQ(
      'sum by(device) (rate(node_network_transmit_drop_total{' + netHost + ',device!="lo"}[5m]) or vector(0))',
      '{{device}} drops'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('pps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// networking: max(y+h) = txErrTs y=30 h=8 → 38
local networkingPanels = [
  g.panel.row.new('🌐 Networking') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  netAlertPanel, rxBwStat, txBwStat, dropRateStat,
  g.panel.row.new('🔌 Physical Interfaces') + c.pos(0, 6, 24, 1),
  physRxTs, physTxTs,
  g.panel.row.new('🖥️ VM Bridges') + c.pos(0, 14, 24, 1),
  vmRxTs, vmTxTs,
  g.panel.row.new('📋 Interface Summary') + c.pos(0, 23, 24, 1),
  topIfacesTable,
  g.panel.row.new('⚠️ Errors & Drops') + c.pos(0, 31, 24, 1),
  errorsTs, txErrTs,
];
local networkingHeight = 38;

// ═══════════════════════════════════════════════════════════════════════════
// heater/processes.jsonnet panels
// ═══════════════════════════════════════════════════════════════════════════

local procAlertPanel = c.alertCountPanel('heater-processes', col=0);

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

local procLogsPanel =
  g.panel.logs.new('Process Events (OOM / Segfaults / Kills)')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="kernel"} | _msg:~"(killed|oom|OOM|segfault|segmentation|out of memory|Killed process|oom_kill)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local procTroubleGuide = c.serviceTroubleshootingGuide('processes', [
  { symptom: 'Process Resource Spike', runbook: 'processes/resource-leak', check: 'Check Top CPU/Memory tables and review trend panels' },
  { symptom: 'Process Count High', runbook: 'processes/fork-bomb', check: 'Monitor Total Processes stat and review historical data' },
  { symptom: 'OOM Killer Active', runbook: 'processes/oom-response', check: 'Check Process Events logs for killed processes' },
  { symptom: 'Zombie Processes', runbook: 'processes/zombie-cleanup', check: 'Review process logs for segfaults or unreaped children' },
], y=35);

// processes: max(y+h) = troubleGuide y=35 h=5 → 40
local processesPanels = [
  g.panel.row.new('⚙️ Processes') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  procAlertPanel, totalProcs, totalThreads, topCpuStat, topMemStat,
  g.panel.row.new('⚡ Top Processes') + c.pos(0, 6, 24, 1),
  cpuByProcessTs, memByProcessTs,
  cpuTable, memTable,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  procLogsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  procTroubleGuide,
];
local processesHeight = 40;

// ═══════════════════════════════════════════════════════════════════════════
// heater/home.jsonnet panels
// ═══════════════════════════════════════════════════════════════════════════

local homeSysColor   = '#0891b2';
local homeGpuColor   = '#7c3aed';
local homeJvmColor   = '#059669';
local homeAiColor    = '#d946ef';
local homeProcColor  = '#d97706';

local homeHeaderHtml = |||
  <style>
    #heater-header {
      display:flex; align-items:center; justify-content:space-between;
      padding: 12px 20px;
      background: linear-gradient(135deg, #0891b2 0%, #0e7490 100%);
      border-radius: 10px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      box-sizing: border-box; height: 100%%; color: #fff;
    }
    #heater-header .brand { display:flex; align-items:center; gap:12px; }
    #heater-header .logo {
      width:36px; height:36px; flex-shrink:0;
      background: rgba(255,255,255,0.2); backdrop-filter: blur(8px);
      border-radius:8px; display:flex; align-items:center; justify-content:center;
      font-size:18px; border: 1px solid rgba(255,255,255,0.25);
    }
    #heater-header .name { font-size:16px; font-weight:700; letter-spacing:-0.025em; }
    #heater-header .tagline {
      font-size:10px; color:rgba(255,255,255,0.7); letter-spacing:0.12em;
      text-transform:uppercase; margin-top:1px;
      font-family: "SFMono-Regular", Consolas, monospace;
    }
  </style>
  <div id="heater-header">
    <div class="brand">
      <div class="logo">H</div>
      <div>
        <div class="name">Heater — Developer Workstation</div>
        <div class="tagline">system / gpu / jvm / claude code / processes</div>
      </div>
    </div>
  </div>
|||;

local homeHeaderPanel =
  g.panel.text.new('Heater')
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(homeHeaderHtml)
  + c.pos(0, 0, 24, 2);

local homeCpuStat =
  g.panel.stat.new('CPU')
  + c.pos(0, 2, 5, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(100 - avg(rate(node_cpu_seconds_total{mode="idle",host="heater"}[5m])) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local homeMemStat =
  g.panel.stat.new('Memory')
  + c.pos(5, 2, 5, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((1 - node_memory_MemAvailable_bytes{host="heater"} / node_memory_MemTotal_bytes{host="heater"}) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local homeGpuStat =
  g.panel.stat.new('GPU')
  + c.pos(10, 2, 5, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(nvidia_smi_utilization_gpu_ratio{host="heater"} * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local homeHeapStat =
  g.panel.stat.new('JVM Heap')
  + c.pos(15, 2, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(jvm_memory_used_bytes{host="heater",area="heap"}) / sum(jvm_memory_max_bytes{host="heater",area="heap"}) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local homeClaudeCostStat =
  g.panel.stat.new('Claude $')
  + c.pos(19, 2, 5, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_prompt_session_cost_usd{host="heater"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 5 },
    { color: 'red', value: 20 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local homeCardHtml(icon, title, subtitle, url, accent) =
  |||
    <a href="%(url)s" target="_self"
      style="
        display:flex; align-items:center; gap:14px;
        padding:16px 18px; height:100%%; width:100%%;
        background:#ffffff;
        border:1px solid #e4e4eb;
        border-left:4px solid %(accent)s;
        border-radius:8px;
        text-decoration:none; color:inherit;
        font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        cursor:pointer; box-sizing:border-box;
        transition: box-shadow 0.18s ease, transform 0.18s ease;
        overflow:hidden;
      "
      onmouseover="this.style.boxShadow='0 4px 16px rgba(0,0,0,0.08)';this.style.transform='translateY(-1px)';"
      onmouseout="this.style.boxShadow='none';this.style.transform='translateY(0)';"
    >
      <div style="
        width:40px; height:40px; flex-shrink:0;
        background:%(accent)s10;
        border-radius:10px;
        display:flex; align-items:center; justify-content:center;
        font-size:20px; line-height:1;
      ">%(icon)s</div>
      <div style="flex:1; min-width:0;">
        <div style="font-size:14px; font-weight:700; color:#111827; letter-spacing:-0.01em;">%(title)s</div>
        <div style="
          font-family:'SFMono-Regular',Consolas,monospace;
          font-size:10px; color:#9ca3af; margin-top:2px; letter-spacing:0.02em;
        ">%(subtitle)s</div>
      </div>
    </a>
  ||| % { url: url, icon: icon, title: title, subtitle: subtitle, accent: accent };

local homeNavCard(name, icon, title, subtitle, uid, accent, pos) =
  g.panel.text.new(name)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(homeCardHtml(icon, title, subtitle, '/d/' + uid, accent))
  + pos;

local homeSystemCard  = homeNavCard('System',    '🖥',  'System',     'cpu / memory / disk / network', 'heater-system',    homeSysColor,  c.pos(0,  7, 8, 4));
local homeGpuCard     = homeNavCard('GPU',       '🎮',  'GPU',        'utilization / vram / temp',     'heater-gpu',       homeGpuColor,  c.pos(8,  7, 8, 4));
local homeJvmCard     = homeNavCard('JVM',       '☕',  'JVM',        'heap / gc / threads',           'heater-jvm',       homeJvmColor,  c.pos(16, 7, 8, 4));
local homeClaudeCard  = homeNavCard('Claude',    '🤖', 'Claude Code', 'tokens / cost / mcp traces',   'heater-claude-code', homeAiColor, c.pos(0,  11, 12, 4));
local homeProcessCard = homeNavCard('Processes', '⚙',   'Processes',  'top cpu / top mem / threads',   'heater-processes', homeProcColor, c.pos(12, 11, 12, 4));

// home: max(y+h) = homeClaudeCard/homeProcessCard y=11 h=4 → 15
local homePanels = [
  homeHeaderPanel,
  c.externalLinksPanel(y=0, x=22),
  g.panel.row.new('Health') + c.pos(0, 2, 24, 0),
  homeCpuStat, homeMemStat, homeGpuStat, homeHeapStat, homeClaudeCostStat,
  g.panel.row.new('Dashboards') + c.pos(0, 6, 24, 1),
  homeSystemCard, homeGpuCard, homeJvmCard, homeClaudeCard, homeProcessCard,
];
local homeHeight = 15;

// ═══════════════════════════════════════════════════════════════════════════
// services/homelab-system.jsonnet panels
// ═══════════════════════════════════════════════════════════════════════════

local homelabAlertPanel = c.alertCountPanel('homelab', col=0);

local homelabCpuStat =
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

local homelabMemStat =
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

local homelabDiskStat =
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

local homelabLoadStat =
  g.panel.stat.new('Load Avg (1m)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('host_load1{host="homelab"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local homelabCpuTs =
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

local homelabMemTs =
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

local homelabDiskIoTs =
  g.panel.timeSeries.new('Disk I/O')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(host_disk_read_bytes_total{host="homelab"}[5m])', 'read {{device}}'),
    c.vmQ('rate(host_disk_written_bytes_total{host="homelab"}[5m])', 'write {{device}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local homelabNetIoTs =
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

local homelabLogsPanel =
  g.panel.logs.new('System Logs')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"(kernel|systemd|NetworkManager|sshd|sudo)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local homelabTroubleGuide = c.serviceTroubleshootingGuide('homelab', [
  { symptom: 'High CPU Usage', runbook: 'homelab/high-cpu', check: 'Monitor "CPU Usage by Mode" graph' },
  { symptom: 'Memory Pressure', runbook: 'homelab/memory', check: 'Check "Memory Breakdown" and "Memory Used" stat' },
  { symptom: 'Disk I/O Bottleneck', runbook: 'homelab/disk-io', check: 'Look at "Disk I/O" chart' },
  { symptom: 'Network Issues', runbook: 'homelab/networking', check: 'Monitor "Network I/O" graph' },
], y=35);

// homelab-system: max(y+h) = troubleGuide y=35 h=5 → 40
local homelabSystemPanels = [
  g.panel.row.new('🏠 Homelab VM System') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  homelabAlertPanel, homelabCpuStat, homelabMemStat, homelabDiskStat, homelabLoadStat,
  g.panel.row.new('⚡ Performance') + c.pos(0, 6, 24, 1),
  homelabCpuTs, homelabMemTs,
  g.panel.row.new('🏗️ Storage & Networking') + c.pos(0, 14, 24, 1),
  homelabDiskIoTs, homelabNetIoTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  homelabLogsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  homelabTroubleGuide,
];

// ═══════════════════════════════════════════════════════════════════════════
// Dashboard assembly
// ═══════════════════════════════════════════════════════════════════════════

g.dashboard.new('Infrastructure')
+ g.dashboard.withUid('home-infrastructure')
+ g.dashboard.withDescription('Heater host and homelab VM system metrics — CPU, GPU, JVM, network, processes.')
+ g.dashboard.withTags(['infrastructure', 'heater', 'homelab'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.vmAdhocVar, c.vlogsAdhocVar])
+ g.dashboard.withPanels(
    c.withYOffset(systemPanels, 0)
    + c.withYOffset(gpuPanels, systemHeight)
    + c.withYOffset(jvmPanels, systemHeight + gpuHeight)
    + c.withYOffset(networkingPanels, systemHeight + gpuHeight + jvmHeight)
    + c.withYOffset(processesPanels, systemHeight + gpuHeight + jvmHeight + networkingHeight)
    + c.withYOffset(homePanels, systemHeight + gpuHeight + jvmHeight + networkingHeight + processesHeight)
    + c.withYOffset(homelabSystemPanels, systemHeight + gpuHeight + jvmHeight + networkingHeight + processesHeight + homeHeight)
  )
