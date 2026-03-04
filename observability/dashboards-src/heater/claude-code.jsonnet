local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Claude Code Metrics — sourced from Vector statusline pipeline.
// Each Claude Code session pushes per-prompt gauges via HTTP to Vector on heater.
// Metrics: claude_tokens_{input,output}_total, claude_prompt_session_cost_usd,
//          claude_prompt_context_used_pct, claude_prompt_{input,output}_tokens,
//          claude_prompt_lines_{added,removed}, claude_prompt_api_wait_ms

local projectVar =
  g.dashboard.variable.query.new('project')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'project',
      'claude_prompt_session_cost_usd{host="heater"}'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Project')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*');

// ── Stats row ───────────────────────────────────────────────────────────────

local totalTokensStat =
  g.panel.stat.new('Tokens (current sessions)')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_prompt_input_tokens{host="heater",project=~"$project"}) + sum(claude_prompt_output_tokens{host="heater",project=~"$project"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local sessionCostStat =
  g.panel.stat.new('Session Cost (current)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_prompt_session_cost_usd{host="heater",project=~"$project"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 5 },
    { color: 'red', value: 20 },
  ])
  + g.panel.stat.options.withColorMode('background');

local contextUsedStat =
  g.panel.stat.new('Context Used %')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(claude_prompt_context_used_pct{host="heater",project=~"$project"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local linesAddedStat =
  g.panel.stat.new('Lines Added (current session)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_prompt_lines_added{host="heater",project=~"$project"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

// ── Time series ─────────────────────────────────────────────────────────────

local tokensTs =
  g.panel.timeSeries.new('Token Usage (Input vs Output)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_prompt_input_tokens{host="heater",project=~"$project"}) or vector(0)', 'input · {{project}}'),
    c.vmQ('sum by (project) (claude_prompt_output_tokens{host="heater",project=~"$project"}) or vector(0)', 'output · {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local costTs =
  g.panel.timeSeries.new('Session Cost by Project')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_prompt_session_cost_usd{host="heater",project=~"$project"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local apiWaitTs =
  g.panel.timeSeries.new('API Wait Time (max)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('max(claude_prompt_api_wait_ms{host="heater",project=~"$project"}) or vector(0)', 'api wait ms'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local contextTs =
  g.panel.timeSeries.new('Context Window Usage')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('max by (project) (claude_prompt_context_used_pct{host="heater",project=~"$project"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Logs panel ──────────────────────────────────────────────────────────────

local logsPanel =
  c.serviceLogsPanel('Claude Code Logs', 'claude-code', host='heater');

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Heater — Claude Code')
+ g.dashboard.withUid('heater-claude-code')
+ g.dashboard.withDescription('Claude Code session metrics: token usage, cost, context and API latency.')
+ g.dashboard.withTags(['heater', 'claude', 'ai'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, projectVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Session Stats') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  totalTokensStat, sessionCostStat, contextUsedStat, linesAddedStat,
  g.panel.row.new('📈 Usage Trends') + c.pos(0, 4, 24, 1),
  tokensTs, costTs,
  g.panel.row.new('⚡ Performance') + c.pos(0, 12, 24, 1),
  apiWaitTs, contextTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 20, 24, 1),
  logsPanel,
])
