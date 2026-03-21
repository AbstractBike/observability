local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// OAP Prometheus endpoint (:1234) exports JVM/process metrics AND trace ingestion histograms.
// Metric names at :1234 have NO oap_ prefix — correct names: trace_in_latency_{bucket,count,sum}.

local alertPanel = c.alertCountPanel('skywalking-oap', col=0);

// 5-stat layout: alert(6) + uptime(4) + threads(4) + heap(5) + cpu(5) = 24
local uptimeStat =
  g.panel.stat.new('OAP Uptime')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('time() - process_start_time_seconds{job="skywalking-oap"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value');

local threadsStat =
  g.panel.stat.new('OAP Threads')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_threads_current{job="skywalking-oap"} or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local heapStat =
  g.panel.stat.new('Heap Used')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('jvm_memory_bytes_used{job="skywalking-oap",area="heap"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.options.withColorMode('value');

local cpuStat =
  g.panel.stat.new('CPU Usage (%)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(rate(process_cpu_seconds_total{job="skywalking-oap"}[5m]) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.options.withColorMode('value');

local heapTs =
  g.panel.timeSeries.new('JVM Heap')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(jvm_memory_bytes_used{job="skywalking-oap",area="heap"}) or vector(0)', 'used'),
    c.vmQ('(jvm_memory_bytes_max{job="skywalking-oap",area="heap"}) or vector(0)', 'max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gcTs =
  g.panel.timeSeries.new('GC Time (ms/s)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(rate(jvm_gc_collection_seconds_sum{job="skywalking-oap"}[5m]) or vector(0)) * 1000', '{{gc}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local swUiLink =
  local skyWalkingUrl = c.config.skywalking_ui_url;
  g.panel.text.new('SkyWalking UI Links')
  + c.pos(0, 21, 24, 3)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <div style="display:flex;align-items:center;justify-content:center;height:100%;gap:24px;font-family:-apple-system,sans-serif;">
      <a href="| + skyWalkingUrl + |" target="_blank" style="
        display:flex;align-items:center;gap:10px;padding:12px 24px;
        background:linear-gradient(135deg,#7c3aed,#5b21b6);
        color:#fff;text-decoration:none;border-radius:8px;font-weight:600;font-size:14px;
        box-shadow:0 2px 8px rgba(124,58,237,0.3);
        transition:transform 0.15s ease;
      " onmouseover="this.style.transform='translateY(-1px)'" onmouseout="this.style.transform=''">
        🔍 Open SkyWalking UI
      </a>
      <a href="| + skyWalkingUrl + |/general/service" target="_blank" style="
        display:flex;align-items:center;gap:8px;padding:10px 18px;
        background:#f3f4f6;color:#374151;text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;
      ">Services →</a>
      <a href="| + skyWalkingUrl + |/general/topology" target="_blank" style="
        display:flex;align-items:center;gap:8px;padding:10px 18px;
        background:#f3f4f6;color:#374151;text-decoration:none;border-radius:6px;font-size:13px;border:1px solid #e5e7eb;
      ">Topology →</a>
    </div>
  |||);

local oapLogsPanel = c.serviceLogsPanel('OAP Logs', 'skywalking-oap', y=27);

local troubleGuide = c.serviceTroubleshootingGuide('skywalking-oap', [
  { symptom: 'OAP Service Down', runbook: 'skywalking/service-down', check: 'Check "OAP Uptime" stat and logs' },
  { symptom: 'High Heap Usage', runbook: 'skywalking/memory', check: 'Monitor "Heap Used" and GC time trends' },
  { symptom: 'Trace Ingestion Latency', runbook: 'skywalking/trace-latency', check: 'Check "Trace Latency" percentiles and trace volume' },
  { symptom: 'GC Pauses', runbook: 'skywalking/gc', check: 'Monitor "GC Time" spikes in JVM Performance' },
], y=38);

// ── Recent Traces Panel ────────────────────────────────────────────────────
local recentTracesPanel =
  g.panel.table.new('Recent Traces (Last 1h)')
  + c.pos(0, 14, 12, 6)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(20, trace_in_latency_count{job="skywalking-oap"} or vector(0))',
      'Traces'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('short')
  + g.panel.table.options.withSortBy([
    { displayName: 'Traces', desc: true },
  ]);

// ── Trace Latency Distribution ────────────────────────────────────────────
local traceLatencyPanel =
  g.panel.timeSeries.new('Trace Latency (p50/p95/p99)')
  + c.pos(12, 14, 12, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.5, sum by(le) (rate(trace_in_latency_bucket{job="skywalking-oap"}[5m]))) or vector(0)',
      'p50'
    ),
    c.vmQ(
      'histogram_quantile(0.95, sum by(le) (rate(trace_in_latency_bucket{job="skywalking-oap"}[5m]))) or vector(0)',
      'p95'
    ),
    c.vmQ(
      'histogram_quantile(0.99, sum by(le) (rate(trace_in_latency_bucket{job="skywalking-oap"}[5m]))) or vector(0)',
      'p99'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

g.dashboard.new('Observability — SkyWalking')
+ g.dashboard.withUid('observability-skywalking')
+ g.dashboard.withDescription('SkyWalking OAP JVM health: uptime, heap, GC, CPU. Links to SkyWalking UI.')
+ g.dashboard.withTags(['observability', 'skywalking', 'tracing', 'critical', 'infrastructure', 'apm'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, uptimeStat, threadsStat, heapStat, cpuStat,
  g.panel.row.new('⚡ JVM Performance') + c.pos(0, 6, 24, 1),
  heapTs, gcTs,
  g.panel.row.new('📡 Traces') + c.pos(0, 15, 24, 1),
  recentTracesPanel, traceLatencyPanel,
  g.panel.row.new('🔗 SkyWalking UI') + c.pos(0, 22, 24, 1),
  swUiLink,
  g.panel.row.new('📝 Logs') + c.pos(0, 26, 24, 1),
  oapLogsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 37, 24, 1),
  troubleGuide,
])
