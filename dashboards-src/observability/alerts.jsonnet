// Alerts Dashboard
//
// Consolidated view of all active and recent alerts.
// Provides quick visibility into system alerting status.

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Alert Stats ────────────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('alertmanager', col=0);

local activeAlertsStat =
  g.panel.stat.new('🚨 Grafana Alerts')
  + c.pos(6, 1, 4, 3)
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
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(alertmanager_notifications_total{job="alertmanager"}[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

// 5-stat layout: alert(6) + activeAlerts(4) + fired(4) + amUp(5) + vmAlertUp(5) = 24
local alertmanagerUpStat =
  g.panel.stat.new('Alertmanager')
  + c.pos(14, 1, 5, 3)
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
  + c.pos(19, 1, 5, 3)
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
  g.panel.text.new('🔔 Alerting System & Related Dashboards')
  + c.pos(0, 14, 24, 4)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### 📊 Related Dashboards
    - **[VMAlert](/d/observability-vmalert)** — Rule evaluation and alert processing
    - **[Alertmanager](/d/observability-alertmanager)** — Alert routing and grouping
    - **[Services Health](/d/services-health)** — View triggered alert context
    - **[SLO Overview](/d/slo-overview)** — Track SLO breach alerts

    ### Alerting Components

    - **Grafana Alerts**: Dashboard alert rules and notifications
    - **VMAlert**: Prometheus-compatible rule engine for VictoriaMetrics
    - **Alertmanager**: Alert routing, grouping, and notifications

    ### Alert Channels
    - Email notifications
    - On-call escalation
    - Service integration via webhooks

    ### 🚀 On-Call Runbooks

    When an alert fires, follow these guides:
    - [High CPU Usage](https://wiki.pin/runbooks/infrastructure/cpu) — CPU > 85% sustained
    - [Memory Pressure](https://wiki.pin/runbooks/infrastructure/memory) — Memory > 90%
    - [Service Unhealthy](https://wiki.pin/runbooks/services/health-check-failure) — Health check failure
    - [Storage Critical](https://wiki.pin/runbooks/infrastructure/storage) — Disk > 85%
    - [High Latency](https://wiki.pin/runbooks/performance/latency-spike) — p99 > 5s

    ### Key Metrics
    1. **Active Alerts** - Current firing alerts (target: 0)
    2. **Alert Rate** - Alerts fired per hour (baseline varies)
    3. **Alertmanager Status** - System health (target: up)
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('alertmanager', [
  { symptom: 'Alerts Not Firing', runbook: 'alertmanager/no-alerts', check: 'Verify alertmanager is up and receiving alerts from VMAlert' },
  { symptom: 'Alert Spam', runbook: 'alertmanager/alert-spam', check: 'Check grouping rules and adjust thresholds in VMAlert rules' },
  { symptom: 'Notifications Not Sent', runbook: 'alertmanager/notification-failure', check: 'Monitor notification channel status and retry logs' },
  { symptom: 'Alert Rules Not Evaluating', runbook: 'alertmanager/rule-eval', check: 'Check VMAlert health and rule syntax in "Trends" panel' },
], y=30);

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Alert Logs', 'alertmanager', y=19);

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Alerts')
+ g.dashboard.withUid('alerts-dashboard')
+ g.dashboard.withDescription('Alert system monitoring: active alerts, firing rate, alertmanager status, alert history.')
+ g.dashboard.withTags(['observability', 'alerts', 'monitoring', 'health', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('🚨 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, activeAlertsStat, firedAlertsStat, alertmanagerUpStat, vmAlertUpStat,

  g.panel.row.new('📈 Trends') + c.pos(0, 4, 24, 1),
  alertRateTs, alertmanagerStatusTs,

  g.panel.row.new('ℹ️ Info') + c.pos(0, 13, 24, 1),
  infoPanel,

  g.panel.row.new('📝 Logs') + c.pos(0, 18, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 29, 24, 1),
  troubleGuide,
])
