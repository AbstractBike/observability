local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Temporal auto-setup exposes server-side metrics (no temporal_ prefix):
//   service_requests, service_latency_*, service_error_with_type,
//   approximate_backlog_count, poll_latency_*
// The temporal_* prefixed metrics are SDK/worker-side metrics.

local workflowStartStat =
  g.panel.stat.new('Workflow Starts/sec')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(service_requests{operation="StartWorkflowExecution",service_name="frontend",job="temporal"}[5m]))'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps');

local taskQueueStat =
  g.panel.stat.new('Task Queue Backlog')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(approximate_backlog_count{job="temporal"})'),
  ]);

local schedLatStat =
  g.panel.stat.new('Schedule-to-Start Latency')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.99, rate(poll_latency_bucket{job="temporal"}[5m])) * 1000'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms');

local errorStat =
  g.panel.stat.new('Service Errors/sec')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(service_error_with_type{job="temporal"}[5m]))'),
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

g.dashboard.new('Services — Temporal')
+ g.dashboard.withUid('services-temporal')
+ g.dashboard.withDescription('Temporal workflow starts, completions, task queue depth, latency.')
+ g.dashboard.withTags(['services', 'temporal'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  workflowStartStat, taskQueueStat, schedLatStat, errorStat,
  g.panel.row.new('Workflows & Latency') + c.pos(0, 4, 24, 1),
  workflowTs, latTs,
  g.panel.row.new('Logs') + c.pos(0, 12, 24, 1),
  logsPanel,
])
