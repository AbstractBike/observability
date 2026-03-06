// Dashboard Usage Analytics
//
// Visualize which dashboards are being used, user journeys,
// engagement metrics, and recommendations for optimization.

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Usage Summary Stats ─────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('grafana', col=0);

// 5-stat layout: alert(6) + views(4) + users(4) + engagement(5) + topDash(5) = 24
local totalViewsStat =
  g.panel.stat.new('📊 Total Views (30d)')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(increase(grafana_dashboard_view_count[30d])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local activeUsersStat =
  g.panel.stat.new('👥 Active Users (30d)')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (user) (increase(grafana_dashboard_view_count[30d])) > 0) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

local avgEngagementStat =
  g.panel.stat.new('✅ Avg Engagement')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - avg(grafana_dashboard_bounce_rate) or vector(0.3)) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.options.withColorMode('background');

local topDashboardsStat =
  g.panel.stat.new('🔝 Top Dashboards')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(topk(10, sum by (dashboard) (increase(grafana_dashboard_view_count[30d]))) > 0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

// ── Usage Trends ────────────────────────────────────────────────────────────

local usageTrendTs =
  g.panel.timeSeries.new('Daily Views Trend (30d)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(increase(grafana_dashboard_view_count[1d])) or vector(0)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local engagementTs =
  g.panel.timeSeries.new('Engagement Rate (30d)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(1 - avg(grafana_dashboard_bounce_rate) or vector(0.3)) * 100'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMin(0)
  + g.panel.timeSeries.standardOptions.withMax(100);

// ── Top Dashboards by Views ─────────────────────────────────────────────────

local topDashboardsTable =
  g.panel.table.new('Top Dashboards (30d)')
  + c.pos(0, 14, 12, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('topk(15, sum by (dashboard) (increase(grafana_dashboard_view_count[30d])))'),
  ])
  + g.panel.table.standardOptions.withUnit('short')
  + g.panel.table.fieldConfig.defaults.custom.withAlign('left');

// ── Underutilized Dashboards ────────────────────────────────────────────────

local underutilizedTable =
  g.panel.table.new('Underutilized Dashboards (<50 views)')
  + c.pos(12, 14, 12, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('sum by (dashboard) (increase(grafana_dashboard_view_count[30d])) <= 50'),
  ])
  + g.panel.table.standardOptions.withUnit('short')
  + g.panel.table.fieldConfig.defaults.custom.withAlign('left');

// ── Analytics Guide ─────────────────────────────────────────────────────────

local guidePanel =
  g.panel.text.new('📈 Usage Analytics Guide')
  + c.pos(0, 23, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Dashboard Performance Metrics

    **Top Dashboards** — Most viewed dashboards indicate primary use cases:
    - Services Health: Primary operational view
    - Alerts: Critical for incident response
    - Homelab: Main landing page

    **Underutilized Dashboards** — Candidates for improvement:
    - Low views: May need better discovery or simpler UI
    - High bounce rate: Users not finding what they need
    - Action: Simplify, improve description, add navigation links

    **Engagement Rate** — Percentage of users who stay beyond first view:
    - Target: >70% (users finding value)
    - Below 50%: Needs UX improvement
    - Trend: Should be increasing with improvements

    ### Related Dashboards
    - **[Services Health](/d/services-health)** — Most-viewed dashboard
    - **[Cost Tracking](/d/cost-tracking)** — Resource efficiency
    - **[Observability — Logs](/d/observability-logs)** — Troubleshooting tool
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('grafana', [
  { symptom: 'Low Engagement', runbook: 'grafana/engagement-low', check: 'Review "Engagement Rate" and check underutilized dashboards' },
  { symptom: 'Missing Usage Data', runbook: 'grafana/metrics-missing', check: 'Verify Grafana is sending metrics to VictoriaMetrics (check targets)' },
  { symptom: 'High View Count Anomaly', runbook: 'grafana/usage-spike', check: 'Correlate with "Daily Views Trend" and check for bots/automation' },
  { symptom: 'Unexpected Dashboard Underutilization', runbook: 'grafana/discovery', check: 'Add links to underutilized dashboards in "Dashboard Index"' },
], y=38);

// ── Logs panel ──────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Analytics Logs', 'grafana', y=27);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Dashboard Usage Analytics')
+ g.dashboard.withUid('dashboard-usage-analytics')
+ g.dashboard.withDescription('Monitor dashboard usage patterns: view counts, user engagement, top dashboards, underutilized dashboards. Identify optimization opportunities based on user behavior.')
+ g.dashboard.withTags(['observability', 'analytics', 'usage', 'optimization', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Usage Summary') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, totalViewsStat, activeUsersStat, avgEngagementStat, topDashboardsStat,

  g.panel.row.new('📈 Usage Trends') + c.pos(0, 4, 24, 1),
  usageTrendTs, engagementTs,

  g.panel.row.new('⚡ Dashboard Performance') + c.pos(0, 13, 24, 1),
  topDashboardsTable, underutilizedTable,

  g.panel.row.new('🎯 Analytics Guide') + c.pos(0, 22, 24, 1),
  guidePanel,

  g.panel.row.new('📝 Logs') + c.pos(0, 26, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 37, 24, 1),
  troubleGuide,
])
