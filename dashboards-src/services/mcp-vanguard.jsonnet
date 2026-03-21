local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// mcp_vanguard exposes metrics on :9196/metrics (Prometheus format).
// Key metrics:
//   mcp_vanguard_requests_total{tool,status}            — tool call outcomes
//   mcp_vanguard_request_duration_seconds{tool}         — per-tool duration histogram
//   mcp_vanguard_anthropic_tokens_total{type,model}     — tokens consumed by Anthropic API

local alertPanel = c.alertCountPanel('mcp-vanguard', col=0);

local totalCallsStat =
  g.panel.stat.new('Requests (1h)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(mcp_vanguard_requests_total[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local successRateStat =
  g.panel.stat.new('Success Rate (15m)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(
      '(sum(rate(mcp_vanguard_requests_total{status="ok"}[15m])) / sum(rate(mcp_vanguard_requests_total[15m]))) or vector(1)',
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

local totalTokensStat =
  g.panel.stat.new('Tokens Consumed (1h)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(mcp_vanguard_anthropic_tokens_total[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local requestRateTs =
  g.panel.timeSeries.new('Request Rate by Status')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(mcp_vanguard_requests_total[5m])', '{{tool}} / {{status}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local latencyTs =
  g.panel.timeSeries.new('Request Latency p50 / p95 / p99 (seconds)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'histogram_quantile(0.50, sum by(le, tool) (rate(mcp_vanguard_request_duration_seconds_bucket[5m])))',
      'p50 {{tool}}'
    ),
    c.vmQ(
      'histogram_quantile(0.95, sum by(le, tool) (rate(mcp_vanguard_request_duration_seconds_bucket[5m])))',
      'p95 {{tool}}'
    ),
    c.vmQ(
      'histogram_quantile(0.99, sum by(le, tool) (rate(mcp_vanguard_request_duration_seconds_bucket[5m])))',
      'p99 {{tool}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tokensTs =
  g.panel.timeSeries.new('Anthropic Tokens / min (by type and model)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(mcp_vanguard_anthropic_tokens_total[5m]) * 60', '{{type}} / {{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local errorRateTs =
  g.panel.timeSeries.new('Error Rate %')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(sum(rate(mcp_vanguard_requests_total{status="error"}[5m])) / sum(rate(mcp_vanguard_requests_total[5m]))) * 100 or vector(0)',
      'error %'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.options.tooltip.withMode('single');

local logsPanel =
  c.serviceLogsPanel('mcp-vanguard Logs', 'mcp_vanguard');

local troubleGuide = c.serviceTroubleshootingGuide('mcp-vanguard', [
  { symptom: 'No metrics', runbook: 'mcp-vanguard/down', check: 'Dashboard empty = service not running; check port 9196 and service status' },
  { symptom: 'Authentication failures', runbook: 'mcp-vanguard/auth', check: 'Check API key file at configured path or ANTHROPIC_API_KEY env' },
  { symptom: 'High latency / timeouts', runbook: 'mcp-vanguard/latency', check: '"Request Latency p95/p99" — default timeout is 30s' },
  { symptom: 'High error rate', runbook: 'mcp-vanguard/errors', check: '"Error Rate %" above 1% — check logs for error type' },
  { symptom: 'Rate limit errors (429)', runbook: 'mcp-vanguard/rate-limits', check: 'Reduce request frequency or upgrade Anthropic plan' },
], y=35);

g.dashboard.new('Services — mcp_vanguard')
+ g.dashboard.withUid('services-mcp-vanguard')
+ g.dashboard.withDescription('mcp_vanguard: MCP fast model tool — request rates, latency, Anthropic token consumption.')
+ g.dashboard.withTags(['services', 'mcp-vanguard', 'mcp', 'anthropic'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, totalCallsStat, successRateStat, totalTokensStat,
  g.panel.row.new('⚡ Request Activity') + c.pos(0, 6, 24, 1),
  requestRateTs, latencyTs,
  g.panel.row.new('🤖 Anthropic API') + c.pos(0, 14, 24, 1),
  tokensTs, errorRateTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  troubleGuide,
])
