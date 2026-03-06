// Performance & Optimization Dashboard
//
// Track system performance metrics, identify bottlenecks, and optimize infrastructure.
// Monitors:
// - Query latency (Grafana, VictoriaMetrics)
// - Storage usage and cardinality growth
// - CPU/Memory utilization by service
// - Data ingestion rates
// - Cache hit rates

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Performance Stats ──────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('observability', col=0);

// 5-stat layout: alert(6) + avgLat(4) + p99Lat(4) + totalMetrics(5) + storage(5) = 24
local avgQueryLatencyStat =
  g.panel.stat.new('Latency — Query Engines — p50')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.5, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) or vector(0)) * 1000'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local p99QueryLatencyStat =
  g.panel.stat.new('Latency — Query Engines — p99')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.99, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) or vector(0)) * 1000'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1000 },
    { color: 'red', value: 5000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local totalMetricsStat =
  g.panel.stat.new('Total Metrics')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count({__name__=~".+"})'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local storageUsedStat =
  g.panel.stat.new('Storage Used')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('vm_data_size_bytes or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

// ── Query Latency Trends ───────────────────────────────────────────────────

local queryLatencyTs =
  g.panel.timeSeries.new('HTTP Request Latency (p50/p95/p99)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.50, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) * 1000',
      'p50'
    ),
    c.vmQ(
      'histogram_quantile(0.95, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) * 1000',
      'p95'
    ),
    c.vmQ(
      'histogram_quantile(0.99, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) * 1000',
      'p99'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Storage Growth ─────────────────────────────────────────────────────────

local storageGrowthTs =
  g.panel.timeSeries.new('Storage — VictoriaMetrics — growth trend')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vm_data_size_bytes or vector(0)', 'Total'),
    c.vmQ('rate(vm_data_size_bytes[1h]) or vector(0)', 'Growth Rate'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Cardinality Growth ─────────────────────────────────────────────────────

local cardinalityTs =
  g.panel.timeSeries.new('Cardinality — Metrics — series growth')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('count({__name__=~".+"}) or vector(0)', 'Total Series'),
    c.vmQ('count(count by (__name__) ({__name__=~".+"})) or vector(0)', 'Unique Metrics'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── CPU Usage by Service ───────────────────────────────────────────────────

local cpuByServiceTs =
  g.panel.timeSeries.new('CPU Usage by Service (5m avg)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(100 - avg by (job) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) or vector(0)',
      '{{job}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Performance Insights ───────────────────────────────────────────────────

local insightsPanel =
  g.panel.text.new('⚡ Performance Optimization Guide & Related Dashboards')
  + c.pos(0, 22, 24, 3)
  + g.panel.text.options.withContent(|||
    ### 📊 Related Dashboards
    - **[Metrics Discovery](/d/metrics-discovery)** — Catalog metrics, identify high-cardinality sources
    - **[Services Health](/d/services-health)** — View health impact of optimization changes
    - **[SLO Overview](/d/slo-overview)** — Track SLO compliance while optimizing

    ### Key Performance Indicators

    1. **Query Latency**: Target < 500ms (p50), < 2s (p99)
       - If high: Check VictoriaMetrics load, enable caching

    2. **Storage Growth**: Monitor daily growth rate
       - If fast growth: Check cardinality explosion, reduce retention

    3. **Cardinality**: Lower is better (less storage, faster queries)
       - Each unique metric + labels = 1 series
       - High cardinality jobs: Check for unbounded labels

    4. **CPU Usage**: Monitor per-service spikes
       - Target: < 70% sustained, < 90% peak
       - If high: Profile queries, add query optimization rules

    ### Optimization Actions
    | Problem | Solution | Impact |
    |---------|----------|--------|
    | High cardinality | Remove high-cardinality labels | ⬇️ 50% storage |
    | Slow queries | Increase aggregation window | ⬇️ 10x latency |
    | Storage growth | Reduce retention | ⬇️ 30% storage |
    | High CPU | Enable query caching | ⬇️ 40% CPU |
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Performance & Error Logs', 'victoriametrics', y=26);

local troubleGuide = c.serviceTroubleshootingGuide('observability', [
  { symptom: 'High Query Latency', runbook: 'performance/query-latency', check: 'Check p50/p99 latency stats and trends' },
  { symptom: 'Cardinality Explosion', runbook: 'performance/cardinality', check: 'Monitor "Total Metrics" and series growth' },
  { symptom: 'Storage Growth Out of Control', runbook: 'performance/storage', check: 'Check storage growth rate and retention policy' },
  { symptom: 'High CPU Utilization', runbook: 'performance/cpu', check: 'Correlate with query latency and cardinality' },
], y=37);

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Performance & Optimization')
+ g.dashboard.withUid('performance-optimization')
+ g.dashboard.withDescription('System performance tracking: query latency, storage usage, cardinality growth, CPU utilization. Identify optimization opportunities.')
+ g.dashboard.withTags(['observability', 'performance', 'optimization', 'troubleshooting', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('⚡ Performance Stats') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, avgQueryLatencyStat, p99QueryLatencyStat, totalMetricsStat, storageUsedStat,

  g.panel.row.new('📈 Trends & Growth') + c.pos(0, 4, 24, 1),
  queryLatencyTs, storageGrowthTs,
  cardinalityTs, cpuByServiceTs,

  g.panel.row.new('🎯 Optimization Guide') + c.pos(0, 21, 24, 1),
  insightsPanel,

  g.panel.row.new('📝 Logs') + c.pos(0, 25, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 36, 24, 1),
  troubleGuide,
])
