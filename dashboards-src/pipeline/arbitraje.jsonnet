// Dashboard: Arbitraje — Market Scalable
// Question:  "Is the arbitrage engine scanning, finding opportunities, and making profit?"
//
// Merged from arbitraje.jsonnet (prod) + arbitraje-dev.jsonnet (dev).
// Instance distinction removed — no instance/env label in VM; all metrics are under
// service="matrix-arbitraje". Add env="prod"|"dev" label in Micrometer config to re-enable.
//
// Available metrics (confirmed in VM):
//   arbitrage_max_profit_usdc       — gauge: best profit seen (USDC)
//   arbitrage_scan_rate_per_sec     — gauge: current scan throughput
//   arbitrage_paths_rate_per_sec    — gauge: path evaluation throughput
//   arbitrage_scans_total           — gauge: total scans executed
//   arbitrage_opportunities_total   — gauge: total opportunities found
//   arbitrage_paths_checked_total   — gauge: total paths checked
//   arbitrage_scan_duration_count   — counter: completed scans (no histogram bucket)
//   arbitrage_opportunities_filtered_total{reason} — counter: filtered opportunities
//
// Missing / not yet instrumented:
//   arbitrage_scan_duration_seconds_bucket  — histogram not exported by app
//   resilience4j_circuitbreaker_state       — Resilience4j not wired to Prometheus
//   binance_api_duration_seconds_bucket     — Binance API timing not instrumented
//   http_server_requests_seconds_count      — Spring MVC actuator not enabled
//   jvm_memory_used_bytes{application=...}  — JVM metrics not exported

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local svc = 'service="matrix-arbitraje"';

local alertPanel = c.alertCountPanel('arbitraje', col=0);

// ── Row 0: Key Stats ──────────────────────────────────────────────────────────

local scanRateStat =
  g.panel.stat.new('Scans / sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('arbitrage_scan_rate_per_sec{' + svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local pathsRateStat =
  g.panel.stat.new('Paths / sec')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('arbitrage_paths_rate_per_sec{' + svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local maxProfitStat =
  g.panel.stat.new('Max Profit (USDC)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('arbitrage_max_profit_usdc{' + svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(4)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Row 1: Arbitrage Engine ───────────────────────────────────────────────────

local scanRateTs =
  g.panel.timeSeries.new('Scan & Path Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('arbitrage_scan_rate_per_sec{' + svc + '} or vector(0)', 'scans/s'),
    c.vmQ('arbitrage_paths_rate_per_sec{' + svc + '} or vector(0)', 'paths/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local opportunitiesTs =
  g.panel.timeSeries.new('Opportunities & Filters')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('arbitrage_opportunities_total{' + svc + '} or vector(0)', 'total found'),
    c.vmQ(
      '(rate(arbitrage_opportunities_filtered_total{' + svc + '}[5m]) or vector(0)) * 60',
      'filtered ({{reason}})/min'
    ),
    c.vmQ('arbitrage_scans_total{' + svc + '} or vector(0)', 'scans total'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local profitTs =
  g.panel.timeSeries.new('Max Profit over Time (USDC)')
  + c.pos(0, 13, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('arbitrage_max_profit_usdc{' + svc + '} or vector(0)', 'max profit USDC'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Logs ───────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Arbitraje Logs', 'arbitraje', y=22);

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('arbitraje', [
  { symptom: 'Scan Rate Drop', runbook: 'arbitraje/scan-stall', check: 'Check Scans/sec stat — drop means the scanning loop stalled' },
  { symptom: 'No Opportunities', runbook: 'arbitraje/market-dry', check: 'Review Opportunities Total — market may be dry or service hung' },
  { symptom: 'Metrics Missing', runbook: 'arbitraje/instrumentation', check: 'Missing: circuit breaker, binance API latency, JVM, HTTP — needs Micrometer config' },
], y=33);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Arbitraje — Market Scalable')
+ g.dashboard.withUid('arbitraje-main')
+ g.dashboard.withDescription('Arbitrage engine: scan throughput, opportunities, profit. service=matrix-arbitraje.')
+ g.dashboard.withTags(['arbitraje', 'trading', 'pipeline', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, scanRateStat, pathsRateStat, maxProfitStat,

  g.panel.row.new('⚙️ Arbitrage Engine') + c.pos(0, 4, 24, 1),
  scanRateTs, opportunitiesTs,
  profitTs,

  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 32, 24, 1),
  troubleGuide,
])
