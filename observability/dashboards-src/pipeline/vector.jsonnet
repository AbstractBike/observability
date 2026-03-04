local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Vector internal_metrics metric names:
// vector_component_received_events_total{component_id, component_type, component_kind}
// vector_component_sent_events_total{component_id, component_type, component_kind}
// vector_component_errors_total{component_id, component_type, component_kind, error_type}
// vector_uptime_seconds{host}
// vector_processed_bytes_total{component_id}

local uptimeStat =
  g.panel.stat.new('Vector Uptime')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('vector_uptime_seconds{host="heater"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local eventsInStat =
  g.panel.stat.new('Events In/sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_received_events_total{host="heater"}[5m]))'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local eventsOutStat =
  g.panel.stat.new('Events Out/sec')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_sent_events_total{host="heater"}[5m]))'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local errorRateStat =
  g.panel.stat.new('Error Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_errors_total{host="heater"}[5m]))'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 0.01 },
    { color: 'red', value: 0.1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local eventsTs =
  g.panel.timeSeries.new('Events per Component (In)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(vector_component_received_events_total{host="heater"}[5m])',
      '{{component_id}} ({{component_type}})'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local eventsOutTs =
  g.panel.timeSeries.new('Events per Component (Out)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(vector_component_sent_events_total{host="heater"}[5m])',
      '{{component_id}} ({{component_type}})'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local errorsTs =
  g.panel.timeSeries.new('Errors per Component')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(vector_component_errors_total{host="heater"}[5m])',
      '{{component_id}} — {{error_type}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local bytesTs =
  g.panel.timeSeries.new('Bytes Processed per Component')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(vector_component_sent_bytes_total{host="heater"}[5m])',
      '{{component_id}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel =
  g.panel.logs.new('Vector Service Logs')
  + c.logPos(21)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater"} | _msg:~"(vector|Vector)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true);

g.dashboard.new('Pipeline — Vector')
+ g.dashboard.withUid('pipeline-vector')
+ g.dashboard.withDescription('Vector observability pipeline metrics: events in/out, errors and component health.')
+ g.dashboard.withTags(['pipeline', 'vector'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Stats') + c.pos(0, 0, 24, 1),
  uptimeStat, eventsInStat, eventsOutStat, errorRateStat,
  g.panel.row.new('Throughput') + c.pos(0, 4, 24, 1),
  eventsTs, eventsOutTs,
  g.panel.row.new('Errors & Bytes') + c.pos(0, 12, 24, 1),
  errorsTs, bytesTs,
  g.panel.row.new('Logs') + c.pos(0, 20, 24, 1),
  logsPanel,
])
