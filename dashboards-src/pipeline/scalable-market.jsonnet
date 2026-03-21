local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Scalable Market — Comprehensive Dashboard ──────────────────────────────────────
//
// Covers ALL services in the Matrix Scalable Market ecosystem:
//   - matrix-arbitraje (market.scalable): Arbitrage engine, execution, persistence
//   - matrix-explorer (matrix.explorer): Subspace exploration, asset scoring
//   - matrix-binance-job (binance-job): Binance data synchronization
//   - matrix-technicals (technicals): Technical indicators
//   - matrix-vault (matrix.vault): Signal generation vault
//   - matrix-meta-strategies (meta-strategies): Meta-level orchestration
//
// Total metrics covered: 70+
//
// Metric prefixes by service:
//   arbitrage.*: Core arbitrage engine (scan rate, opportunities, paths)
//   execution.*: Trade execution metrics (duration, slippage, profit deviation)
//   orderbook.persistence.*: OrderBook persistence queue, rate, errors
//   feed.*: Trade/Price feed persistence (queue, dropped, persisted)
//   matrix.*: Explorer, Binance job, meta-strategies metrics
//
// Standard Micrometer JVM metrics: jvm_*, process_*, http_server_requests
// Resilience4j: resilience4j_circuitbreaker_state

// Instance filtering: prod (homelab), dev (heater), or all
local instanceVar =
  g.dashboard.variable.custom.new('instance', [
    { key: 'homelab (prod)', value: '192.168.0.4.*' },
    { key: 'heater (dev)', value: '192.168.0.3.*' },
    { key: 'all', value: '.*' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Instance')
  + g.dashboard.variable.custom.generalOptions.withCurrent('homelab (prod)', '192.168.0.4.*');

local q(expr, legend='') =
  c.vmQ(std.strReplace(expr, 'application="%s"', 'application="%s",instance=~"$instance"'), legend);

local alertPanel = c.alertCountPanel('scalable-market', col=0);

// ── Row 0: Key Stats ──────────────────────────────────────────────────────────

local scanRateStat =
  g.panel.stat.new('Scans / sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    q('arbitrage_scan_rate{application="market.scalable"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local pathsRateStat =
  g.panel.stat.new('Paths / sec')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    q('arbitrage_paths_rate{application="market.scalable"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local maxProfitStat =
  g.panel.stat.new('Max Profit (USDC)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    q('arbitrage_max_profit_usdc{application="market.scalable"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(4)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local circuitBreakerStat =
  g.panel.stat.new('Binance API Circuit (closed=1)')
  + c.statPos(4)
  + g.panel.stat.queryOptions.withTargets([
    q('resilience4j_circuitbreaker_state{application="market.scalable",name="binanceApi",state="closed"} or vector(0)', 'closed'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Row 1: Arbitrage Engine ───────────────────────────────────────────────────

local scanDurationTs =
  g.panel.timeSeries.new('Scan Duration (P50 / P95 / P99)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('histogram_quantile(0.50, rate(arbitrage_scan_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P50'),
    q('histogram_quantile(0.95, rate(arbitrage_scan_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P95'),
    q('histogram_quantile(0.99, rate(arbitrage_scan_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local opportunitiesTs =
  g.panel.timeSeries.new('Opportunities Found / min')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('(rate(arbitrage_opportunity_found_total{application="market.scalable"}[5m]) or vector(0)) * 60', 'found/min'),
    q('(rate(arbitrage_opportunities_filtered{application="market.scalable"}[5m]) or vector(0)) * 60', 'filtered/min ({{reason}})'),
    q('(rate(arbitrage_opportunity_finding_duration_seconds_count{application="market.scalable"}[5m]) or vector(0)) * 60', 'finding attempts/min'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Data Persistence ──────────────────────────────────────────────────

local persistenceQueueTs =
  g.panel.timeSeries.new('Persistence Queue Sizes')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('arbitrage_paths_persistence_queue_size{application="market.scalable"} or vector(0)', 'Paths'),
    q('orderbook_persistence_queue_size{application="market.scalable"} or vector(0)', 'OrderBook'),
    q('feed_trades_queue_size{application="market.scalable"} or vector(0)', 'Trades'),
    q('feed_prices_queue_size{application="market.scalable"} or vector(0)', 'Prices'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local persistenceRatesTs =
  g.panel.timeSeries.new('Persistence Rates (persisted/sec)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('(rate(arbitrage_paths_persisted_total{application="market.scalable"}[5m]) or vector(0)) * 60', 'Paths/min'),
    q('(rate(orderbook_persistence_total{application="market.scalable"}[5m]) or vector(0)) * 60', 'OrderBook/min'),
    q('(rate(feed_trades_persisted{application="market.scalable"}[5m]) or vector(0)) * 60', 'Trades/min'),
    q('(rate(feed_prices_persisted{application="market.scalable"}[5m]) or vector(0)) * 60', 'Prices/min'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local persistenceErrorsTs =
  g.panel.timeSeries.new('Persistence Errors / Dropped (5m)')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('increase(arbitrage_paths_persistence_errors_total{application="market.scalable"}[5m]) or vector(0)', 'Paths errors'),
    q('increase(orderbook_persistence_errors_total{application="market.scalable"}[5m]) or vector(0)', 'OrderBook errors'),
    q('increase(arbitrage_paths_persistence_dropped_total{application="market.scalable"}[5m]) or vector(0)', 'Paths dropped'),
    q('increase(orderbook_persistence_dropped_total{application="market.scalable"}[5m]) or vector(0)', 'OrderBook dropped'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local persistenceLatencyTs =
  g.panel.timeSeries.new('Persistence Latency (P95)')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('histogram_quantile(0.95, rate(arbitrage_paths_persistence_latency_ms_bucket{application="market.scalable"}[5m]) or vector(0))', 'Paths'),
    q('histogram_quantile(0.95, rate(orderbook_persistence_latency_ms_bucket{application="market.scalable"}[5m]) or vector(0))', 'OrderBook'),
    q('histogram_quantile(0.95, rate(feed_trades_latency_bucket{application="market.scalable"}[5m]) or vector(0))', 'Trades'),
    q('histogram_quantile(0.95, rate(feed_prices_latency_bucket{application="market.scalable"}[5m]) or vector(0))', 'Prices'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: Execution ────────────────────────────────────────────────────────

local executionDurationTs =
  g.panel.timeSeries.new('Execution Duration (P95)')
  + c.tsPos(0, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('histogram_quantile(0.95, rate(execution_trade_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Trade ({{service}})'),
    q('histogram_quantile(0.95, rate(execution_slippage_evaluation_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Slippage eval'),
    q('histogram_quantile(0.95, rate(execution_recovery_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Recovery'),
    q('histogram_quantile(0.95, rate(execution_audit_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Audit'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local executionWorkflowTs =
  g.panel.timeSeries.new('Execution Workflow & Results')
  + c.tsPos(1, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('histogram_quantile(0.95, rate(execution_workflow_total_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Workflow P95'),
    q('(rate(execution_trade_result_total{application="market.scalable"}[5m]) or vector(0)) * 60', 'Results/min ({{status}})'),
    q('(increase(arbitrage_execution_aborted_total{application="market.scalable"}[5m]) or vector(0))', 'Aborted ({{reason}})'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local profitDeviationTs =
  g.panel.timeSeries.new('Profit & Dust Deviation (USDC)')
  + c.tsPos(0, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('arbitrage_execution_profit_deviation{application="market.scalable"} or vector(0)', 'Profit deviation'),
    q('arbitrage_execution_dust_deviation{application="market.scalable"} or vector(0)', 'Dust deviation ({{instrument}})'),
    q('increase(arbitrage_dust_amount_total{application="market.scalable"}[5m]) or vector(0))', 'Dust accumulated ({{type}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local slippageTs =
  g.panel.timeSeries.new('Slippage Detection')
  + c.tsPos(1, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('arbitrage_slippage_detected{application="market.scalable"} or vector(0)', 'Detected ({{status}})'),
    q('(rate(arbitrage_execution_aborted_total{application="market.scalable",reason="slippage"}[5m]) or vector(0)) * 60', 'Aborted due to slippage/min'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 4: Smoke Checks & Kafka ─────────────────────────────────────────────

local smokeCheckTs =
  g.panel.timeSeries.new('Smoke Check Results (5m)')
  + c.tsPos(0, 5)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('increase(smoke_check_passed_total{application="market.scalable"}[5m]) or vector(0)', 'Passed'),
    q('increase(smoke_check_failed_total{application="market.scalable"}[5m]) or vector(0)', 'Failed ({{reason}})'),
    q('histogram_quantile(0.95, rate(smoke_check_latency_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Latency P95'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local kafkaTs =
  g.panel.timeSeries.new('Kafka Operations Duration (P95)')
  + c.tsPos(1, 5)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('histogram_quantile(0.95, rate(kafka_publish_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Publish P95'),
    q('histogram_quantile(0.95, rate(kafka_consume_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Consume P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 5: Explorer ────────────────────────────────────────────────────────

local explorerTs =
  g.panel.timeSeries.new('Explorer Metrics')
  + c.tsPos(0, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('(rate(matrix_subspace_explored_total{application="matrix.explorer"}[5m]) or vector(0)) * 60', 'Subspaces/min ({{type}})'),
    q('histogram_quantile(0.95, rate(matrix_subspace_exploration_time_seconds_bucket{application="matrix.explorer"}[5m]) or vector(0))', 'Exploration P95 ({{type}})'),
    q('(rate(matrix_point_state_saved_count_total{application="matrix.explorer"}[5m]) or vector(0)) * 60', 'States saved/min ({{type}})'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local explorerDistributionTs =
  g.panel.timeSeries.new('Explorer Distributions (USDT)')
  + c.tsPos(1, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('matrix_subspace_max_total_usdt{application="matrix.explorer"} or vector(0)', 'Max total ({{type}})'),
    q('matrix_subspace_min_total_usdt{application="matrix.explorer"} or vector(0)', 'Min total ({{type}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local explorerScoresTs =
  g.panel.timeSeries.new('Asset Scores')
  + c.tsPos(0, 7)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('matrix_asset_score{application="matrix.explorer"} or vector(0)', 'Score ({{indicator}})'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local explorerTimingTs =
  g.panel.timeSeries.new('Explorer Timing')
  + c.tsPos(1, 7)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('histogram_quantile(0.95, rate(matrix_points_best_buy_asset_time_seconds_bucket{application="matrix.explorer"}[5m]) or vector(0))', 'Best buy asset P95'),
    q('(rate(matrix_subspace_explored_total{application="matrix.explorer"}[5m]) or vector(0)) * 60', 'Subspaces/min'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 6: Binance Job ─────────────────────────────────────────────────────

local binanceJobTs =
  g.panel.timeSeries.new('Binance Job Strategies')
  + c.tsPos(0, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('matrix_binance_strategies_raw{application="binance-job"} or vector(0)', 'Raw strategies ({{client}}, {{asset}})'),
    q('matrix_binance_strategies_usdt{application="binance-job"} or vector(0)', 'USDT strategies ({{client}}, {{asset}})'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 7: Binance API & HTTP ───────────────────────────────────────────────

local binanceApiTs =
  g.panel.timeSeries.new('Binance API Latency (P50 / P95 / P99)')
  + c.tsPos(0, 9)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('histogram_quantile(0.50, rate(binance_api_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P50'),
    q('histogram_quantile(0.95, rate(binance_api_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P95'),
    q('histogram_quantile(0.99, rate(binance_api_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local httpRequestsTs =
  g.panel.timeSeries.new('HTTP Requests / sec')
  + c.tsPos(1, 9)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('sum(rate(http_server_requests_seconds_count{application=~"market\\.scalable|matrix\\.explorer|technicals|vault"}[5m]) or vector(0)) by (application, uri, status)', '{{application}} {{uri}} {{status}}'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 8: JVM ────────────────────────────────────────────────────────────────

local jvmHeapTs =
  g.panel.timeSeries.new('Heap Memory (Used / Max)')
  + c.tsPos(0, 10)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('jvm_memory_used_bytes{application=~"market\\.scalable|matrix\\.explorer|technicals|vault",area="heap"} or vector(0)', 'Used ({{application}})'),
    q('jvm_memory_max_bytes{application=~"market\\.scalable|matrix\\.explorer|technicals|vault",area="heap"} or vector(0)', 'Max ({{application}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cpuAndGcTs =
  g.panel.timeSeries.new('CPU & GC Pause')
  + c.tsPos(1, 10)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('process_cpu_usage{application=~"market\\.scalable|matrix\\.explorer|technicals|vault"} or vector(0)', 'CPU ({{application}})'),
    q('rate(jvm_gc_pause_seconds_sum{application=~"market\\.scalable|matrix\\.explorer|technicals|vault"}[5m]) or vector(0)', 'GC pause/s ({{application}}, {{cause}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percentunit')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 9: Troubleshooting ─────────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('scalable-market', [
  { symptom: 'Scan Rate Drop', runbook: 'scalable-market/scan-stall', check: 'Check Scans/sec stat and review scan duration trends' },
  { symptom: 'Binance API Down', runbook: 'scalable-market/api-failure', check: 'Monitor Circuit Breaker state and check Binance latency' },
  { symptom: 'No Opportunities', runbook: 'scalable-market/market-dry', check: 'Review Opportunities Found metric and market conditions' },
  { symptom: 'Persistence Backlog', runbook: 'scalable-market/persistence-lag', check: 'Check Queue Sizes panel and ClickHouse health' },
  { symptom: 'JVM Memory High', runbook: 'scalable-market/oom-risk', check: 'Check Heap Memory panel and review GC activity' },
  { symptom: 'Kafka Lag', runbook: 'scalable-market/kafka-lag', check: 'Check Kafka Operations Duration and consumer lag' },
  { symptom: 'Execution Failures', runbook: 'scalable-market/execution-errors', check: 'Check Execution Workflow panel and abort reasons' },
  { symptom: 'Slippage Detected', runbook: 'scalable-market/slippage-alert', check: 'Check Slippage Detection panel and instrument liquidity' },
], y=93);

// ── Row 10: Logs (Multi-Service) ──────────────────────────────────────────────

local logsPanelArbitraje =
  g.panel.logs.new('Arbitraje Logs')
  + c.pos(0, 97, 12, 8)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{instance=~"$instance",service=~"arbitraje|market\\.scalable"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local logsPanelExplorer =
  g.panel.logs.new('Explorer Logs')
  + c.pos(12, 97, 12, 8)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{instance=~"$instance",service=~"explorer|matrix\\.explorer"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local logsPanelBinanceJob =
  g.panel.logs.new('Binance Job Logs')
  + c.pos(0, 105, 12, 8)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{instance=~"$instance",service=~"binance-job"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local logsPanelOther =
  g.panel.logs.new('Vault & Technicals Logs')
  + c.pos(12, 105, 12, 8)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{instance=~"$instance",service=~"vault|technicals"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Scalable Market — All Services')
+ g.dashboard.withUid('scalable-market-main')
+ g.dashboard.withDescription('Comprehensive dashboard for all Matrix Scalable Market services: Arbitrage, Explorer, Binance Job, Vault, Technicals. Covers 70+ metrics across persistence, execution, Kafka, JVM, and multi-service logs.')
+ g.dashboard.withTags(['scalable-market', 'trading', 'pipeline', 'critical', 'observability'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, instanceVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, scanRateStat, pathsRateStat, maxProfitStat, circuitBreakerStat,

  g.panel.row.new('⚙️ Arbitrage Engine') + c.pos(0, 6, 24, 1),
  scanDurationTs, opportunitiesTs,

  g.panel.row.new('📦 Data Persistence') + c.pos(0, 15, 24, 1),
  persistenceQueueTs, persistenceRatesTs,

  g.panel.row.new('📦 Data Persistence (cont.)') + c.pos(0, 23, 24, 1),
  persistenceErrorsTs, persistenceLatencyTs,

  g.panel.row.new('🎯 Execution') + c.pos(0, 31, 24, 1),
  executionDurationTs, executionWorkflowTs,

  g.panel.row.new('🎯 Execution (cont.)') + c.pos(0, 39, 24, 1),
  profitDeviationTs, slippageTs,

  g.panel.row.new('🔍 Smoke Checks & Kafka') + c.pos(0, 47, 24, 1),
  smokeCheckTs, kafkaTs,

  g.panel.row.new('🧭 Explorer') + c.pos(0, 55, 24, 1),
  explorerTs, explorerDistributionTs,

  g.panel.row.new('🧭 Explorer (cont.)') + c.pos(0, 63, 24, 1),
  explorerScoresTs, explorerTimingTs,

  g.panel.row.new('📈 Binance Job') + c.pos(0, 71, 24, 1),
  binanceJobTs,

  g.panel.row.new('🌐 Binance API & HTTP') + c.pos(0, 79, 24, 1),
  binanceApiTs, httpRequestsTs,

  g.panel.row.new('⚡ JVM') + c.pos(0, 87, 24, 1),
  jvmHeapTs, cpuAndGcTs,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 93, 24, 1),
  troubleGuide,

  g.panel.row.new('📝 Logs — Arbitraje & Explorer') + c.pos(0, 98, 24, 1),
  logsPanelArbitraje, logsPanelExplorer,

  g.panel.row.new('📝 Logs — Binance Job & Vault') + c.pos(0, 106, 24, 1),
  logsPanelBinanceJob, logsPanelOther,
])
