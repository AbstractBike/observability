// Metric Discovery Dashboard
//
// Show all available metrics in VictoriaMetrics with their cardinality and status.
// Helps identify unused exporters and troubleshoot missing metrics.
//
// Queries VictoriaMetrics API directly to show:
// - All metric names available
// - Metrics by job/service
// - Series cardinality per metric
// - Recent activity (metrics used in last 5m)

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Top Metrics by Cardinality ──────────────────────────────────────────────

local topMetricsTs =
  g.panel.timeSeries.new('Top 20 Metrics by Cardinality (5m avg)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(20, count by (__name__) ({__name__=~".+"})) or vector(0)',
      '{{__name__}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Metrics by Job ────────────────────────────────────────────────────────

local metricsByJobTs =
  g.panel.timeSeries.new('Metric Count by Job')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'count by (job) ({__name__=~".+"}) or vector(0)',
      '{{job}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Total Series Count ────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('victoriametrics', col=0);

// 5-stat layout: alert(6) + series(4) + unique(4) + jobs(5) + ingest(5) = 24
local totalSeriesStat =
  g.panel.stat.new('Total Series')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count({__name__=~".+"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Unique Metrics Count ───────────────────────────────────────────────────

local uniqueMetricsStat =
  g.panel.stat.new('Unique Metrics')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (__name__) ({__name__=~".+"})) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

// ── Jobs with Metrics ────────────────────────────────────────────────────

local jobCountStat =
  g.panel.stat.new('Active Jobs')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (job) ({__name__=~".+"})) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

// ── Ingestion Rate ──────────────────────────────────────────────────────

local ingestionRateStat =
  g.panel.stat.new('Ingestion Rate (5m)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate({__name__=~".+"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqpm')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

// ── Top 10 Jobs by Series Count ────────────────────────────────────────────

local topJobsTable =
  g.panel.table.new('Top 10 Jobs by Series Count')
  + c.pos(0, 14, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'sort_desc(topk(10, count by (job) ({__name__=~".+"})  or vector(0)))',
      'Series Count'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('short')
  + g.panel.table.options.withSortBy([
    { displayName: 'Value', desc: true },
  ]);

// ── Metrics Info Text ────────────────────────────────────────────────────

local infoPanel =
  g.panel.text.new('📊 Metric Discovery Guide & Related Dashboards')
  + c.pos(0, 22, 24, 3)
  + g.panel.text.options.withContent(|||
    ### 📊 Related Dashboards
    - **[Performance & Optimization](/d/performance-optimization)** — Monitor query latency and storage impact
    - **[Services Health](/d/services-health)** — View health of metric-producing services
    - **[Observability — Logs](/d/observability-logs)** — Debug missing metrics in logs

    ### How to use this dashboard:

    1. **Top 20 Metrics** - Shows metrics consuming most cardinality (impact on storage)
    2. **Metrics by Job** - Shows which exporters/services are active
    3. **Stats** - Total series, unique metrics, active jobs, ingestion rate
    4. **Top Jobs** - Which services are reporting the most metrics

    ### Troubleshooting:

    - **Missing service data**: Check if it appears in "Top Jobs" table
    - **High cardinality**: Click on metric in "Top 20" to investigate
    - **Unused exporters**: Look for jobs in config but not in table
    - **Performance issues**: Large ingestion rate may indicate cardinality explosion
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('victoriametrics', [
  { symptom: 'Missing Service Metrics', runbook: 'metrics/missing-scrape', check: 'Check "Top Jobs" table - verify job appears in Prometheus scrape config' },
  { symptom: 'High Cardinality Alert', runbook: 'metrics/cardinality', check: 'Inspect "Top 20 Metrics" for high-cardinality offenders' },
  { symptom: 'Ingestion Rate Drop', runbook: 'metrics/ingest-drop', check: 'Compare current rate vs baseline in "Ingestion Rate" stat' },
  { symptom: 'Storage Growing Fast', runbook: 'metrics/retention', check: 'Review metric discovery dashboard and reduce retention or cardinality' },
], y=39);

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('VictoriaMetrics Logs', 'victoriametrics', y=28);

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Metric Discovery')
+ g.dashboard.withUid('metrics-discovery')
+ g.dashboard.withDescription('Catalog of all metrics in VictoriaMetrics: cardinality, jobs, ingestion rate, trends.')
+ g.dashboard.withTags(['observability', 'metrics', 'discovery', 'troubleshooting', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, totalSeriesStat, uniqueMetricsStat, jobCountStat, ingestionRateStat,

  g.panel.row.new('📈 Metrics Overview') + c.pos(0, 6, 24, 1),
  topMetricsTs, metricsByJobTs,

  g.panel.row.new('ℹ️ Jobs & Info') + c.pos(0, 15, 24, 1),
  topJobsTable, infoPanel,

  g.panel.row.new('📝 Logs') + c.pos(0, 27, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 38, 24, 1),
  troubleGuide,
])
