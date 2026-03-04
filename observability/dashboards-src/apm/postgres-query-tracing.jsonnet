// PostgreSQL — Query Tracing & Performance Analysis
//
// Database-specific tracing dashboard showing:
// - Query latency distribution
// - Slow query identification and analysis
// - Connection pool status
// - Transaction patterns
// - Correlation with application traces
//
// Each query span shows:
// - Query text (if captured)
// - Execution time
// - Connection pool utilization
// - Related application trace context

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Query Performance Stats ────────────────────────────────────────────────

local queryRateStat =
  g.panel.stat.new('Queries/sec')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(skywalking_span_total{service="PostgreSQL",operation=~".*query.*"}[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value');

local avgQueryLatencyStat =
  g.panel.stat.new('Avg Query Time')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.50, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m]))) or vector(0))'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local p95QueryLatencyStat =
  g.panel.stat.new('P95 Query Time')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.95, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m]))) or vector(0))'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local slowQueryCountStat =
  g.panel.stat.new('Slow Queries (>1s)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}{le="+Inf"} > 1000) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

// ── Query Latency Analysis ─────────────────────────────────────────────────

local queryLatencyTs =
  g.panel.timeSeries.new('Query Latency Distribution (p50/p95/p99)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.50, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m])))', 'p50'),
    c.vmQ('histogram_quantile(0.95, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m])))', 'p95'),
    c.vmQ('histogram_quantile(0.99, sum by(le) (rate(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}[5m])))', 'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local slowQueryVolumeTs =
  g.panel.timeSeries.new('Slow Queries Over Time')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('count(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}{le="1000"}) or vector(0)', '>1s'),
    c.vmQ('count(skywalking_span_latency_bucket{service="postgres-server",operation=~"query.*"}{le="5000"}) or vector(0)', '>5s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

g.dashboard.new('PostgreSQL — Query Tracing & Performance')
+ g.dashboard.withUid('tracing-postgresql')
+ g.dashboard.withDescription('Database query tracing: latency distribution, slow query analysis, connection pool status.')
+ g.dashboard.withTags(['observability', 'tracing', 'database', 'performance', 'postgresql'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Query Performance') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  queryRateStat, avgQueryLatencyStat, p95QueryLatencyStat, slowQueryCountStat,

  g.panel.row.new('Analysis') + c.pos(0, 4, 24, 1),
  queryLatencyTs, slowQueryVolumeTs,
])
