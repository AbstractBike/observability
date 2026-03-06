local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Vector internal_metrics metric names:
// vector_component_received_events_total{component_id, component_type, component_kind, host}
// vector_component_sent_events_total{component_id, component_type, component_kind, host}
// vector_component_errors_total{component_id, component_type, component_kind, error_type, host}
// vector_uptime_seconds{host}
// vector_processed_bytes_total{component_id, host}

local hostVar =
  g.dashboard.variable.custom.new('host', [
    { key: 'All', value: '.*' },
    { key: 'heater', value: 'heater' },
    { key: 'homelab', value: 'homelab' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Host')
  + g.dashboard.variable.custom.generalOptions.withCurrent('heater', 'heater');

local alertPanel = c.alertCountPanel('vector', col=0);

local uptimeStat =
  g.panel.stat.new('Vector Uptime')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(vector_uptime_seconds{host=~"$host"}) or vector(0)', '{{host}}'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local eventsInStat =
  g.panel.stat.new('Events In/sec')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_received_events_total{host=~"$host"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local eventsOutStat =
  g.panel.stat.new('Events Out/sec')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_sent_events_total{host=~"$host"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local errorRateStat =
  g.panel.stat.new('Error Rate')
  + c.statPos(4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_errors_total{host=~"$host"}[5m])) or vector(0)'),
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
      'topk(10, (rate(vector_component_received_events_total{host=~"$host"}[5m]) or vector(0)))',
      '{{host}} · {{component_id}} ({{component_type}})'
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
      'topk(10, (rate(vector_component_sent_events_total{host=~"$host"}[5m]) or vector(0)))',
      '{{host}} · {{component_id}} ({{component_type}})'
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
      '(rate(vector_component_errors_total{host=~"$host"}[5m]) or vector(0))',
      '{{host}} · {{component_id}} — {{error_type}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local bytesTs =
  g.panel.timeSeries.new('Bytes Processed per Component')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (rate(vector_component_sent_bytes_total{host=~"$host"}[5m]) or vector(0)))',
      '{{host}} · {{component_id}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel =
  g.panel.logs.new('Vector Service Logs')
  + c.logPos(21)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host=~"$host",service="vector"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('vector', [
  { symptom: 'Vector Down', runbook: 'vector/not-running', check: 'Verify Vector Uptime stat and check service logs' },
  { symptom: 'Events Backlog', runbook: 'vector/backpressure', check: 'Compare Events In/sec vs Out/sec - check for buffering' },
  { symptom: 'High Error Rate', runbook: 'vector/errors', check: 'Review Error Rate stat and "Errors & Bytes" trends' },
  { symptom: 'Data Loss', runbook: 'vector/data-loss', check: 'Check processed bytes and component error logs' },
], y=18);

g.dashboard.new('Pipeline — Vector')
+ g.dashboard.withUid('pipeline-vector')
+ g.dashboard.withDescription('Vector observability pipeline metrics: events in/out, errors and component health for both heater and homelab hosts.')
+ g.dashboard.withTags(['pipeline', 'vector', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, hostVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, uptimeStat, eventsInStat, eventsOutStat, errorRateStat,
  g.panel.row.new('📤 Throughput') + c.pos(0, 4, 24, 1),
  eventsTs, eventsOutTs,
  g.panel.row.new('⚠️ Errors & Bytes') + c.pos(0, 12, 24, 1),
  errorsTs, bytesTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 17, 24, 1),
  troubleGuide,
  g.panel.row.new('📝 Logs') + c.pos(0, 25, 24, 1),
  logsPanel,
])
