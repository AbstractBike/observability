// Dashboard: Services — vlog-proxy
// Question:  "Is vlog-proxy healthy? Buffer state, write/flush path, query path, VLogs reachability."
//
// Data: vlogproxy_* metrics from vlog-proxy /metrics endpoint (service="vlog-proxy")
// Metrics: vlogproxy_buffer_active_entries, vlogproxy_buffer_retired_entries,
//   vlogproxy_buffer_utilization_ratio, vlogproxy_writes_total, vlogproxy_writes_rejected_total,
//   vlogproxy_flush_total, vlogproxy_flush_entries_total, vlogproxy_flush_errors_total,
//   vlogproxy_flush_requeue_total, vlogproxy_flush_duration_seconds,
//   vlogproxy_flush_verify_duration_seconds, vlogproxy_queries_merged_total,
//   vlogproxy_queries_passthrough_total, vlogproxy_queries_buffer_hits_total,
//   vlogproxy_vlogs_reachable

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Row 0: Status stats ───────────────────────────────────────────────────────

local vlogsReachableStat =
  g.panel.stat.new('VLogs Reachable')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('vlogproxy_vlogs_reachable or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local bufferUtilStat =
  g.panel.stat.new('Buffer Utilization')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('vlogproxy_buffer_utilization_ratio or vector(0)')])
  + g.panel.stat.standardOptions.withUnit('percentunit')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 0.7 },
    { color: 'red', value: 0.9 },
  ])
  + g.panel.stat.options.withColorMode('background');

local activeEntriesStat =
  g.panel.stat.new('Active Buffer Entries')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('vlogproxy_buffer_active_entries or vector(0)')])
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local flushErrorsStat =
  g.panel.stat.new('Flush Errors (total)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('vlogproxy_flush_errors_total or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Row 1: Write path ─────────────────────────────────────────────────────────

local writesTs =
  g.panel.timeSeries.new('Write Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(vlogproxy_writes_total[1m]) or vector(0)', 'accepted'),
    c.vmQ('rate(vlogproxy_writes_rejected_total[1m]) or vector(0)', 'rejected'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local bufferTs =
  g.panel.timeSeries.new('Buffer Entries')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vlogproxy_buffer_active_entries or vector(0)', 'active'),
    c.vmQ('vlogproxy_buffer_retired_entries or vector(0)', 'retired (post-flush, pre-verify)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Flush path ─────────────────────────────────────────────────────────

local flushRateTs =
  g.panel.timeSeries.new('Flush Rate & Errors')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(vlogproxy_flush_total[5m]) or vector(0)', 'flushes/s'),
    c.vmQ('rate(vlogproxy_flush_errors_total[5m]) or vector(0)', 'errors/s'),
    c.vmQ('rate(vlogproxy_flush_requeue_total[5m]) or vector(0)', 'requeues/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local flushDurationTs =
  g.panel.timeSeries.new('Flush & Verify Duration (p50/p95/p99)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.50, rate(vlogproxy_flush_duration_seconds_bucket[5m]))', 'flush p50'),
    c.vmQ('histogram_quantile(0.95, rate(vlogproxy_flush_duration_seconds_bucket[5m]))', 'flush p95'),
    c.vmQ('histogram_quantile(0.50, rate(vlogproxy_flush_verify_duration_seconds_bucket[5m]))', 'verify p50'),
    c.vmQ('histogram_quantile(0.95, rate(vlogproxy_flush_verify_duration_seconds_bucket[5m]))', 'verify p95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(3)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: Query path ─────────────────────────────────────────────────────────

local queryRateTs =
  g.panel.timeSeries.new('Query Rate by Type')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(vlogproxy_queries_merged_total[1m]) or vector(0)', 'merged (buffer+vlogs)'),
    c.vmQ('rate(vlogproxy_queries_passthrough_total[1m]) or vector(0)', 'passthrough (complex)'),
    c.vmQ('rate(vlogproxy_queries_buffer_hits_total[1m]) or vector(0)', 'buffer hits'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local flushEntriesTs =
  g.panel.timeSeries.new('Entries Flushed to VLogs')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(vlogproxy_flush_entries_total[1m]) or vector(0)', 'entries/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8);

// ── Dashboard assembly ────────────────────────────────────────────────────────

g.dashboard.new('vlog-proxy')
+ g.dashboard.withUid('pin-si-vlog-proxy')
+ g.dashboard.withDescription('vlog-proxy — write-behind cache for VictoriaLogs. Buffer state, write/flush/verify path, query routing.')
+ g.dashboard.withTags(['services', 'observability', 'vlog'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withTimezone('browser')
+ g.dashboard.time.withFrom('now-1h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  vlogsReachableStat,
  bufferUtilStat,
  activeEntriesStat,
  flushErrorsStat,
  writesTs,
  bufferTs,
  flushRateTs,
  flushDurationTs,
  queryRateTs,
  flushEntriesTs,
])
