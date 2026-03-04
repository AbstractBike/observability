local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local firingCountStat =
  g.panel.stat.new('Firing Alerts')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(vmalert_alerts_firing)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local rulesStat =
  g.panel.stat.new('Rules Loaded')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(vmalert_alerting_rules_last_evaluation_samples) + count(vmalert_recording_rules_last_evaluation_samples) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local evalDurStat =
  g.panel.stat.new('Eval Duration p99 (ms)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    // vmalert exposes iteration_duration as a Summary (quantile labels), not a Histogram.
    c.vmQ('max(vmalert_iteration_duration_seconds{quantile="0.99"}) * 1000 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local errorStat =
  g.panel.stat.new('Eval Errors/sec')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(vmalert_execution_errors_total[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 0.01 },
  ])
  + g.panel.stat.options.withColorMode('background');

local firingTs =
  g.panel.timeSeries.new('Firing Alerts Over Time')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vmalert_alerts_firing', '{{alertname}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local evalTs =
  g.panel.timeSeries.new('Evaluation Duration (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('max(vmalert_iteration_duration_seconds{quantile="0.5"}) * 1000', 'p50'),
    c.vmQ('max(vmalert_iteration_duration_seconds{quantile="0.99"}) * 1000', 'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel = c.serviceLogsPanel('VMAlert Logs', 'vmalert', y=13);

g.dashboard.new('Observability — vmalert')
+ g.dashboard.withUid('observability-vmalert')
+ g.dashboard.withDescription('vmalert: firing alerts, rule evaluation duration, errors.')
+ g.dashboard.withTags(['observability', 'vmalert', 'alerting'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  firingCountStat, rulesStat, evalDurStat, errorStat,
  g.panel.row.new('Detail') + c.pos(0, 4, 24, 1),
  firingTs, evalTs,
  g.panel.row.new('Logs') + c.pos(0, 12, 24, 1),
  logsPanel,
])
