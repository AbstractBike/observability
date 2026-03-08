// Dashboard: Pathranker — Market Scalable
// Question:  "Is the path ranker scanning, finding arbitrage cycles, and are any profitable?"
//
// Metrics pushed every 15s to VictoriaMetrics via /api/v1/import/prometheus.
// All metrics carry: service="scalable-pathranker"
//
// Available metrics:
//   pathranker_profitable_paths      — gauge: profitable cyclic paths in last scan
//   pathranker_total_paths           — gauge: total cyclic paths in last scan
//   pathranker_instruments           — gauge: instruments loaded from orderbook
//   pathranker_best_return_ratio     — gauge: return ratio of top path (1.002 = 0.2% gain)
//   pathranker_scans_total           — counter: total scans completed
//   pathranker_scan_duration_seconds — histogram: duration of RankPaths activity

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local svc = 'service="scalable-pathranker"';

local alertPanel = c.alertCountPanel('pathranker', col=0);

// ── Row 0: Key Stats ──────────────────────────────────────────────────────────

local profitablePathsStat =
  g.panel.stat.new('Profitable Paths')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('pathranker_profitable_paths{' + svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 1 },
    { color: 'green', value: 3 },
  ]);

local totalPathsStat =
  g.panel.stat.new('Total Paths')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('pathranker_total_paths{' + svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local bestReturnStat =
  g.panel.stat.new('Best Return Ratio')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('pathranker_best_return_ratio{' + svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(4)
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 1.0 },
    { color: 'green', value: 1.001 },
  ]);

// ── Row 1: Scanning ───────────────────────────────────────────────────────────

local pathsTs =
  g.panel.timeSeries.new('Paths Found per Scan')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pathranker_total_paths{' + svc + '} or vector(0)', 'total'),
    c.vmQ('pathranker_profitable_paths{' + svc + '} or vector(0)', 'profitable'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local scanRateTs =
  g.panel.timeSeries.new('Scan Rate & Duration')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(pathranker_scans_total{' + svc + '}[5m]) or vector(0)', 'scans/s'),
    c.vmQ(
      'rate(pathranker_scan_duration_seconds_sum{' + svc + '}[5m]) / rate(pathranker_scan_duration_seconds_count{' + svc + '}[5m]) or vector(0)',
      'avg duration (s)'
    ),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local returnRatioTs =
  g.panel.timeSeries.new('Best Return Ratio over Time')
  + c.pos(0, 13, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pathranker_best_return_ratio{' + svc + '} or vector(0)', 'best ratio'),
  ])
  + g.panel.timeSeries.standardOptions.withDecimals(5)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Logs ───────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Pathranker Logs', 'scalable-pathranker', y=22);

// ── Troubleshooting Guide ─────────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('pathranker', [
  { symptom: 'Zero paths found', runbook: 'pathranker/no-paths', check: 'Check instruments gauge — if 0, orderbook is not pushing to VM' },
  { symptom: 'No profitable paths', runbook: 'pathranker/market-dry', check: 'Best Return Ratio < 1.0 — market too tight or fees too high' },
  { symptom: 'Metrics missing', runbook: 'pathranker/no-metrics', check: 'Push goroutine failed — check VM_URL env and VM reachability' },
  { symptom: 'Scan duration spike', runbook: 'pathranker/slow-scan', check: 'Graph too dense — consider reducing MAX_HOPS or ENDPOINTS' },
  { symptom: 'Worker stopped', runbook: 'pathranker/temporal-dead', check: 'Check Temporal UI — workflow may have failed; restart container' },
], y=33);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Pathranker — Market Scalable')
+ g.dashboard.withUid('pathranker-main')
+ g.dashboard.withDescription('Cyclic arbitrage path ranker: scan throughput, profitable paths, best return ratio. service=scalable-pathranker.')
+ g.dashboard.withTags(['pathranker', 'trading', 'pipeline', 'arbitrage'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, profitablePathsStat, totalPathsStat, bestReturnStat,

  g.panel.row.new('⚙️ Scanning') + c.pos(0, 4, 24, 1),
  pathsTs, scanRateTs,
  returnRatioTs,

  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 32, 24, 1),
  troubleGuide,
])
