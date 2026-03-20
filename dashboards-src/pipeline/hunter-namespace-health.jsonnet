local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Hunter Namespace Health — Worker Up/Down by Namespace ───────────────────
//
// Monitors hunter_namespace_worker_up for the hunter-prod consolidated
// namespace. All candidates share hunter-prod — worker health is monitored
// at namespace level, not per-candidate.

// ── Variables ───────────────────────────────────────────────────────────────

local envVar =
  g.dashboard.variable.custom.new('env', [
    { key: 'prod', value: 'prod' },
    { key: 'dev', value: 'dev' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Environment')
  + g.dashboard.variable.custom.generalOptions.withCurrent('prod', 'prod');

local hunterMetricsDsVar =
  g.dashboard.variable.datasource.new('huntermetrics', 'victoriametrics-metrics-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('Hunter Metrics')
  + g.dashboard.variable.datasource.withRegex('^HunterMetrics-Prod$');

// ── Query helper ────────────────────────────────────────────────────────────

local hQ(expr, legend='') =
  g.query.prometheus.new('$huntermetrics', expr)
  + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {});

// ── Metric selector with mandatory labels ───────────────────────────────────

local workerUp = 'hunter_namespace_worker_up{namespace="hunter-prod", service="hunter", host="homelab", env="$env"}';

// ── Panels ──────────────────────────────────────────────────────────────────

local upDownThresholds =
  g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ]);

local upDownMappings =
  g.panel.stat.standardOptions.withMappings([
    { type: 'value', options: { '0': { text: 'DOWN' }, '1': { text: 'UP' } } },
  ]);

local workerStatusStat =
  g.panel.stat.new(c.panelTitle('Status', 'Hunter', 'Worker Up'))
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    hQ(workerUp, 'hunter-prod'),
  ])
  + upDownThresholds
  + upDownMappings
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local workerHistoryTs =
  g.panel.timeSeries.new(c.panelTitle('Timeseries', 'Hunter', 'Worker Up History'))
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ(workerUp, 'hunter-prod'),
  ])
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ]);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Hunter \u2014 Namespace Health')
+ g.dashboard.withUid('hunter-namespace-health')
+ g.dashboard.withDescription('Worker up/down status for hunter-prod consolidated namespace.')
+ g.dashboard.withTags(['hunter', 'namespace', 'temporal'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.time.withFrom('now-24h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([envVar, hunterMetricsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Worker Status \u2014 hunter-prod') + c.pos(0, 0, 24, 1),
  workerStatusStat,

  g.panel.row.new('History') + c.pos(0, 4, 24, 1),
  workerHistoryTs,
])
