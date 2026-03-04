local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local receivedStat =
  g.panel.stat.new('Alerts Received/sec')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(alertmanager_alerts_received_total[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local firedStat =
  g.panel.stat.new('Notifications Sent/sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(alertmanager_notifications_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local failedStat =
  g.panel.stat.new('Failed Notifications/sec')
  + c.statPos(2)
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
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('alertmanager_silences{state="active"}'),
  ]);

local notifTs =
  g.panel.timeSeries.new('Notifications by Receiver')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(alertmanager_notifications_total[5m])', '{{receiver}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local alertsTs =
  g.panel.timeSeries.new('Alerts in Pipeline')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('alertmanager_alerts{state="active"}', 'active'),
    c.vmQ('alertmanager_alerts{state="suppressed"}', 'suppressed'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel = c.serviceLogsPanel('Alertmanager Logs', 'alertmanager', y=13);

g.dashboard.new('Observability — Alertmanager')
+ g.dashboard.withUid('observability-alertmanager')
+ g.dashboard.withDescription('Alertmanager: notifications sent/failed, silences, alert pipeline.')
+ g.dashboard.withTags(['observability', 'alertmanager', 'alerting'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  receivedStat, firedStat, failedStat, silencesStat,
  g.panel.row.new('Detail') + c.pos(0, 4, 24, 1),
  notifTs, alertsTs,
  g.panel.row.new('Logs') + c.pos(0, 12, 24, 1),
  logsPanel,
])
