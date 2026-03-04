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
      'topk(20, count by (__name__) ({__name__=~".+"}))',
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
      'count by (job) ({__name__=~".+"})',
      '{{job}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Total Series Count ────────────────────────────────────────────────────

local totalSeriesStat =
  g.panel.stat.new('Total Series')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count({__name__=~".+"})'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Unique Metrics Count ───────────────────────────────────────────────────

local uniqueMetricsStat =
  g.panel.stat.new('Unique Metrics')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (__name__) ({__name__=~".+"}))'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

// ── Jobs with Metrics ────────────────────────────────────────────────────

local jobCountStat =
  g.panel.stat.new('Active Jobs')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (job) ({__name__=~".+"}))'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

// ── Ingestion Rate ──────────────────────────────────────────────────────

local ingestionRateStat =
  g.panel.stat.new('Ingestion Rate (5m)')
  + c.statPos(3)
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
  + c.pos(0, 5, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'sort_desc(topk(10, count by (job) ({__name__=~".+"})))',
      'Series Count'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('short')
  + g.panel.table.options.withSortBy([
    { displayName: 'Value', desc: true },
  ]);

// ── Metrics Info Text ────────────────────────────────────────────────────

local infoPanel =
  g.panel.text.new('📊 Metric Discovery Guide')
  + c.pos(0, 13, 24, 3)
  + g.panel.text.options.withContent(|||
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

    See [DASHBOARD-DEPENDENCIES.md](./DASHBOARD-DEPENDENCIES.md) for metric requirements per dashboard.
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('VictoriaMetrics Logs', 'victoriametrics', y=17);

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Metric Discovery')
+ g.dashboard.withUid('metrics-discovery')
+ g.dashboard.withDescription('Catalog of all metrics in VictoriaMetrics: cardinality, jobs, ingestion rate, trends.')
+ g.dashboard.withTags(['observability', 'metrics', 'discovery', 'troubleshooting'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  totalSeriesStat, uniqueMetricsStat, jobCountStat, ingestionRateStat,

  g.panel.row.new('Metrics Overview') + c.pos(0, 4, 24, 1),
  topMetricsTs, metricsByJobTs,

  g.panel.row.new('Jobs & Info') + c.pos(0, 12, 24, 1),
  topJobsTable, infoPanel,

  g.panel.row.new('Logs') + c.pos(0, 16, 24, 1),
  logsPanel,
])
