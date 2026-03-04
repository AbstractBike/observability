local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// OAP Prometheus endpoint (:1234) exports JVM/process metrics only.
// oap_trace_in_latency_* are stored in BanyanDB, not in the Prometheus endpoint.

local uptimeStat =
  g.panel.stat.new('OAP Uptime')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('time() - process_start_time_seconds{job="skywalking-oap"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value');

local threadsStat =
  g.panel.stat.new('OAP Threads')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_threads_current{job="skywalking-oap"} or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local heapStat =
  g.panel.stat.new('Heap Used')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_memory_bytes_used{job="skywalking-oap",area="heap"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value');

local cpuStat =
  g.panel.stat.new('CPU Usage (%)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(rate(process_cpu_seconds_total{job="skywalking-oap"}[5m]) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.options.withColorMode('value');

local heapTs =
  g.panel.timeSeries.new('JVM Heap')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('jvm_memory_bytes_used{job="skywalking-oap",area="heap"}', 'used'),
    c.vmQ('jvm_memory_bytes_max{job="skywalking-oap",area="heap"}', 'max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gcTs =
  g.panel.timeSeries.new('GC Time (ms/s)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(jvm_gc_collection_seconds_sum{job="skywalking-oap"}[5m]) * 1000', '{{gc}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local swUiLink =
  g.panel.text.new('SkyWalking UI')
  + c.pos(0, 13, 24, 3)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <div style="display:flex;align-items:center;justify-content:center;height:100%;gap:24px;font-family:-apple-system,sans-serif;">
      <a href="http://traces.pin" target="_blank" style="
        display:flex;align-items:center;gap:10px;padding:12px 24px;
        background:linear-gradient(135deg,#7c3aed,#5b21b6);
        color:#fff;text-decoration:none;border-radius:8px;font-weight:600;font-size:14px;
        box-shadow:0 2px 8px rgba(124,58,237,0.3);
        transition:transform 0.15s ease;
      " onmouseover="this.style.transform='translateY(-1px)'" onmouseout="this.style.transform=''">
        🔍 Open SkyWalking UI — traces.pin
      </a>
      <a href="http://traces.pin/general/service" target="_blank" style="
        display:flex;align-items:center;gap:8px;padding:10px 18px;
        background:#f3f4f6;color:#374151;text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;
      ">Services →</a>
      <a href="http://traces.pin/general/topology" target="_blank" style="
        display:flex;align-items:center;gap:8px;padding:10px 18px;
        background:#f3f4f6;color:#374151;text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;
      ">Topology →</a>
    </div>
  |||);

local oapLogsPanel = c.serviceLogsPanel('OAP Logs', 'skywalking-oap', y=17);

g.dashboard.new('Observability — SkyWalking')
+ g.dashboard.withUid('observability-skywalking')
+ g.dashboard.withDescription('SkyWalking OAP JVM health: uptime, heap, GC, CPU. Links to SkyWalking UI.')
+ g.dashboard.withTags(['observability', 'skywalking', 'tracing'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  uptimeStat, threadsStat, heapStat, cpuStat,
  g.panel.row.new('JVM') + c.pos(0, 4, 24, 1),
  heapTs, gcTs,
  g.panel.row.new('SkyWalking UI') + c.pos(0, 12, 24, 1),
  swUiLink,
  g.panel.row.new('Logs') + c.pos(0, 16, 24, 1),
  oapLogsPanel,
])
