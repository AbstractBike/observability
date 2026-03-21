local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Claude — Overview
// Merged from: claude/metrics.json, dashboards_new/claude-proxy-dashboard.json
// Dropped (0 series): claude/chat-*.json (claude_chat_* not deployed), SkyWalking traces
// Logs: heater-scoped — Claude Code runs exclusively on the heater machine

local projectVar =
  g.dashboard.variable.query.new('project')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'project', 'claude_session_cost_usd'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Project')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*');

local modelVar =
  g.dashboard.variable.query.new('model')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'model', 'claude_tokens_input_total'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Model')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*');

local sessionVar =
  g.dashboard.variable.query.new('session')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'session', 'claude_tokens_input_total'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Session')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*');

local intervalVar =
  g.dashboard.variable.interval.new('interval', ['1m', '5m', '15m', '30m', '1h', '3h'])
  + g.dashboard.variable.interval.generalOptions.withLabel('Interval')
  + g.dashboard.variable.interval.withAutoOption(30, '1m');

// Datasource vars hidden from the bar — still functional via $datasource/$vlogs
local hiddenVmDs   = c.vmDsVar   + g.dashboard.variable.datasource.generalOptions.showOnDashboard.withNothing();
local hiddenVlogsDs = c.vlogsDsVar + g.dashboard.variable.datasource.generalOptions.showOnDashboard.withNothing();

// ── Stats (8 × width 3 = 24 columns, y=0, h=3) ──────────────────────────────

local sessionCostStat =
  g.panel.stat.new('Session Cost')
  + c.pos(0, 0, 3, 3)
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

