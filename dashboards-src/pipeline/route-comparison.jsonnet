local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Route Comparison — Multi-Route Firecrawl Validation ─────────────────────
//
// 3 routes searched in parallel per pipeline run:
//   direct   → firecrawl.pin:3002 (local, no VPN)
//   auckland → fc.auckland.pin (NZ WireGuard VPN)
//   prague   → fc.prague.pin (CZ WireGuard VPN)
//
// Metrics pushed to VictoriaMetrics by vmlog.LogRouteComparison():
//   hunter_route_hits{route}       — total URLs found per route
//   hunter_route_exclusive{route}  — URLs only found by this route
//   hunter_route_latency_ms{route} — search duration per route
//   hunter_route_failed{route}     — route failure indicator
//   hunter_route_overlap{}         — URLs found by 2+ routes

// ── Variables ───────────────────────────────────────────────────────────────

local hunterMetricsDsVar =
  g.dashboard.variable.datasource.new('huntermetrics', 'victoriametrics-metrics-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('Hunter Metrics')
  + g.dashboard.variable.datasource.withRegex('HunterMetrics.*');

local hQ(expr, legend='') =
  g.query.prometheus.new('$huntermetrics', expr)
  + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {});

// ── Row 0: Key Stats ────────────────────────────────────────────────────────

local directHitsStat =
  g.panel.stat.new('Direct Hits')
  + c.pos(0, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hQ('hunter_route_hits{route="direct"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local aucklandHitsStat =
  g.panel.stat.new('Auckland Hits')
  + c.pos(6, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hQ('hunter_route_hits{route="auckland"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local pragueHitsStat =
  g.panel.stat.new('Prague Hits')
  + c.pos(12, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hQ('hunter_route_hits{route="prague"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local overlapStat =
  g.panel.stat.new('URL Overlap')
  + c.pos(18, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hQ('hunter_route_overlap'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'yellow', value: null },
    { color: 'green', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Row 1: Hits per Route Over Time ─────────────────────────────────────────

local hitsOverTimeTs =
  g.panel.timeSeries.new('Hits per Route')
  + c.pos(0, 5, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('hunter_route_hits{route="direct"}', 'Direct'),
    hQ('hunter_route_hits{route="auckland"}', 'Auckland (NZ)'),
    hQ('hunter_route_hits{route="prague"}', 'Prague (CZ)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local exclusiveOverTimeTs =
  g.panel.timeSeries.new('Exclusive Finds per Route')
  + c.pos(12, 5, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('hunter_route_exclusive{route="direct"}', 'Direct only'),
    hQ('hunter_route_exclusive{route="auckland"}', 'Auckland only'),
    hQ('hunter_route_exclusive{route="prague"}', 'Prague only'),
    hQ('hunter_route_overlap', 'Overlap (2+ routes)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Latency & Failures ───────────────────────────────────────────────

local latencyTs =
  g.panel.timeSeries.new('Search Latency per Route')
  + c.pos(0, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('hunter_route_latency_ms{route="direct"}', 'Direct'),
    hQ('hunter_route_latency_ms{route="auckland"}', 'Auckland (NZ)'),
    hQ('hunter_route_latency_ms{route="prague"}', 'Prague (CZ)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local failuresTs =
  g.panel.timeSeries.new('Route Failures')
  + c.pos(12, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('hunter_route_failed{route="direct"}', 'Direct'),
    hQ('hunter_route_failed{route="auckland"}', 'Auckland (NZ)'),
    hQ('hunter_route_failed{route="prague"}', 'Prague (CZ)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 1 },
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: Route Efficiency ─────────────────────────────────────────────────

local efficiencyBarTs =
  g.panel.timeSeries.new('Route Value — Exclusive vs Overlap')
  + c.pos(0, 23, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('hunter_route_exclusive{route="direct"} / (hunter_route_hits{route="direct"} > 0) or vector(0)', 'Direct exclusive %'),
    hQ('hunter_route_exclusive{route="auckland"} / (hunter_route_hits{route="auckland"} > 0) or vector(0)', 'Auckland exclusive %'),
    hQ('hunter_route_exclusive{route="prague"} / (hunter_route_hits{route="prague"} > 0) or vector(0)', 'Prague exclusive %'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percentunit')
  + g.panel.timeSeries.standardOptions.withDecimals(1)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Route Comparison — Multi-Route Firecrawl')
+ g.dashboard.withUid('hunter-route-comparison')
+ g.dashboard.withDescription(|||
  Multi-route Firecrawl validation: direct vs Auckland VPN vs Prague VPN.
  Compares hits, exclusive finds, latency, and failures across geo-diverse routes.
  Used to validate VPN scraping effectiveness and detect geo-blocked content.
|||)
+ g.dashboard.withTags(['hunter', 'firecrawl', 'vpn', 'route-comparison', 'observability'])
+ g.dashboard.withRefresh('1m')
+ g.dashboard.time.withFrom('now-7d')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([hunterMetricsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Route Stats') + c.pos(0, 0, 24, 1),
  directHitsStat, aucklandHitsStat, pragueHitsStat, overlapStat,

  g.panel.row.new('Hits & Exclusive Finds') + c.pos(0, 4, 24, 1),
  hitsOverTimeTs, exclusiveOverTimeTs,

  g.panel.row.new('Latency & Failures') + c.pos(0, 13, 24, 1),
  latencyTs, failuresTs,

  g.panel.row.new('Route Efficiency') + c.pos(0, 22, 24, 1),
  efficiencyBarTs,
])
