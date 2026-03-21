local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Claude Code — Full Observability Dashboard
// Metrics:  VictoriaMetrics (claude_tokens_*, claude_session_*, claude_context_*, claude_lines_*, claude_duration_*)
// Logs:     VictoriaLogs (claude-code, claude-code-debug, mitmproxy-claude)
// Traces:   SkyWalking OAP PromQL (mcp-vanguard)

local alertPanel = c.alertCountPanel('heater-claude-code', col=0);

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

// ── Hero stats (primary KPIs) ───────────────────────────────────────────────

local sessionCostStat =
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

local contextUsedStat =
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

// ── Secondary stats ─────────────────────────────────────────────────────────

local totalTokensStat =
  g.panel.stat.new('Tokens')
  + c.pos(0, 5, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + sum(claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local cacheTokensStat =
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

local linesAddedStat =
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

local apiWaitStat =
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

local mcpLatencyStat =
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

local linesRemovedStat =
  g.panel.stat.new('Lines Removed')
  + c.pos(20, 5, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

// ── Time series — Usage Trends ──────────────────────────────────────────────

local tokensTs =
  g.panel.timeSeries.new('Token Usage (Input vs Output)')
  + c.pos(0, 9, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_input_total{project=~"$project",model=~"$model"}) or vector(0)', 'input {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', 'output {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local costTs =
  g.panel.timeSeries.new('Session Cost by Project')
  + c.pos(12, 9, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_session_cost_usd{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Time series — Cache & Model breakdown ───────────────────────────────────

local cacheTs =
  g.panel.timeSeries.new('Cache Tokens (Read vs Write)')
  + c.pos(0, 18, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_cache_read{project=~"$project",model=~"$model"}) or vector(0)', 'read {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_cache_write{project=~"$project",model=~"$model"}) or vector(0)', 'write {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tokensByModelTs =
  g.panel.timeSeries.new('Token Usage by Model')
  + c.pos(12, 18, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (model) (claude_tokens_input_total{project=~"$project",model=~"$model"} + claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', '{{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Time series — Performance ───────────────────────────────────────────────

local apiWaitTs =
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

local contextTs =
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

// ── Time series — Code Changes ──────────────────────────────────────────────

local linesTs =
  g.panel.timeSeries.new('Lines Added / Removed')
  + c.pos(0, 36, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', '+added {{project}}'),
    c.vmQ('-sum by (project) (claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', '-removed {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Log volume (statsRange) ─────────────────────────────────────────────────

local logVolumeTs =
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

// ── Logs panels ─────────────────────────────────────────────────────────────

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

// ── Troubleshooting Guide ───────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('claude-code', [
  { symptom: 'High Session Cost', runbook: 'claude-code/cost-optimization', check: 'Check Session Cost stat and review Token Usage trends by project' },
  { symptom: 'Context Window Full', runbook: 'claude-code/context-strategy', check: 'Monitor Context Used % and review prompt sizes in logs' },
  { symptom: 'API Latency Spike', runbook: 'claude-code/api-delay', check: 'Compare API Wait Time vs MCP Latency to isolate bottleneck' },
  { symptom: 'Low Cache Hit Rate', runbook: 'claude-code/cache-tuning', check: 'Check Cache Hit stat and Cache Tokens chart for read/write ratio' },
  { symptom: 'MCP Vanguard Slow', runbook: 'claude-code/mcp-debug', check: 'Check MCP P95 stat and SkyWalking traces for mcp-vanguard' },
  { symptom: 'Session Failures', runbook: 'claude-code/error-recovery', check: 'Review HTTP Traffic logs for 4xx/5xx and Debug Logs for errors' },
], y=0);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Heater — Claude Code')
+ g.dashboard.withUid('heater-claude-code')
+ g.dashboard.withDescription('Claude Code full observability: metrics (tokens, cost, cache, context, lines), logs (session, debug, HTTP traffic), traces (MCP Vanguard via SkyWalking).')
+ g.dashboard.withTags(['heater', 'claude', 'ai', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.swDsVar, projectVar, modelVar])
+ g.dashboard.withPanels([
  // Hero row — Cost & Context as primary KPIs
  g.panel.row.new('Session Overview') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, sessionCostStat, contextUsedStat,

  // Secondary stats — compact row
  g.panel.row.new('Details') + c.pos(0, 6, 24, 1),
  totalTokensStat, cacheTokensStat, linesAddedStat, apiWaitStat, mcpLatencyStat, linesRemovedStat,

  // Usage trends
  g.panel.row.new('Usage Trends') + c.pos(0, 10, 24, 1),
  tokensTs, costTs,

  // Cache & Model breakdown
  g.panel.row.new('Cache & Models') + c.pos(0, 19, 24, 1),
  cacheTs, tokensByModelTs,

  // Performance
  g.panel.row.new('Performance') + c.pos(0, 28, 24, 1),
  apiWaitTs, contextTs,

  // Code changes & log volume
  g.panel.row.new('Activity') + c.pos(0, 37, 24, 1),
  linesTs, logVolumeTs,

  // Logs — collapsed rows
  (g.panel.row.new('Session Logs') + c.pos(0, 46, 24, 1) + { collapsed: true, panels: [sessionLogsPanel] }),
  (g.panel.row.new('Debug Logs') + c.pos(0, 47, 24, 1) + { collapsed: true, panels: [debugLogsPanel] }),
  (g.panel.row.new('HTTP Traffic') + c.pos(0, 48, 24, 1) + { collapsed: true, panels: [trafficLogsPanel] }),

  // Troubleshooting — collapsed
  (g.panel.row.new('Troubleshooting') + c.pos(0, 49, 24, 1) + { collapsed: true, panels: [troubleGuide] }),
])
