local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Arbitraje — Dev dashboard ─────────────────────────────────────────────────
//
// Tracks the dev instance of market.scalable running on heater (192.168.0.3)
// via `./gradlew bootRun`. Metrics are identical to prod but scoped to dev
// deployment. When a prod-specific label (e.g. env="prod") is added to the app,
// add a matching filter here for `env="dev"`.
//
// Metric names (Spring Boot Micrometer, application="market.scalable"):
//   Custom gauges   : arbitrage_scans_total, arbitrage_opportunities_total,
//                     arbitrage_paths_checked_total, arbitrage_max_profit_usdc,
//                     arbitrage_scan_rate, arbitrage_paths_rate
//   Custom counters : arbitrage_opportunities_found_total,
//                     arbitrage_paths_evaluated_total,
//                     arbitrage_opportunities_filtered_total{reason},
//   Timers          : arbitrage_scan_duration_seconds_{count,sum,bucket}
//                     binance_api_duration_seconds_{count,sum,bucket}
//   Resilience4j    : resilience4j_circuitbreaker_state{name="binanceApi",state}
//   JVM (Micrometer): jvm_memory_used_bytes, jvm_memory_max_bytes,
//                     jvm_gc_pause_seconds, process_cpu_usage
//   HTTP            : http_server_requests_seconds

local app = 'market.scalable';

// Dev instance runs via `bootRun` on heater (192.168.0.3:8081).
// The $instance variable defaults to heater so this dashboard only shows dev metrics,
// even when a prod instance also pushes metrics with the same application label.
local instanceVar =
  g.dashboard.variable.custom.new('instance', [
    { key: 'heater (dev)', value: '192.168.0.3.*' },
    { key: 'homelab (prod)', value: '192.168.0.4.*' },
    { key: 'all', value: '.*' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Instance')
  + g.dashboard.variable.custom.generalOptions.withCurrent('heater (dev)', '192.168.0.3.*');

local q(expr, legend='') =
  // Inject instance filter into every arbitraje metric to scope to dev
  c.vmQ(std.strReplace(expr, 'application="%s"' % app, 'application="%s",instance=~"$instance"' % app), legend);

// ── Row 0: Key Stats ──────────────────────────────────────────────────────────

local scanRateStat =
  g.panel.stat.new('Scans / sec')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    q('arbitrage_scan_rate{application="%s"}' % app),
  ])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local pathsRateStat =
  g.panel.stat.new('Paths / sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    q('arbitrage_paths_rate{application="%s"}' % app),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local maxProfitStat =
  g.panel.stat.new('Max Profit (USDC)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    q('arbitrage_max_profit_usdc{application="%s"}' % app),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(4)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local circuitBreakerStat =
  g.panel.stat.new('Binance API Circuit (closed=1)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    q('resilience4j_circuitbreaker_state{application="%s",name="binanceApi",state="closed"}' % app, 'closed'),
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
    q('(histogram_quantile(0.50, rate(arbitrage_scan_duration_seconds_bucket{application="%s"}[5m]) or vector(0)))' % app, 'P50'),
    q('(histogram_quantile(0.95, rate(arbitrage_scan_duration_seconds_bucket{application="%s"}[5m]) or vector(0)))' % app, 'P95'),
    q('(histogram_quantile(0.99, rate(arbitrage_scan_duration_seconds_bucket{application="%s"}[5m]) or vector(0)))' % app, 'P99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local opportunitiesTs =
  g.panel.timeSeries.new('Opportunities Found / min')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('(rate(arbitrage_opportunities_found_total{application="%s"}[5m]) or vector(0)) * 60' % app, 'found/min'),
    q('(rate(arbitrage_opportunities_filtered_total{application="%s"}[5m]) or vector(0)) * 60' % app, 'filtered ({{reason}})/min'),
    q('(rate(arbitrage_paths_persistence_errors_total{application="%s"}[5m]) or vector(0)) * 60' % app, 'persist errors/min'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Binance API ────────────────────────────────────────────────────────

local binanceApiTs =
  g.panel.timeSeries.new('Binance API Latency (P50 / P95 / P99)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('(histogram_quantile(0.50, rate(binance_api_duration_seconds_bucket{application="%s"}[5m]) or vector(0)))' % app, 'P50'),
    q('(histogram_quantile(0.95, rate(binance_api_duration_seconds_bucket{application="%s"}[5m]) or vector(0)))' % app, 'P95'),
    q('(histogram_quantile(0.99, rate(binance_api_duration_seconds_bucket{application="%s"}[5m]) or vector(0)))' % app, 'P99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local httpRequestsTs =
  g.panel.timeSeries.new('HTTP Requests / sec')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('(sum(rate(http_server_requests_seconds_count{application="%s"}[5m]) or vector(0)) by (uri, status))', '{{uri}} {{status}}'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: JVM ────────────────────────────────────────────────────────────────

local jvmHeapTs =
  g.panel.timeSeries.new('Heap Memory (Used / Max)')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('(jvm_memory_used_bytes{application="%s",area="heap"}) or vector(0)' % app, 'Used'),
    q('(jvm_memory_max_bytes{application="%s",area="heap"}) or vector(0)' % app, 'Max'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cpuAndGcTs =
  g.panel.timeSeries.new('CPU & GC Pause')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    q('process_cpu_usage{application="%s"}' % app, 'CPU'),
    q('rate(jvm_gc_pause_seconds_sum{application="%s"}[5m])' % app, 'GC pause/s ({{cause}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percentunit')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 4: Logs ───────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Arbitraje Dev Logs', 'arbitraje', y=29);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Arbitraje — Dev')
+ g.dashboard.withUid('arbitraje-dev')
+ g.dashboard.withDescription('Dev instance: arbitrage engine scan rate, opportunities, Binance API health, JVM. Runs via bootRun on heater (default filter: 192.168.0.3).')
+ g.dashboard.withTags(['arbitraje', 'trading', 'pipeline', 'dev'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, instanceVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  scanRateStat, pathsRateStat, maxProfitStat, circuitBreakerStat,

  g.panel.row.new('⚙️ Arbitrage Engine') + c.pos(0, 4, 24, 1),
  scanDurationTs, opportunitiesTs,

  g.panel.row.new('🌐 Binance API & HTTP') + c.pos(0, 13, 24, 1),
  binanceApiTs, httpRequestsTs,

  g.panel.row.new('⚡ JVM') + c.pos(0, 22, 24, 1),
  jvmHeapTs, cpuAndGcTs,

  g.panel.row.new('📝 Logs') + c.pos(0, 31, 24, 1),
  logsPanel,
])
