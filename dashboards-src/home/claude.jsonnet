local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Claude — Merged Dashboard
// Absorbs: heater/claude-code.jsonnet (sessions, cost, tokens, logs, traces)
//          claude/overview.jsonnet   (overview: proxy metrics, model breakdown, pie/bar/table)

local projectVar =
  g.dashboard.variable.query.new('project')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'project',
      'claude_session_cost_usd'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Project')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*');

local modelVar =
  g.dashboard.variable.query.new('model')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'model',
      'claude_tokens_input_total'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Model')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*');

// Extra vars used by overview section only
local sessionVar =
  g.dashboard.variable.query.new('session')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'session', 'claude_tokens_input_total'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Session')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*')
  + g.dashboard.variable.query.generalOptions.showOnDashboard.withNothing();

local intervalVar =
  g.dashboard.variable.interval.new('interval', ['1m', '5m', '15m', '30m', '1h', '3h'])
  + g.dashboard.variable.interval.generalOptions.withLabel('Interval')
  + g.dashboard.variable.interval.withAutoOption(30, '1m');

// ── heater/claude-code panels ─────────────────────────────────────────────

local cc_alertPanel = c.alertCountPanel('heater-claude-code', col=0);

local cc_sessionCostStat =
  g.panel.stat.new('Session Cost')
  + c.pos(6, 1, 9, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_session_cost_usd{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 5 },
    { color: 'red', value: 20 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local cc_contextUsedStat =
  g.panel.stat.new('Context Used %')
  + c.pos(15, 1, 9, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(claude_context_used_pct{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local cc_totalTokensStat =
  g.panel.stat.new('Tokens')
  + c.pos(0, 5, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + sum(claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local cc_cacheTokensStat =
  g.panel.stat.new('Cache Hit')
  + c.pos(4, 5, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_cache_read{project=~"$project",model=~"$model"}) / (sum(claude_tokens_cache_read{project=~"$project",model=~"$model"}) + sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + 1) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 30 },
    { color: 'green', value: 60 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local cc_linesAddedStat =
  g.panel.stat.new('Lines +/-')
  + c.pos(8, 5, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', 'added'),
    c.vmQ('sum(claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', 'removed'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local cc_apiWaitStat =
  g.panel.stat.new('API Wait (avg)')
  + c.pos(12, 5, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_duration_api_seconds{project=~"$project",model=~"$model"}) / sum(claude_prompt_count{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 10 },
    { color: 'red', value: 30 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local cc_mcpLatencyStat =
  g.panel.stat.new('MCP P95')
  + c.pos(16, 5, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.swQ(
      'histogram_quantile(0.95, sum by(le) (rate(meter_service_resp_time_bucket{service="mcp-vanguard"}[5m]))) or vector(0)',
      'p95'
    ),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.latencyThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local cc_linesRemovedStat =
  g.panel.stat.new('Lines Removed')
  + c.pos(20, 5, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local cc_tokensTs =
  g.panel.timeSeries.new('Token Usage (Input vs Output)')
  + c.pos(0, 9, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_input_total{project=~"$project",model=~"$model"}) or vector(0)', 'input {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', 'output {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cc_costTs =
  g.panel.timeSeries.new('Session Cost by Project')
  + c.pos(12, 9, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_session_cost_usd{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cc_cacheTs =
  g.panel.timeSeries.new('Cache Tokens (Read vs Write)')
  + c.pos(0, 18, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_cache_read{project=~"$project",model=~"$model"}) or vector(0)', 'read {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_cache_write{project=~"$project",model=~"$model"}) or vector(0)', 'write {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cc_tokensByModelTs =
  g.panel.timeSeries.new('Token Usage by Model')
  + c.pos(12, 18, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (model) (claude_tokens_input_total{project=~"$project",model=~"$model"} + claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', '{{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cc_apiWaitTs =
  g.panel.timeSeries.new('API Wait (avg/request) vs MCP Latency')
  + c.pos(0, 27, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(claude_duration_api_seconds{project=~"$project",model=~"$model"}) / sum(claude_prompt_count{project=~"$project",model=~"$model"}) or vector(0)', 'API wait avg (Claude)'),
    c.swQ(
      'avg(rate(meter_service_resp_time_sum{service="mcp-vanguard"}[5m]) / rate(meter_service_resp_time_count{service="mcp-vanguard"}[5m])) / 1000 or vector(0)',
      'MCP avg latency'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cc_contextTs =
  g.panel.timeSeries.new('Context Window Usage')
  + c.pos(12, 27, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('max by (project) (claude_context_used_pct{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cc_linesTs =
  g.panel.timeSeries.new('Lines Added / Removed')
  + c.pos(0, 36, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', '+added {{project}}'),
    c.vmQ('-sum by (project) (claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', '-removed {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cc_logVolumeTs =
  g.panel.timeSeries.new('Log Volume by Service')
  + c.pos(12, 36, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vlogsStatsQ('service:claude-code | stats count() as claude_code'),
    c.vlogsStatsQ('service:claude-code-debug | stats count() as debug'),
    c.vlogsStatsQ('service:mitmproxy-claude | stats count() as mitmproxy'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cc_sessionLogsPanel =
  c.serviceLogsPanel('Session Logs (claude-code)', 'claude-code', host='heater', y=0);

local cc_debugLogsPanel =
  g.panel.logs.new('Debug Logs (claude-code-debug)')
  + c.pos(0, 10, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="claude-code-debug"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local cc_trafficLogsPanel =
  g.panel.logs.new('HTTP Traffic (mitmproxy)')
  + c.pos(0, 20, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="mitmproxy-claude"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local cc_troubleGuide = c.serviceTroubleshootingGuide('claude-code', [
  { symptom: 'High Session Cost', runbook: 'claude-code/cost-optimization', check: 'Check Session Cost stat and review Token Usage trends by project' },
  { symptom: 'Context Window Full', runbook: 'claude-code/context-strategy', check: 'Monitor Context Used % and review prompt sizes in logs' },
  { symptom: 'API Latency Spike', runbook: 'claude-code/api-delay', check: 'Compare API Wait Time vs MCP Latency to isolate bottleneck' },
  { symptom: 'Low Cache Hit Rate', runbook: 'claude-code/cache-tuning', check: 'Check Cache Hit stat and Cache Tokens chart for read/write ratio' },
  { symptom: 'MCP Vanguard Slow', runbook: 'claude-code/mcp-debug', check: 'Check MCP P95 stat and SkyWalking traces for mcp-vanguard' },
  { symptom: 'Session Failures', runbook: 'claude-code/error-recovery', check: 'Review HTTP Traffic logs for 4xx/5xx and Debug Logs for errors' },
], y=0);

// claudeCodePanels: row at y=0, last collapsed rows at y=46,47,48,49 h=1 → height=50
local claudeCodePanels = [
  g.panel.row.new('Claude Code') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  cc_alertPanel, cc_sessionCostStat, cc_contextUsedStat,

  g.panel.row.new('Details') + c.pos(0, 6, 24, 1),
  cc_totalTokensStat, cc_cacheTokensStat, cc_linesAddedStat, cc_apiWaitStat, cc_mcpLatencyStat, cc_linesRemovedStat,

  g.panel.row.new('Usage Trends') + c.pos(0, 10, 24, 1),
  cc_tokensTs, cc_costTs,

  g.panel.row.new('Cache & Models') + c.pos(0, 19, 24, 1),
  cc_cacheTs, cc_tokensByModelTs,

  g.panel.row.new('Performance') + c.pos(0, 28, 24, 1),
  cc_apiWaitTs, cc_contextTs,

  g.panel.row.new('Activity') + c.pos(0, 37, 24, 1),
  cc_linesTs, cc_logVolumeTs,

  (g.panel.row.new('Session Logs') + c.pos(0, 46, 24, 1) + { collapsed: true, panels: [cc_sessionLogsPanel] }),
  (g.panel.row.new('Debug Logs')   + c.pos(0, 47, 24, 1) + { collapsed: true, panels: [cc_debugLogsPanel] }),
  (g.panel.row.new('HTTP Traffic') + c.pos(0, 48, 24, 1) + { collapsed: true, panels: [cc_trafficLogsPanel] }),

  (g.panel.row.new('Troubleshooting') + c.pos(0, 49, 24, 1) + { collapsed: true, panels: [cc_troubleGuide] }),
];

// claudeCodeHeight = 50 (last panel at y=49 h=1)
local claudeCodeHeight = 50;

// ── claude/overview panels ────────────────────────────────────────────────

local ov_sessionCostStat =
  g.panel.stat.new('Session Cost')
  + c.pos(0, 3, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_session_cost_usd{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 5 },
    { color: 'red', value: 20 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local ov_contextUsedStat =
  g.panel.stat.new('Context Used %')
  + c.pos(3, 3, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(claude_context_used_pct{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local ov_totalTokensStat =
  g.panel.stat.new('Tokens (in+out)')
  + c.pos(6, 3, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + sum(claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local ov_cacheHitStat =
  g.panel.stat.new('Cache Hit %')
  + c.pos(9, 3, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_cache_read{project=~"$project",model=~"$model"}) / (sum(claude_tokens_cache_read{project=~"$project",model=~"$model"}) + sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + 1) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 30 },
    { color: 'green', value: 60 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local ov_linesNetStat =
  g.panel.stat.new('Lines +/-')
  + c.pos(12, 3, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', 'added'),
    c.vmQ('sum(claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', 'removed'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local ov_apiWaitStat =
  g.panel.stat.new('API Wait (avg)')
  + c.pos(15, 3, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_duration_api_seconds{project=~"$project",model=~"$model"}) / sum(claude_prompt_count{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 10 },
    { color: 'red', value: 30 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local ov_proxyTokensInStat =
  g.panel.stat.new('Proxy Tokens In')
  + c.pos(18, 3, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(increase(claude_proxy_tokens_input_total[$__range])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local ov_proxyLatencyStat =
  g.panel.stat.new('Proxy Latency')
  + c.pos(21, 3, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('avg(claude_proxy_duration_ms) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.latencyThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local ov_tokensTs =
  g.panel.timeSeries.new('Token Usage (Input vs Output)')
  + c.pos(0, 6, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_input_total{project=~"$project",model=~"$model"}) or vector(0)', 'input {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', 'output {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_cacheTs =
  g.panel.timeSeries.new('Cache Tokens (Read vs Write)')
  + c.pos(12, 6, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_cache_read{project=~"$project",model=~"$model"}) or vector(0)', 'read {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_cache_write{project=~"$project",model=~"$model"}) or vector(0)', 'write {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_costByProjectTs =
  g.panel.timeSeries.new('Cost by Project')
  + c.pos(0, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_session_cost_usd{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_tokensByProjectTs =
  g.panel.timeSeries.new('Tokens by Project')
  + c.pos(12, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_input_total{project=~"$project",model=~"$model"} + claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_apiDurationTs =
  g.panel.timeSeries.new('API Duration over Time')
  + c.pos(0, 22, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_duration_api_seconds{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_contextTs =
  g.panel.timeSeries.new('Context Window Usage')
  + c.pos(12, 22, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('max by (project) (claude_context_used_pct{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_linesTs =
  g.panel.timeSeries.new('Lines Added / Removed')
  + c.pos(0, 30, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', '+added {{project}}'),
    c.vmQ('-sum by (project) (claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', '-removed {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_proxyTokensTs =
  g.panel.timeSeries.new('Proxy Token Usage by Model')
  + c.pos(12, 30, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (model) (rate(claude_proxy_tokens_input_total[$interval])) or vector(0)', 'in {{model}}'),
    c.vmQ('sum by (model) (rate(claude_proxy_tokens_output_total[$interval])) or vector(0)', 'out {{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_proxyLatencyTs =
  g.panel.timeSeries.new('Proxy Latency by Model')
  + c.pos(0, 38, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('avg by (model) (claude_proxy_duration_ms) or vector(0)', '{{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local ov_tokensByModelPie =
  g.panel.pieChart.new('Tokens by Model')
  + c.pos(0, 46, 8, 8)
  + g.panel.pieChart.queryOptions.withTargets([
    c.vmQ('sum by (model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range]) + last_over_time(claude_tokens_output_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{model}}'),
  ])
  + g.panel.pieChart.options.withPieType('donut')
  + g.panel.pieChart.options.withDisplayLabels(['name', 'percent']);

local ov_costByModelBar =
  g.panel.barChart.new('Cost by Model')
  + c.pos(8, 46, 8, 8)
  + g.panel.barChart.queryOptions.withTargets([
    c.vmQ('sum by (model) (last_over_time(claude_session_cost_usd{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{model}}'),
  ])
  + g.panel.barChart.standardOptions.withUnit('currencyUSD');

local ov_modelShareBar =
  g.panel.barChart.new('Model Share % by Project')
  + c.pos(16, 46, 8, 8)
  + g.panel.barChart.queryOptions.withTargets([
    c.vmQ('sum by (project, model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{project}} / {{model}}'),
  ])
  + g.panel.barChart.standardOptions.withUnit('short');

local ov_tokenBreakdownTable =
  g.panel.table.new('Token Breakdown: Project x Model')
  + c.pos(0, 54, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('sum by (project, model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range]) + last_over_time(claude_tokens_output_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{project}} / {{model}}'),
  ])
  + g.panel.table.standardOptions.withUnit('short');

local ov_sessionLogsPanel =
  c.serviceLogsPanel('Session Logs (claude-code)', 'claude-code', host='heater', y=0);

local ov_debugLogsPanel =
  g.panel.logs.new('Debug Logs (claude-code-debug)')
  + c.pos(0, 10, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="claude-code-debug"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local ov_trafficLogsPanel =
  g.panel.logs.new('HTTP Traffic (mitmproxy)')
  + c.pos(0, 20, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="mitmproxy-claude"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// overview panels: row at y=0, last collapsed rows at y=62,63,64 h=1 → height=65
local claudeOverviewPanels = [
  g.panel.row.new('Claude Overview') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  ov_sessionCostStat, ov_contextUsedStat, ov_totalTokensStat, ov_cacheHitStat,
  ov_linesNetStat, ov_apiWaitStat, ov_proxyTokensInStat, ov_proxyLatencyStat,

  ov_tokensTs, ov_cacheTs,
  ov_costByProjectTs, ov_tokensByProjectTs,
  ov_apiDurationTs, ov_contextTs,
  ov_linesTs, ov_proxyTokensTs,
  ov_proxyLatencyTs,

  ov_tokensByModelPie, ov_costByModelBar, ov_modelShareBar,
  ov_tokenBreakdownTable,

  (g.panel.row.new('Session Logs') + c.pos(0, 62, 24, 1) + { collapsed: true, panels: [ov_sessionLogsPanel] }),
  (g.panel.row.new('Debug Logs')   + c.pos(0, 63, 24, 1) + { collapsed: true, panels: [ov_debugLogsPanel] }),
  (g.panel.row.new('HTTP Traffic') + c.pos(0, 64, 24, 1) + { collapsed: true, panels: [ov_trafficLogsPanel] }),
];

// ── Dashboard ─────────────────────────────────────────────────────────────

g.dashboard.new('Claude')
+ g.dashboard.withUid('home-claude')
+ g.dashboard.withDescription('Claude Code sessions, token cost, context, logs, and traces. Merged from heater/claude-code and claude/overview.')
+ g.dashboard.withTags(['claude', 'ai', 'heater'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.swDsVar, projectVar, modelVar, sessionVar, intervalVar, c.vmAdhocVar, c.vlogsAdhocVar])
+ g.dashboard.withPanels(
    c.withYOffset(claudeCodePanels, 0)
    + c.withYOffset(claudeOverviewPanels, claudeCodeHeight)
  )