local contextUsedStat =
  g.panel.stat.new('Context Used %')
  + c.pos(3, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(claude_context_used_pct{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local totalTokensStat =
  g.panel.stat.new('Tokens (in+out)')
  + c.pos(6, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + sum(claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local cacheHitStat =
  g.panel.stat.new('Cache Hit %')
  + c.pos(9, 0, 3, 3)
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

local linesNetStat =
  g.panel.stat.new('Lines +/-')
  + c.pos(12, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', 'added'),
    c.vmQ('sum(claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', 'removed'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local apiWaitStat =
  g.panel.stat.new('API Wait (avg)')
  + c.pos(15, 0, 3, 3)
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

local proxyTokensInStat =
  g.panel.stat.new('Proxy Tokens In')
  + c.pos(18, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(increase(claude_proxy_tokens_input_total[$__range])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local proxyLatencyStat =
  g.panel.stat.new('Proxy Latency')
  + c.pos(21, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('avg(claude_proxy_duration_ms) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.latencyThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

// ── Time series (pairs of 12, starting y=3) ──────────────────────────────────
// Raw counters are intentional — shows cumulative usage trends (same as heater/claude-code.jsonnet)

local tokensTs =
  g.panel.timeSeries.new('Token Usage (Input vs Output)')
  + c.pos(0, 3, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_input_total{project=~"$project",model=~"$model"}) or vector(0)', 'input {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', 'output {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cacheTs =
  g.panel.timeSeries.new('Cache Tokens (Read vs Write)')
  + c.pos(12, 3, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_cache_read{project=~"$project",model=~"$model"}) or vector(0)', 'read {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_cache_write{project=~"$project",model=~"$model"}) or vector(0)', 'write {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local costByProjectTs =
  g.panel.timeSeries.new('Cost by Project')
  + c.pos(0, 11, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_session_cost_usd{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tokensByProjectTs =
  g.panel.timeSeries.new('Tokens by Project')
  + c.pos(12, 11, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_input_total{project=~"$project",model=~"$model"} + claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local apiDurationTs =
  g.panel.timeSeries.new('API Duration over Time')
  + c.pos(0, 19, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_duration_api_seconds{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local contextTs =
  g.panel.timeSeries.new('Context Window Usage')
  + c.pos(12, 19, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('max by (project) (claude_context_used_pct{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local linesTs =
  g.panel.timeSeries.new('Lines Added / Removed')
  + c.pos(0, 27, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', '+added {{project}}'),
    c.vmQ('-sum by (project) (claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', '-removed {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local proxyTokensTs =
  g.panel.timeSeries.new('Proxy Token Usage by Model')
  + c.pos(12, 27, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (model) (rate(claude_proxy_tokens_input_total[$interval])) or vector(0)', 'in {{model}}'),
    c.vmQ('sum by (model) (rate(claude_proxy_tokens_output_total[$interval])) or vector(0)', 'out {{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local proxyLatencyTs =
  g.panel.timeSeries.new('Proxy Latency by Model')
  + c.pos(0, 35, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('avg by (model) (claude_proxy_duration_ms) or vector(0)', '{{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Charts (3 × width 8 = 24, y=43) ─────────────────────────────────────────

local tokensByModelPie =
  g.panel.pieChart.new('Tokens by Model')
  + c.pos(0, 43, 8, 8)
  + g.panel.pieChart.queryOptions.withTargets([
    c.vmQ('sum by (model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range]) + last_over_time(claude_tokens_output_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{model}}'),
  ])
  + g.panel.pieChart.options.withPieType('donut')
  + g.panel.pieChart.options.withDisplayLabels(['name', 'percent']);

local costByModelBar =
  g.panel.barChart.new('Cost by Model')
  + c.pos(8, 43, 8, 8)
  + g.panel.barChart.queryOptions.withTargets([
    c.vmQ('sum by (model) (last_over_time(claude_session_cost_usd{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{model}}'),
  ])
  + g.panel.barChart.standardOptions.withUnit('currencyUSD');

local modelShareBar =
  g.panel.barChart.new('Model Share % by Project')
  + c.pos(16, 43, 8, 8)
  + g.panel.barChart.queryOptions.withTargets([
    c.vmQ('sum by (project, model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{project}} / {{model}}'),
  ])
  + g.panel.barChart.standardOptions.withUnit('short');

// ── Table (full width, y=51) ─────────────────────────────────────────────────

local tokenBreakdownTable =
  g.panel.table.new('Token Breakdown: Project × Model')
  + c.pos(0, 51, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('sum by (project, model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range]) + last_over_time(claude_tokens_output_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{project}} / {{model}}'),
  ])
  + g.panel.table.standardOptions.withUnit('short');

// ── Logs (heater-scoped, collapsed) ─────────────────────────────────────────

local sessionLogsPanel =
  c.serviceLogsPanel('Session Logs (claude-code)', 'claude-code', host='heater', y=0);

local debugLogsPanel =
  g.panel.logs.new('Debug Logs (claude-code-debug)')
  + c.pos(0, 10, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="claude-code-debug"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local trafficLogsPanel =
  g.panel.logs.new('HTTP Traffic (mitmproxy)')
  + c.pos(0, 20, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="mitmproxy-claude"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard ────────────────────────────────────────────────────────────────

g.dashboard.new('Claude — Overview')
+ g.dashboard.withUid('claude-overview')
+ g.dashboard.withDescription('Merged Claude observability: tokens, cost, cache, context, lines, proxy metrics, heater-scoped logs. Absorbed from metrics.json + claude-proxy-dashboard.')
+ g.dashboard.withTags(['claude', 'ai', 'overview'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([hiddenVmDs, hiddenVlogsDs, projectVar, modelVar, sessionVar, intervalVar])
+ g.dashboard.withPanels([
  // Stats
  sessionCostStat, contextUsedStat, totalTokensStat, cacheHitStat,
  linesNetStat, apiWaitStat, proxyTokensInStat, proxyLatencyStat,
  // Time series
  tokensTs, cacheTs,
  costByProjectTs, tokensByProjectTs,
  apiDurationTs, contextTs,
  linesTs, proxyTokensTs,
  proxyLatencyTs,
  // Charts
  tokensByModelPie, costByModelBar, modelShareBar,
  // Table
  tokenBreakdownTable,
  // Collapsed log rows (y=59, 60, 61)
  (g.panel.row.new('Session Logs') + c.pos(0, 59, 24, 1) + { collapsed: true, panels: [sessionLogsPanel] }),
  (g.panel.row.new('Debug Logs')   + c.pos(0, 60, 24, 1) + { collapsed: true, panels: [debugLogsPanel] }),
  (g.panel.row.new('HTTP Traffic') + c.pos(0, 61, 24, 1) + { collapsed: true, panels: [trafficLogsPanel] }),
])
