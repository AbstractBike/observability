local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Temporal auto-setup exposes server-side metrics (no temporal_ prefix):
//   service_requests, service_latency_*, service_error_with_type,
//   approximate_backlog_count, poll_latency_*
// The temporal_* prefixed metrics are SDK/worker-side metrics.

local alertPanel = c.alertCountPanel('temporal', col=0);

local upStat =
  g.panel.stat.new('Temporal Up')
  + c.pos(4, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('up{job="temporal"}')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('value_and_name');

local workflowStartStat =
  g.panel.stat.new('Workflow Starts/sec')
  + c.pos(8, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(service_requests{operation="StartWorkflowExecution",service_name="frontend",job="temporal"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local taskQueueStat =
  g.panel.stat.new('Task Queue Backlog')
  + c.pos(13, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(approximate_backlog_count{job="temporal"}) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local schedLatStat =
  g.panel.stat.new('Schedule-to-Start Latency p99')
  + c.pos(18, 1, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.99, rate(poll_latency_bucket{job="temporal"}[5m])) * 1000 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local errorStat =
  g.panel.stat.new('Service Errors/sec')
  + c.pos(21, 1, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(service_error_with_type{job="temporal"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 0.1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local workflowTs =
  g.panel.timeSeries.new('Workflow Operations/sec')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(service_requests{operation="StartWorkflowExecution",service_name="frontend",job="temporal"}[5m])', 'starts'),
    c.vmQ('rate(service_requests{operation="RespondWorkflowTaskCompleted",service_name="history",job="temporal"}[5m])', 'completions'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local latTs =
  g.panel.timeSeries.new('Request Latency p99 (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.99, sum by (le, operation) (rate(service_latency_bucket{job="temporal"}[5m]))) * 1000',
      '{{operation}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel = c.serviceLogsPanel('Temporal Logs', 'temporal');

local troubleGuide = c.serviceTroubleshootingGuide('temporal', [
  { symptom: 'Service Down', runbook: 'temporal/service-down', check: 'Check "Temporal Up" stat' },
  { symptom: 'High Task Queue Backlog', runbook: 'temporal/queue-backlog', check: 'Monitor "Task Queue Backlog" stat' },
  { symptom: 'High Latency', runbook: 'temporal/latency', check: 'Check "Request Latency p99" graph' },
  { symptom: 'Service Errors', runbook: 'temporal/errors', check: 'Look at "Service Errors/sec" stat' },
], y=20);

g.dashboard.new('Services — Temporal')
+ g.dashboard.withUid('services-temporal')
+ g.dashboard.withDescription('Temporal workflow starts, completions, task queue depth, latency, and alerts.')
+ g.dashboard.withTags(['services', 'temporal', 'workflow', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, upStat, workflowStartStat, taskQueueStat, schedLatStat, errorStat,
  g.panel.row.new('⚡ Workflows & Latency') + c.pos(0, 4, 24, 1),
  workflowTs, latTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 12, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 19, 24, 1),
  troubleGuide,
])
