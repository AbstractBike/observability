// Dashboard: Services — victorialogs-general
// Question:  "Is the instant-read VictoriaLogs fork healthy? Ingestion rate, pending rows, storage state."
//
// Replaces the old vlog-proxy dashboard. The fork makes data queryable in ~100ms
// without a proxy layer (configurable -rowsFlushDelay).
//
// Data: vl_* metrics from victorialogs-general /metrics endpoint (port 9435)
// Key metrics: vl_rows_ingested_total, vl_pending_rows, vl_storage_parts,
//   vl_data_size_bytes, vl_merge_duration_seconds, vl_http_requests_total

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Instance label filter for victorialogs-general on port 9435.
local i = 'instance=~".*:9435"';

// ── Row 0: Status stats ───────────────────────────────────────────────────────

local uptimeStat =
  g.panel.stat.new('Uptime')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('vm_app_uptime_seconds{' + i + '}')])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local pendingRowsStat =
  g.panel.stat.new('Pending Rows')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('sum(vl_pending_rows{' + i + '}) or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1000 },
    { color: 'red', value: 10000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local ingestRateStat =
  g.panel.stat.new('Ingest Rate')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('rate(vl_rows_ingested_total{' + i + '}[1m]) or vector(0)')])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local httpErrorsStat =
  g.panel.stat.new('HTTP Errors (5m)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('increase(vl_http_errors_total{' + i + '}[5m]) or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Row 1: Write path ─────────────────────────────────────────────────────────

local ingestTs =
  g.panel.timeSeries.new('Ingestion Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(vl_rows_ingested_total{' + i + '}[1m]) or vector(0)', 'rows/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pendingRowsTs =
  g.panel.timeSeries.new('Pending Rows by Type')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vl_pending_rows{type="storage",' + i + '} or vector(0)', 'storage (data)'),
    c.vmQ('vl_pending_rows{type="indexdb",' + i + '} or vector(0)', 'indexdb'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Storage ──────────────────────────────────────────────────────────

local partsTs =
  g.panel.timeSeries.new('Parts Count')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vl_storage_parts{type="storage/inmemory",' + i + '} or vector(0)', 'inmemory'),
    c.vmQ('vl_storage_parts{type="storage/small",' + i + '} or vector(0)', 'small'),
    c.vmQ('vl_storage_parts{type="storage/big",' + i + '} or vector(0)', 'big'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local mergeDurationTs =
  g.panel.timeSeries.new('Merge Duration (p50/p95)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vl_merge_duration_seconds{quantile="0.5",' + i + '} or vector(0)', 'p50'),
    c.vmQ('vl_merge_duration_seconds{quantile="0.95",' + i + '} or vector(0)', 'p95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(3)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: HTTP & storage size ──────────────────────────────────────────────

local httpRequestsTs =
  g.panel.timeSeries.new('HTTP Request Rate')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (path) (rate(vl_http_requests_total{' + i + '}[1m])) or vector(0)', '{{path}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local dataSizeTs =
  g.panel.timeSeries.new('Storage Size')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vl_data_size_bytes{type="storage",' + i + '} or vector(0)', 'data'),
    c.vmQ('vl_data_size_bytes{type="indexdb",' + i + '} or vector(0)', 'index'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Logs ────────────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('victorialogs-general Logs', 'victorialogs-general', y=29);

// ── Dashboard assembly ────────────────────────────────────────────────────────

g.dashboard.new('victorialogs-general')
+ g.dashboard.withUid('pin-si-victorialogs-general')
+ g.dashboard.withDescription('victorialogs-general — VictoriaLogs fork with instant read/write (-rowsFlushDelay=100ms). Ingestion, pending rows, storage health.')
+ g.dashboard.withTags(['services', 'observability', 'vlog'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withTimezone('browser')
+ g.dashboard.time.withFrom('now-1h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  uptimeStat,
  pendingRowsStat,
  ingestRateStat,
  httpErrorsStat,
  ingestTs,
  pendingRowsTs,
  partsTs,
  mergeDurationTs,
  httpRequestsTs,
  dataSizeTs,
  logsPanel,
])
