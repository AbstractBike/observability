// Matrix Services — SkyWalking APM Dashboard
// Shows service-level and JVM metrics sent by the Java agent to OAP at 192.168.0.4:11800.
// Activate agent: SW_ENABLED=true ./gradlew bootRun
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Variables ──────────────────────────────────────────────────────────────

local serviceVar =
  g.dashboard.variable.query.new('service')
  + g.dashboard.variable.query.withDatasourceFromVariable(c.swDsVar)
  + g.dashboard.variable.query.queryTypes.withLabelValues('service', 'service_cpm')
  + g.dashboard.variable.query.generalOptions.withLabel('Service')
  + g.dashboard.variable.query.selectionOptions.withMulti(false)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(false)
  + g.dashboard.variable.query.refresh.onTime();

local instanceVar =
  g.dashboard.variable.query.new('instance')
  + g.dashboard.variable.query.withDatasourceFromVariable(c.swDsVar)
  + g.dashboard.variable.query.queryTypes.withLabelValues('service_instance_id', 'instance_jvm_cpu{service="$service"}')
  + g.dashboard.variable.query.generalOptions.withLabel('Instance')
  + g.dashboard.variable.query.selectionOptions.withMulti(false)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
  + g.dashboard.variable.query.refresh.onTime();

// ── Stat panels (row 1) ────────────────────────────────────────────────────

local cpmStat =
  g.panel.stat.new('Calls / min')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_cpm{service="$service"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area')
  + g.panel.stat.options.withReduceOptions(
    g.panel.stat.options.reduceOptions.withCalcs(['lastNotNull'])
  );

local respTimeStat =
  g.panel.stat.new('Avg Response Time')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_resp_time{service="$service"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withReduceOptions(
    g.panel.stat.options.reduceOptions.withCalcs(['lastNotNull'])
  );

local errorRateStat =
  g.panel.stat.new('Error Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_error_rate{service="$service"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withReduceOptions(
    g.panel.stat.options.reduceOptions.withCalcs(['lastNotNull'])
  );

local apdexStat =
  g.panel.stat.new('Apdex Score')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ('(service_apdex{service="$service"} / 10000) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 0.7 },
    { color: 'green', value: 0.94 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withReduceOptions(
    g.panel.stat.options.reduceOptions.withCalcs(['lastNotNull'])
  );

// ── Service metrics (row 2) ────────────────────────────────────────────────

local cpmTs =
  g.panel.timeSeries.new('Calls per Minute')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_cpm{service="$service"}) or vector(0)', 'cpm'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('single');

local latencyTs =
  g.panel.timeSeries.new('Response Time Percentiles (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_percentile{service="$service",le="50"}) or vector(0)',  'p50'),
    c.swQ('(service_percentile{service="$service",le="75"}) or vector(0)',  'p75'),
    c.swQ('(service_percentile{service="$service",le="90"}) or vector(0)',  'p90'),
    c.swQ('(service_percentile{service="$service",le="95"}) or vector(0)',  'p95'),
    c.swQ('(service_percentile{service="$service",le="99"}) or vector(0)',  'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local errorRateTs =
  g.panel.timeSeries.new('Error Rate (%)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(service_error_rate{service="$service"}) or vector(0)', 'error %'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 1 },
  ])
  + g.panel.timeSeries.options.tooltip.withMode('single');

local throughputTs =
  g.panel.timeSeries.new('Endpoint Throughput (top 5)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('topk(5, (endpoint_cpm{service="$service"}) or vector(0))', '{{endpoint}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── JVM metrics (row 3) ────────────────────────────────────────────────────

local jvmCpuTs =
  g.panel.timeSeries.new('JVM CPU Usage (%)')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(instance_jvm_cpu{service="$service",service_instance_id=~"$instance"}) or vector(0)', '{{service_instance_id}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local jvmHeapTs =
  g.panel.timeSeries.new('JVM Heap Memory')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(instance_jvm_memory_used{service="$service",service_instance_id=~"$instance",name="heap"}) or vector(0)',  'heap used'),
    c.swQ('(instance_jvm_memory_max{service="$service",service_instance_id=~"$instance",name="heap"}) or vector(0)',   'heap max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local jvmGcTs =
  g.panel.timeSeries.new('GC Time (ms/min)')
  + c.tsPos(0, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(instance_jvm_young_gc_time{service="$service",service_instance_id=~"$instance"}) or vector(0)', 'young GC'),
    c.swQ('(instance_jvm_old_gc_time{service="$service",service_instance_id=~"$instance"}) or vector(0)',   'old GC'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local jvmThreadTs =
  g.panel.timeSeries.new('JVM Thread Count')
  + c.tsPos(1, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.swQ('(instance_jvm_thread_live_count{service="$service",service_instance_id=~"$instance"}) or vector(0)',    'live'),
    c.swQ('(instance_jvm_thread_daemon_count{service="$service",service_instance_id=~"$instance"}) or vector(0)',  'daemon'),
    c.swQ('(instance_jvm_thread_peak_count{service="$service",service_instance_id=~"$instance"}) or vector(0)',    'peak'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Services — Matrix APM (SkyWalking)')
+ g.dashboard.withUid('matrix-apm-skywalking')
+ g.dashboard.withDescription('Matrix services APM: latency, throughput, error rate, JVM — via SkyWalking Java agent.')
+ g.dashboard.withTags(['matrix', 'apm', 'skywalking', 'jvm'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.time.withFrom('now-1h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([c.swDsVar, serviceVar, instanceVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Service Overview')   + c.pos(0, 0,  24, 1),
  cpmStat, respTimeStat, errorRateStat, apdexStat,

  g.panel.row.new('Request Traffic')    + c.pos(0, 4,  24, 1),
  cpmTs, latencyTs,

  g.panel.row.new('Errors & Endpoints') + c.pos(0, 13, 24, 1),
  errorRateTs, throughputTs,

  g.panel.row.new('JVM Internals')      + c.pos(0, 22, 24, 1),
  jvmCpuTs, jvmHeapTs,

  g.panel.row.new('Garbage Collection & Threads') + c.pos(0, 31, 24, 1),
  jvmGcTs, jvmThreadTs,
])
