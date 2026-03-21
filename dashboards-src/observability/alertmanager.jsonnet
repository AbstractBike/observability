local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local alertPanel = c.alertCountPanel('alertmanager', col=0);

local receivedStat =
  g.panel.stat.new('Alerts Received/sec')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(alertmanager_alerts_received_total[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local firedStat =
  g.panel.stat.new('Notifications Sent/sec')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(alertmanager_notifications_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local failedStat =
  g.panel.stat.new('Failed Notifications/sec')
  + c.pos(14, 1, 5, 3)
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

// 5-stat layout: alert(6) + received(4) + fired(4) + failed(5) + silences(5) = 24
local silencesStat =
  g.panel.stat.new('Active Silences')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(alertmanager_silences{state="active"}) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

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

local logsPanel = c.serviceLogsPanel('Alertmanager Logs', 'alertmanager', y=15);

local troubleGuide = c.serviceTroubleshootingGuide('alertmanager', [
  { symptom: 'Notification Failures', runbook: 'alertmanager/notification-failures', check: '"Failed Notifications/sec" > 0 — check receiver config (email, webhook)' },
  { symptom: 'Alert Pipeline Backlog', runbook: 'alertmanager/alert-backlog', check: '"Alerts in Pipeline" — high suppressed count = silences or inhibit rules' },
  { symptom: 'High Alert Volume', runbook: 'alertmanager/volume', check: '"Alerts Received/sec" high — check VMAlert rules for over-sensitive thresholds' },
  { symptom: 'Silences Not Working', runbook: 'alertmanager/silences', check: '"Active Silences" = 0 but alerts still suppressed? Check expiry dates' },
], y=26);

g.dashboard.new('Observability — Alertmanager')
+ g.dashboard.withUid('observability-alertmanager')
+ g.dashboard.withDescription('Alertmanager: notifications sent/failed, silences, alert pipeline.')
+ g.dashboard.withTags(['observability', 'alertmanager', 'alerting', 'critical', 'infrastructure'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, receivedStat, firedStat, failedStat, silencesStat,
  g.panel.row.new('⚠️ Alert Routing') + c.pos(0, 6, 24, 1),
  notifTs, alertsTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 14, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 25, 24, 1),
  troubleGuide,
])
