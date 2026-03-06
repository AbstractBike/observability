local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// prometheus-jmx-exporter metric names:
// jvm_memory_used_bytes{area, pool}
// jvm_memory_committed_bytes{area, pool}
// jvm_memory_max_bytes{area, pool}
// jvm_gc_collection_seconds_count{gc}
// jvm_gc_collection_seconds_sum{gc}
// jvm_threads_current, jvm_threads_daemon
// jvm_classes_loaded
// process_cpu_seconds_total

local alertPanel = c.alertCountPanel('heater-jvm', col=0);

// 5-stat layout: alert(6) + heapPct(4) + heapBytes(4) + gc(5) + threads(5) = 24
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

local logsPanel =
  g.panel.logs.new('IntelliJ / JVM Logs')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    // Filter to kernel and claude-code logs that mention JVM/Java/exceptions.
    c.vlogsQ('{host="heater"} | _msg:~"(?i)(exception|error|jvm|java|intellij)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('jvm', [
  { symptom: 'High Heap Usage', runbook: 'jvm/memory-leak', check: 'Check Heap Used % gauge and review memory trend panel' },
  { symptom: 'GC Pauses', runbook: 'jvm/gc-tuning', check: 'Monitor GC Collections/min stat and GC Pause Time trends' },
  { symptom: 'Thread Leaks', runbook: 'jvm/thread-exhaustion', check: 'Review Live Threads stat and Threads panel for deadlocks' },
  { symptom: 'OutOfMemoryError', runbook: 'jvm/oom-recovery', check: 'Check Heap Max boundary and review exception logs' },
], y=33);

g.dashboard.new('Heater — JVM / IntelliJ')
+ g.dashboard.withUid('heater-jvm')
+ g.dashboard.withDescription('JVM heap, GC pauses, threads via JMX exporter (IntelliJ IDEA).')
+ g.dashboard.withTags(['heater', 'jvm', 'intellij', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, heapUsedPct, heapUsedBytes, gcRate, threadCount,
  g.panel.row.new('💾 Memory') + c.pos(0, 4, 24, 1),
  heapTs, nonHeapTs,
  g.panel.row.new('♻️ GC & Threads') + c.pos(0, 12, 24, 1),
  gcPauseTs, threadsTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 32, 24, 1),
  troubleGuide,
])
