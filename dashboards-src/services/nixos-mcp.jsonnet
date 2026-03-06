local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// nixos-mcp exposes metrics on :9110/metrics (prometheus format).
// Key metrics:
//   nixos_mcp_tool_calls_total{tool,status}        — tool call outcomes (success/failed/timeout)
//   nixos_mcp_tool_duration_seconds{tool}           — per-tool execution duration histogram
//   nixos_mcp_active_connections                    — current active MCP connections

local alertPanel = c.alertCountPanel('nixos-mcp', col=0);

local totalCallsStat =
  g.panel.stat.new('Tool Calls (1h)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(nixos_mcp_tool_calls_total[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local successRateStat =
  g.panel.stat.new('Success Rate (15m)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(
      '(sum(rate(nixos_mcp_tool_calls_total{status="success"}[15m])) / sum(rate(nixos_mcp_tool_calls_total[15m]))) or vector(1)',
    ),
  ])
  + g.panel.stat.standardOptions.withUnit('percentunit')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 0.9 },
    { color: 'green', value: 0.99 },
  ])
  + g.panel.stat.options.withColorMode('background');

local activeConnectionsStat =
  g.panel.stat.new('Active Connections')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nixos_mcp_active_connections or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local toolCallsTs =
  g.panel.timeSeries.new('Tool Calls by Tool and Status')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(nixos_mcp_tool_calls_total[5m])', '{{tool}} / {{status}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local durationTs =
  g.panel.timeSeries.new('Tool Duration p95 (seconds)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.95, sum by(le, tool) (rate(nixos_mcp_tool_duration_seconds_bucket[5m]))) or vector(0)',
      'p95 {{tool}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel =
  c.serviceLogsPanel('nixos-mcp Logs', 'nixos-mcp');

local troubleGuide = c.serviceTroubleshootingGuide('nixos-mcp', [
  { symptom: 'No metrics emitted', runbook: 'nixos-mcp/down', check: 'Check "Active Connections" stat and service status' },
  { symptom: 'Deploy failures', runbook: 'nixos-mcp/deploy-failures', check: 'Check tool calls by status — filter tool=nixos_deploy' },
  { symptom: 'High error rate', runbook: 'nixos-mcp/high-errors', check: 'Check "Success Rate" stat and logs' },
  { symptom: 'Slow tool calls', runbook: 'nixos-mcp/performance', check: 'Check "Tool Duration p95" chart' },
], y=20);

g.dashboard.new('Services — NixOS MCP')
+ g.dashboard.withUid('services-nixos-mcp')
+ g.dashboard.withDescription('NixOS MCP server: tool call rates, success rates, durations and active connections.')
+ g.dashboard.withTags(['services', 'nixos-mcp', 'mcp', 'nixos'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, totalCallsStat, successRateStat, activeConnectionsStat,
  g.panel.row.new('Tool Activity') + c.pos(0, 4, 24, 1),
  toolCallsTs, durationTs,
  g.panel.row.new('Logs') + c.pos(0, 12, 24, 1),
  logsPanel,
  g.panel.row.new('Troubleshooting') + c.pos(0, 19, 24, 1),
  troubleGuide,
])
