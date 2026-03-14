local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── SBTCP — Self Building Temporal Conditional Platform ─────────────────────
//
// Bootstrap Entity: long-lived Temporal workflow (sbtcp-bootstrap-entity-*)
// Task Queue: sbtcp-bootstrap
// Worker: cmd/worker/main.go
//
// Metrics exposed on :9090/metrics (prometheus scrape via VictoriaMetrics)
// Logs shipped via Vector to VictoriaLogs (service=sbtcp)
// Traces shipped via OTLP HTTP to otelcol-contrib → Tempo

// ── Variables ───────────────────────────────────────────────────────────────

local metricsDsVar =
  g.dashboard.variable.datasource.new('sbtcpmetrics', 'victoriametrics-metrics-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('SBTCP Metrics');

local logsDsVar =
  g.dashboard.variable.datasource.new('sbtcplogs', 'victoriametrics-logs-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('SBTCP Logs');

local entityIDVar =
  g.dashboard.variable.query.new('entity_id')
  + g.dashboard.variable.query.generalOptions.withLabel('Entity ID')
  + g.dashboard.variable.query.withDatasourceFromVariable(metricsDsVar)
  + g.dashboard.variable.query.queryTypes.withLabelValues('entity_id', 'sbtcp_decision_thread_cycles_total')
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
  + g.dashboard.variable.query.generalOptions.withCurrent('All');

// ── Query helpers ────────────────────────────────────────────────────────────

local mQ(expr, legend='') =
  g.query.prometheus.new('$sbtcpmetrics', expr)
  + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {});

local logsQ(expr) = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${sbtcplogs}' },
  expr: expr,
  refId: 'A',
  queryType: 'range',
  legendFormat: '',
  editorMode: 'code',
};

// ── Row 0: Key Stats ─────────────────────────────────────────────────────────

local decisionCyclesStat =
  g.panel.stat.new('Decision Cycles')
  + c.pos(0, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    mQ('increase(sbtcp_decision_thread_cycles_total[24h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local interruptsStat =
  g.panel.stat.new('Interrupts (24h)')
  + c.pos(4, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    mQ('increase(sbtcp_interrupt_received_total[24h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 5 },
    { color: 'red', value: 20 },
  ])
  + g.panel.stat.options.withColorMode('background');

local tokensStat =
  g.panel.stat.new('LLM Tokens (24h)')
  + c.pos(8, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    mQ('increase(sbtcp_llm_tokens_input_total[24h]) + increase(sbtcp_llm_tokens_output_total[24h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local compactionsStat =
  g.panel.stat.new('Compactions (7d)')
  + c.pos(12, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    mQ('increase(sbtcp_state_compaction_total[7d]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value');

local anomaliesStat =
  g.panel.stat.new('Anomalies (24h)')
  + c.pos(16, 0, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    mQ('sum(increase(sbtcp_monitor_mesh_anomalies_total[24h])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 3 },
    { color: 'red', value: 10 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Row 1: Decision Thread ────────────────────────────────────────────────────

local dtCycleRateTs =
  g.panel.timeSeries.new('Decision Thread Cycle Rate')
  + c.pos(0, 4, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    mQ('rate(sbtcp_decision_thread_cycles_total[5m])', 'cycles/s'),
    mQ('rate(sbtcp_decision_thread_skipped_total[5m])', 'skipped/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local dtDurationTs =
  g.panel.timeSeries.new('Decision Thread Reasoning Duration')
  + c.pos(12, 4, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    mQ('histogram_quantile(0.50, rate(sbtcp_decision_thread_reasoning_duration_seconds_bucket[5m]))', 'P50'),
    mQ('histogram_quantile(0.95, rate(sbtcp_decision_thread_reasoning_duration_seconds_bucket[5m]))', 'P95'),
    mQ('histogram_quantile(0.99, rate(sbtcp_decision_thread_reasoning_duration_seconds_bucket[5m]))', 'P99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: LLM Token Usage ────────────────────────────────────────────────────

local llmTokensTs =
  g.panel.timeSeries.new('LLM Token Usage')
  + c.pos(0, 12, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    mQ('rate(sbtcp_llm_tokens_input_total[5m])', 'input tokens/s'),
    mQ('rate(sbtcp_llm_tokens_output_total[5m])', 'output tokens/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local llmDurationTs =
  g.panel.timeSeries.new('LLM Reasoning Duration')
  + c.pos(12, 12, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    mQ('histogram_quantile(0.50, rate(sbtcp_llm_reasoning_duration_seconds_bucket[5m]))', 'P50'),
    mQ('histogram_quantile(0.95, rate(sbtcp_llm_reasoning_duration_seconds_bucket[5m]))', 'P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: Monitor Mesh & Interrupts ─────────────────────────────────────────

local meshChecksTs =
  g.panel.timeSeries.new('Monitor Mesh Checks by Monitor')
  + c.pos(0, 20, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    mQ('rate(sbtcp_monitor_mesh_checks_total[5m])', '{{monitor}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local interruptRateTs =
  g.panel.timeSeries.new('Interrupt Rate (received vs handled)')
  + c.pos(12, 20, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    mQ('rate(sbtcp_interrupt_received_total[5m])', 'received'),
    mQ('rate(sbtcp_interrupt_handled_total[5m])', 'handled'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 4: Result Status Distribution ────────────────────────────────────────

local resultStatusTs =
  g.panel.timeSeries.new('Activity Result Status Distribution')
  + c.pos(0, 28, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    mQ('rate(sbtcp_result_status_total[5m])', '{{status}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local compactionTs =
  g.panel.timeSeries.new('State Compaction Events')
  + c.pos(12, 28, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    mQ('increase(sbtcp_state_compaction_total[1h])', 'compactions/h'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10);

// ── Row 5: Logs (VictoriaLogs) ───────────────────────────────────────────────

local logsPanel =
  g.panel.logs.new('SBTCP Entity Logs')
  + c.pos(0, 36, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    logsQ('{service="sbtcp"} | json | limit 200'),
  ])
  + g.panel.logs.options.withShowTime(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withDedupStrategy('none');

// ── Dashboard ────────────────────────────────────────────────────────────────

g.dashboard.new('SBTCP — Self Building Temporal Conditional Platform')
+ g.dashboard.withUid('sbtcp-entity-overview')
+ g.dashboard.withDescription('Bootstrap Entity operational dashboard: Decision Thread, LLM usage, Monitor Mesh, interrupts, state compaction.')
+ g.dashboard.withTags(['sbtcp', 'temporal', 'llm', 'entity'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.time.withFrom('now-6h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withVariables([metricsDsVar, logsDsVar, entityIDVar])
+ g.dashboard.withPanels([
  // Row 0: Key Stats
  decisionCyclesStat,
  interruptsStat,
  tokensStat,
  compactionsStat,
  anomaliesStat,
  // Row 1: Decision Thread
  dtCycleRateTs,
  dtDurationTs,
  // Row 2: LLM Token Usage
  llmTokensTs,
  llmDurationTs,
  // Row 3: Monitor Mesh & Interrupts
  meshChecksTs,
  interruptRateTs,
  // Row 4: Result Status & Compaction
  resultStatusTs,
  compactionTs,
  // Row 5: Logs
  logsPanel,
])
