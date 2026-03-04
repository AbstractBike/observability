local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// OAP Prometheus endpoint (:1234) exports JVM/process metrics only.
// oap_trace_in_latency_* are stored in BanyanDB, not in the Prometheus endpoint.

local uptimeStat =
  g.panel.stat.new('OAP Uptime')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('time() - process_start_time_seconds{job="skywalking-oap"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('s');

local threadsStat =
  g.panel.stat.new('OAP Threads')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_threads_current{job="skywalking-oap"}'),
  ]);

local heapStat =
  g.panel.stat.new('Heap Used (MB)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_memory_bytes_used{job="skywalking-oap",area="heap"} / 1024 / 1024'),
  ])
  + g.panel.stat.standardOptions.withUnit('none');

local cpuStat =
  g.panel.stat.new('CPU Usage (%)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(process_cpu_seconds_total{job="skywalking-oap"}[5m]) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent');

local heapTs =
  g.panel.timeSeries.new('JVM Heap (MB)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('jvm_memory_bytes_used{job="skywalking-oap",area="heap"} / 1024 / 1024', 'used'),
    c.vmQ('jvm_memory_bytes_max{job="skywalking-oap",area="heap"} / 1024 / 1024', 'max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('none')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gcTs =
  g.panel.timeSeries.new('GC Time (ms/s)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(jvm_gc_collection_seconds_sum{job="skywalking-oap"}[5m]) * 1000', '{{gc}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

g.dashboard.new('Observability — SkyWalking')
+ g.dashboard.withUid('observability-skywalking')
+ g.dashboard.withDescription('SkyWalking OAP JVM health: uptime, heap, GC, CPU.')
+ g.dashboard.withTags(['observability', 'skywalking', 'tracing'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  uptimeStat, threadsStat, heapStat, cpuStat,
  g.panel.row.new('JVM') + c.pos(0, 4, 24, 1),
  heapTs, gcTs,
])
