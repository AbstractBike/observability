// Query Performance Profiling Dashboard
//
// Monitors Grafana query performance:
// - Query execution time distribution
// - Slowest queries by datasource
// - Query error rates
// - Datasource health

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Average Query Time ──────────────────────────────────────────────────────

local avgQueryTimeStat =
  g.panel.stat.new('Latency — Query Executor — avg')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.5, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) or vector(0)) * 1000', 'ms'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 100 },
    { color: 'red', value: 500 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── P99 Query Time ──────────────────────────────────────────────────────────

local p99QueryTimeStat =
  g.panel.stat.new('Latency — Query Executor — p99')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.99, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) or vector(0)) * 1000', 'ms'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Query Error Rate ────────────────────────────────────────────────────────

local queryErrorRateStat =
  g.panel.stat.new('Error Rate — Queries — 5m')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(rate(grafana_query_errors_total[5m])) / sum(rate(grafana_queries_total[5m])) or vector(0)) * 100', '%'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Total Queries Executed ──────────────────────────────────────────────────

local totalQueriesStat =
  g.panel.stat.new('Throughput — Queries — /sec')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(grafana_queries_total[5m])) or vector(0)', 'queries/sec'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

// ── Query Time Distribution ─────────────────────────────────────────────────

local queryTimeDistributionTs =
  g.panel.timeSeries.new('Latency Distribution — Queries — percentiles')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.5, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) * 1000',
      'p50'
    ),
    c.vmQ(
      'histogram_quantile(0.95, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) * 1000',
      'p95'
    ),
    c.vmQ(
      'histogram_quantile(0.99, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) * 1000',
      'p99'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Slowest Queries by Datasource ───────────────────────────────────────────

local slowestQueriesTs =
  g.panel.timeSeries.new('Slowest Queries — by datasource')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(5, sum by (datasource) (rate(grafana_query_duration_seconds_bucket{le="1"}[5m]))) * 1000',
      '{{datasource}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Query Errors ────────────────────────────────────────────────────────────

local queryErrorsTs =
  g.panel.timeSeries.new('Errors — Queries — 5m rolling')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'sum(rate(grafana_query_errors_total[5m])) by (datasource)',
      '{{datasource}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Query Throughput by Datasource ──────────────────────────────────────────

local queryThroughputTs =
  g.panel.timeSeries.new('Throughput — Queries — by datasource')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'sum by (datasource) (rate(grafana_queries_total[5m]))',
      '{{datasource}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Info Panel ──────────────────────────────────────────────────────────────

local infoPanel =
  g.panel.text.new('🔬 Query Performance Monitoring & Related Dashboards')
  + c.pos(0, 18, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### 📊 Related Dashboards
    - **[Performance & Optimization](/d/performance-optimization)** — System-wide performance metrics
    - **[Observability — Grafana](/d/observability-grafana)** — Grafana instance health
    - **[Dashboard Index](/d/dashboard-index)** — Discover all observability dashboards

    ### 🔍 How to Use This Dashboard

    **Key Metrics:**
    1. **Latency Percentiles** — p50/p95/p99 show query speed distribution
    2. **Error Rate** — Percentage of queries failing (target: < 1%)
    3. **Slowest by Datasource** — Which datasources have highest latency
    4. **Throughput** — Queries executed per second

    **When to investigate:**
    - P99 latency > 5 seconds: Check for slow datasources
    - Error rate > 5%: Check datasource health and connectivity
    - Throughput drop: May indicate dashboard load issue
    - Uneven distribution: Slow datasource may need optimization

    ### 💡 Optimization Tips
    - Use datasource-specific caching (Redis)
    - Implement query result caching in Grafana
    - Optimize slow datasource queries (see Performance dashboard)
    - Consider dashboard refresh rate (5s is often too fast)
  |||);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Query Performance')
+ g.dashboard.withUid('query-performance')
+ g.dashboard.withDescription('Grafana query execution profiling: latency distribution, errors by datasource, throughput trends. Identify slow datasources and optimize dashboard refresh.')
+ g.dashboard.withTags(['observability', 'meta', 'performance', 'troubleshooting'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  avgQueryTimeStat, p99QueryTimeStat, queryErrorRateStat, totalQueriesStat,

  g.panel.row.new('Trends') + c.pos(0, 4, 24, 1),
  queryTimeDistributionTs, slowestQueriesTs,
  queryErrorsTs, queryThroughputTs,

  g.panel.row.new('Info') + c.pos(0, 17, 24, 1),
  infoPanel,
])
