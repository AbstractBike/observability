local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local alertPanel = c.alertCountPanel('alertmanager', col=0);

local receivedStat =
  g.panel.stat.new('Alerts Received/sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(alertmanager_alerts_received_total[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local firedStat =
  g.panel.stat.new('Notifications Sent/sec')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(alertmanager_notifications_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local failedStat =
  g.panel.stat.new('Failed Notifications/sec')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(alertmanager_notifications_failed_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 0.01 },
  ])
  + g.panel.stat.options.withColorMode('background');

local silencesStat =
  g.panel.stat.new('Active Silences')
  + c.statPos(4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(alertmanager_silences{state="active"}) or vector(0)'),
  ]);

local notifTs =
  g.panel.timeSeries.new('Notifications by Receiver')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(rate(alertmanager_notifications_total[5m]) or vector(0))', '{{receiver}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local alertsTs =
  g.panel.timeSeries.new('Alerts in Pipeline')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(alertmanager_alerts{state="active"}) or vector(0)', 'active'),
    c.vmQ('(alertmanager_alerts{state="suppressed"}) or vector(0)', 'suppressed'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel = c.serviceLogsPanel('Alertmanager Logs', 'alertmanager', y=13);

local troubleGuide = c.serviceTroubleshootingGuide('alertmanager', [
  { symptom: 'Notification Failures', runbook: 'alertmanager/notification-failures', check: 'Check "Failed Notifications/sec" stat' },
  { symptom: 'Alert Pipeline Backlog', runbook: 'alertmanager/alert-backlog', check: 'Monitor "Alerts in Pipeline" active vs suppressed' },
  { symptom: 'High Alert Volume', runbook: 'alertmanager/volume', check: 'Check "Alerts Received/sec" and routing config' },
  { symptom: 'Silences Not Working', runbook: 'alertmanager/silences', check: 'Verify active silences in "Active Silences" stat' },
], y=14);

g.dashboard.new('Observability — Alertmanager')
+ g.dashboard.withUid('observability-alertmanager')
+ g.dashboard.withDescription('Alertmanager: notifications sent/failed, silences, alert pipeline.')
+ g.dashboard.withTags(['observability', 'alertmanager', 'alerting', 'critical', 'infrastructure'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, receivedStat, firedStat, failedStat, silencesStat,
  g.panel.row.new('⚠️ Alert Routing') + c.pos(0, 4, 24, 1),
  notifTs, alertsTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 12, 24, 1),
  troubleGuide,
  g.panel.row.new('📝 Logs') + c.pos(0, 19, 24, 1),
  logsPanel,
])
