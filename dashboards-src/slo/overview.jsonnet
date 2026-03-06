local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local alertPanel = c.alertCountPanel('slo', col=0);

// 5-stat layout: alert(6) + host(4) + postgres(4) + redis(5) + grafana(5) = 24
local sloStatPos = [
  c.pos(6, 1, 4, 3),
  c.pos(10, 1, 4, 3),
  c.pos(14, 1, 5, 3),
  c.pos(19, 1, 5, 3),
];

local sloStatPanel(title, errorRatioExpr, targetPct, col) =
  g.panel.stat.new(title)
  + sloStatPos[col]
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((1 - ' + errorRatioExpr + ') * 100) or vector(0)'),
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
      '((1 - (' + errorRatioExpr + ' / ' + std.toString(targetErrorRatio) + ')) * 100) or vector(0)',
      'budget remaining %'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMin(0)
  + g.panel.timeSeries.standardOptions.withMax(100);

local guidancePanel =
  g.panel.text.new('📚 SLO Guidance')
  + c.pos(0, 22, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    **SLO Budget Tracking**: Each service has a monthly error budget. When the budget reaches 0%, the service has violated its SLO target.

    **Budget Formula**: `Remaining % = (1 - (Actual Error Rate / Target Error Rate)) × 100`

    - **Green (>50%)**: Healthy budget, room for degradation
    - **Yellow (0-50%)**: Limited budget, monitor closely
    - **Red (<0%)**: SLO breach, immediate action required

    ### Related Dashboards
    - **[Services Health](/d/services-health)** — Current operational status and error rates
    - **[Observability — Alerts](/d/alerts-dashboard)** — Active alerts and firing rate
    - **[Performance & Optimization](/d/performance-optimization)** — System performance tracking
  |||);

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('slo', [
  { symptom: 'SLO Violation Alert', runbook: 'slo/violation', check: 'Review specific service compliance stat and error budget burndown' },
  { symptom: 'Budget Exhausted', runbook: 'slo/budget-exhausted', check: 'Check "Error Budget Remaining" charts for affected service' },
  { symptom: 'Unexpected Spike', runbook: 'slo/spike-investigation', check: 'Correlate error budget drop with specific timestamp in logs' },
  { symptom: 'SLO Target Change', runbook: 'slo/target-update', check: 'Verify new target percentage is correctly configured' },
], y=26);

g.dashboard.new('SLO — Overview')
+ g.dashboard.withUid('slo-overview')
+ g.dashboard.withDescription('Global SLO compliance table and error budget burn rates.')
+ g.dashboard.withTags(['slo', 'overview', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 30-day Compliance') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel,
  sloStatPanel('Host Uptime (99.5%)', 'slo:host_uptime:error_ratio_30d', 99.5, 0),
  sloStatPanel('PostgreSQL (99.9%)', 'slo:postgresql:error_ratio_30d', 99.9, 1),
  sloStatPanel('Redis (99.9%)', 'slo:redis:error_ratio_30d', 99.9, 2),
  sloStatPanel('Grafana (99%)', 'slo:grafana:error_ratio_30d', 99.0, 3),

  g.panel.row.new('💯 Error Budget Remaining (30d)') + c.pos(0, 4, 24, 1),
  budgetTs('PostgreSQL Error Budget', 'slo:postgresql:error_ratio_30d', 0.001, 0, 0),
  budgetTs('Redis Error Budget', 'slo:redis:error_ratio_30d', 0.001, 1, 0),
  budgetTs('Host Error Budget', 'slo:host_uptime:error_ratio_30d', 0.005, 0, 1),
  budgetTs('Grafana Error Budget', 'slo:grafana:error_ratio_30d', 0.01, 1, 1),

  g.panel.row.new('💡 Guidance') + c.pos(0, 21, 24, 1),
  guidancePanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 25, 24, 1),
  troubleGuide,
])
