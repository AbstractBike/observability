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
  + c.pos(0, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + sum(claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local cc_cacheTokensStat =
  g.panel.stat.new('Cache Hit')
  + c.pos(6, 5, 6, 3)
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
  + c.pos(12, 5, 6, 3)
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
  + c.pos(18, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(claude_duration_api_seconds{project=~"$project",model=~"$model"}[$__range]) / increase(claude_prompt_count{project=~"$project",model=~"$model"}[$__range]) or vector(0)'),
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

// ── Token Economy panels ────────────────────────────────────────────────

local te_costPerLineStat =
  g.panel.stat.new('$/Net Line')
  + c.pos(0, 46, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_session_cost_usd{project=~"$project"}) / clamp_min(sum(claude_lines_added{project=~"$project"}) - sum(claude_lines_removed{project=~"$project"}), 1)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(3)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 0.05 },
    { color: 'red', value: 0.20 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local te_cacheSavingsStat =
  g.panel.stat.new('Cache Savings $')
  + c.pos(6, 46, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_cache_read{project=~"$project"}) * 0.00000030'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local te_efficiencyByModelStat =
  g.panel.stat.new('Opus $/Line')
  + c.pos(12, 46, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_session_cost_usd{model=~".*opus.*"}) / clamp_min(sum(claude_lines_added{model=~".*opus.*"}), 1)', 'Opus'),
    c.vmQ('sum(claude_session_cost_usd{model=~".*sonnet.*"}) / clamp_min(sum(claude_lines_added{model=~".*sonnet.*"}), 1)', 'Sonnet'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(3)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local te_tokenBudgetStat =
  g.panel.stat.new('Total Spend')
  + c.pos(18, 46, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_session_cost_usd)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 50 },
    { color: 'red', value: 200 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local te_costPerLineTs =
  g.panel.timeSeries.new('Cost per Line by Project')
  + c.pos(0, 49, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_session_cost_usd{project=~"$project"}) / clamp_min(sum by (project) (claude_lines_added{project=~"$project"}), 1)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local te_cacheEconomicsTs =
  g.panel.timeSeries.new('Cache Savings vs Actual Spend')
  + c.pos(12, 49, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_cache_read{project=~"$project"}) * 0.00000030', 'Saved (cache reads)'),
    c.vmQ('sum(claude_session_cost_usd{project=~"$project"})', 'Spent (actual)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
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

// claudeCodePanels: row at y=0, last collapsed rows at y=57,58,59,60 h=1 → height=61
local claudeCodePanels = [
  g.panel.row.new('Claude Code') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  cc_alertPanel, cc_sessionCostStat, cc_contextUsedStat,

  g.panel.row.new('Details') + c.pos(0, 6, 24, 1),
  cc_totalTokensStat, cc_cacheTokensStat, cc_linesAddedStat, cc_apiWaitStat,

  g.panel.row.new('Usage Trends') + c.pos(0, 10, 24, 1),
  cc_tokensTs, cc_costTs,

  g.panel.row.new('Cache & Models') + c.pos(0, 19, 24, 1),
  cc_cacheTs, cc_tokensByModelTs,

  g.panel.row.new('Performance') + c.pos(0, 28, 24, 1),
  cc_apiWaitTs, cc_contextTs,

  g.panel.row.new('Activity') + c.pos(0, 37, 24, 1),
  cc_linesTs, cc_logVolumeTs,

  g.panel.row.new('💰 Token Economy') + c.pos(0, 45, 24, 1),
  te_costPerLineStat, te_cacheSavingsStat, te_efficiencyByModelStat, te_tokenBudgetStat,
  te_costPerLineTs, te_cacheEconomicsTs,

  (g.panel.row.new('Session Logs') + c.pos(0, 57, 24, 1) + { collapsed: true, panels: [cc_sessionLogsPanel] }),
  (g.panel.row.new('Debug Logs')   + c.pos(0, 58, 24, 1) + { collapsed: true, panels: [cc_debugLogsPanel] }),
  (g.panel.row.new('HTTP Traffic') + c.pos(0, 59, 24, 1) + { collapsed: true, panels: [cc_trafficLogsPanel] }),

  (g.panel.row.new('Troubleshooting') + c.pos(0, 60, 24, 1) + { collapsed: true, panels: [cc_troubleGuide] }),
];

// claudeCodeHeight = 50 (last panel at y=49 h=1)
local claudeCodeHeight = 61;

// ── Dashboard ─────────────────────────────────────────────────────────────

g.dashboard.new('Claude')
+ g.dashboard.withUid('home-claude')
+ g.dashboard.withDescription('Claude Code sessions, token cost, context, logs, and traces. Merged from heater/claude-code and claude/overview.')
+ g.dashboard.withTags(['claude', 'ai', 'heater'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, projectVar, modelVar, c.vmAdhocVar, c.vlogsAdhocVar])
+ g.dashboard.withPanels(
    c.withYOffset(claudeCodePanels, 0)
  )
