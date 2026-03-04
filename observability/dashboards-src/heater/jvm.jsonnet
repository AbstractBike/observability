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

local heapUsedPct =
  g.panel.gauge.new('Heap Used %')
  + c.statPos(0)
  + g.panel.gauge.queryOptions.withTargets([
    c.vmQ(
      'sum(jvm_memory_used_bytes{host="heater",area="heap"}) / sum(jvm_memory_max_bytes{host="heater",area="heap"}) * 100'
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
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(jvm_memory_used_bytes{host="heater",area="heap"})'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local gcRate =
  g.panel.stat.new('GC Collections/min')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(jvm_gc_collection_seconds_count{host="heater"}[5m]) or vector(0)) * 60'),
  ])
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local threadCount =
  g.panel.stat.new('Live Threads')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_threads_current{host="heater"}'),
  ])
  + g.panel.stat.options.withColorMode('value');

local heapTs =
  g.panel.timeSeries.new('Heap Memory (Used / Committed / Max)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(jvm_memory_used_bytes{host="heater",area="heap"})', 'Used'),
    c.vmQ('sum(jvm_memory_committed_bytes{host="heater",area="heap"})', 'Committed'),
    c.vmQ('sum(jvm_memory_max_bytes{host="heater",area="heap"})', 'Max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local nonHeapTs =
  g.panel.timeSeries.new('Non-Heap Memory (Used / Committed)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(jvm_memory_used_bytes{host="heater",area="nonheap"})', 'Used'),
    c.vmQ('sum(jvm_memory_committed_bytes{host="heater",area="nonheap"})', 'Committed'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gcPauseTs =
  g.panel.timeSeries.new('GC Pause Time (rate)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(jvm_gc_collection_seconds_sum{host="heater"}[5m])', '{{gc}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local threadsTs =
  g.panel.timeSeries.new('Threads')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('jvm_threads_current{host="heater"}', 'Total'),
    c.vmQ('jvm_threads_daemon{host="heater"}', 'Daemon'),
    c.vmQ('jvm_threads_deadlocked{host="heater"}', 'Deadlocked'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel =
  g.panel.logs.new('IntelliJ / JVM Logs')
  + c.logPos(21)
  + g.panel.logs.queryOptions.withTargets([
    // Filter to kernel and claude-code logs that mention JVM/Java/exceptions.
    c.vlogsQ('{host="heater"} | _msg:~"(?i)(exception|error|jvm|java|intellij)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

g.dashboard.new('Heater — JVM / IntelliJ')
+ g.dashboard.withUid('heater-jvm')
+ g.dashboard.withDescription('JVM heap, GC pauses, threads via JMX exporter (IntelliJ IDEA).')
+ g.dashboard.withTags(['heater', 'jvm', 'intellij'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Stats') + c.pos(0, 0, 24, 1),
  heapUsedPct, heapUsedBytes, gcRate, threadCount,
  g.panel.row.new('Memory') + c.pos(0, 4, 24, 1),
  heapTs, nonHeapTs,
  g.panel.row.new('GC & Threads') + c.pos(0, 12, 24, 1),
  gcPauseTs, threadsTs,
  g.panel.row.new('Logs') + c.pos(0, 20, 24, 1),
  logsPanel,
])
