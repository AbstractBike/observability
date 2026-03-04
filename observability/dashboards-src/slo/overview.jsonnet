local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local sloStatPanel(title, errorRatioExpr, targetPct, col) =
  g.panel.stat.new(title)
  + c.statPos(col)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - ' + errorRatioExpr + ') * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(3)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: targetPct - 0.5 },
    { color: 'green', value: targetPct },
  ])
  + g.panel.stat.options.withColorMode('background');

local budgetTs(title, errorRatioExpr, targetErrorRatio, col, row) =
  g.panel.timeSeries.new(title)
  + c.tsPos(col, row)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(1 - (' + errorRatioExpr + ' / ' + std.toString(targetErrorRatio) + ')) * 100',
      'budget remaining %'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMin(0)
  + g.panel.timeSeries.standardOptions.withMax(100);

g.dashboard.new('SLO — Overview')
+ g.dashboard.withUid('slo-overview')
+ g.dashboard.withDescription('Global SLO compliance table and error budget burn rates.')
+ g.dashboard.withTags(['slo', 'overview'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('30-day Compliance') + c.pos(0, 0, 24, 1),
  sloStatPanel('Host Uptime (99.5%)', 'slo:host_uptime:error_ratio_30d', 99.5, 0),
  sloStatPanel('PostgreSQL (99.9%)', 'slo:postgresql:error_ratio_30d', 99.9, 1),
  sloStatPanel('Redis (99.9%)', 'slo:redis:error_ratio_30d', 99.9, 2),
  sloStatPanel('Grafana (99%)', 'slo:grafana:error_ratio_30d', 99.0, 3),

  g.panel.row.new('Error Budget Remaining (30d)') + c.pos(0, 4, 24, 1),
  budgetTs('PostgreSQL Error Budget', 'slo:postgresql:error_ratio_30d', 0.001, 0, 0),
  budgetTs('Redis Error Budget', 'slo:redis:error_ratio_30d', 0.001, 1, 0),
  budgetTs('Host Error Budget', 'slo:host_uptime:error_ratio_30d', 0.005, 0, 1),
  budgetTs('Grafana Error Budget', 'slo:grafana:error_ratio_30d', 0.01, 1, 1),
])
