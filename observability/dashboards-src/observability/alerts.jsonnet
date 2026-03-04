// Alerts Dashboard
//
// Consolidated view of all active and recent alerts.
// Provides quick visibility into system alerting status.

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Alert Stats ────────────────────────────────────────────────────────────

local activeAlertsStat =
  g.panel.stat.new('🚨 Active Alerts')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('grafana_alerting_active_alerts or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local firedAlertsStat =
  g.panel.stat.new('🔔 Fired This Hour')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(alertmanager_notifications_total{job="alertmanager"}[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

local alertmanagerUpStat =
  g.panel.stat.new('Alertmanager')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('up{job="alertmanager"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name');

local vmAlertUpStat =
  g.panel.stat.new('VMAlert')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('up{job="vmalert"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name');

// ── Alert Rate Trends ──────────────────────────────────────────────────────

local alertRateTs =
  g.panel.timeSeries.new('Alerts Fired Per Hour (5m avg)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(alertmanager_notifications_total{job="alertmanager"}[5m]) * 3600',
      'Notifications/hour'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Alertmanager Status ────────────────────────────────────────────────────

local alertmanagerStatusTs =
  g.panel.timeSeries.new('Alertmanager Health')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('up{job="alertmanager"} or vector(0)', 'Up'),
    c.vmQ('(alertmanager_alerts or vector(0))', 'Total Alerts'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Alert Info ────────────────────────────────────────────────────────────

local infoPanel =
  g.panel.text.new('🔔 Alerting System')
  + c.pos(0, 9, 24, 3)
  + g.panel.text.options.withContent(|||
    ### Alerting Components

    - **Grafana Alerts**: Dashboard alert rules and notifications
    - **VMAlert**: Prometheus-compatible rule engine for VictoriaMetrics
    - **Alertmanager**: Alert routing, grouping, and notifications

    ### Alert Channels

    - Email notifications
    - On-call escalation
    - Service integration via webhooks

    ### Key Metrics

    1. **Active Alerts** - Current firing alerts (target: 0)
    2. **Alert Rate** - Alerts fired per hour (baseline varies)
    3. **Alertmanager Status** - System health (target: up)

    See [DASHBOARD-RUNBOOK.md](./DASHBOARD-RUNBOOK.md) for alert troubleshooting.
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Alert Logs', 'alertmanager', y=12);

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Alerts')
+ g.dashboard.withUid('alerts-dashboard')
+ g.dashboard.withDescription('Alert system monitoring: active alerts, firing rate, alertmanager status, alert history.')
+ g.dashboard.withTags(['observability', 'alerts', 'monitoring', 'health'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  activeAlertsStat, firedAlertsStat, alertmanagerUpStat, vmAlertUpStat,

  g.panel.row.new('Trends') + c.pos(0, 4, 24, 1),
  alertRateTs, alertmanagerStatusTs,

  g.panel.row.new('Info') + c.pos(0, 8, 24, 1),
  infoPanel,

  g.panel.row.new('Logs') + c.pos(0, 11, 24, 1),
  logsPanel,
])
