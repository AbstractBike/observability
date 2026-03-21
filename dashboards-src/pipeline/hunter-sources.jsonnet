local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Hunter Sources — Search Source Performance ──────────────────────────────
//
// Tracks which search sources (route_origin) produce the most and best jobs.
//
// Sources:
//   cloud     — Firecrawl Cloud (api.firecrawl.dev)
//   auckland  — Firecrawl Auckland (fc.auckland.pin, SearXNG)
//   local     — Firecrawl Local (192.168.0.4:3002)
//   adzuna    — Adzuna API (6 countries)
//   remotive  — Remotive API
//   remoteok  — RemoteOK API (full feed, keyword filter)
//   jobicy    — Jobicy API (EU remote)
//   linkedin  — LinkedIn guest API
//
// VictoriaLogs fields used:
//   _msg:"job_extracted" route_origin:<source>  — scraped jobs per source
//   _msg:"job_ranked"    route_origin:<source>  — ranked jobs with tier/score

// ── Variables ───────────────────────────────────────────────────────────────

local hunterLogsDsVar =
  g.dashboard.variable.datasource.new('hunterlogs', 'victoriametrics-logs-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('Hunter Logs')
  + g.dashboard.variable.datasource.withRegex('^VictoriaLogs$');

local slugVar =
  g.dashboard.variable.custom.new('slug', [
    { key: 'all', value: '*' },
    { key: 'mar', value: 'mar' },
    { key: 'silvio', value: 'silvio' },
    { key: 'macarena', value: 'macarena' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Candidate')
  + g.dashboard.variable.custom.generalOptions.withCurrent('all', '*');

// ── Query helpers ───────────────────────────────────────────────────────────

local hLogsStatsQ(expr, refId='A', step='1d') = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${hunterlogs}' },
  expr: expr,
  refId: refId,
  queryType: 'statsRange',
  legendFormat: '',
  editorMode: 'code',
  step: step,
};

local hLogsQ(expr) = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${hunterlogs}' },
  expr: expr,
  refId: 'A',
  queryType: 'range',
  legendFormat: '',
  editorMode: 'code',
};

// ── Row 0: Overview Stats ───────────────────────────────────────────────────

local totalExtractedStat =
  g.panel.stat.new('Total Extracted')
  + c.pos(0, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_extracted" slug:$slug | stats count() as total'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local totalRankedStat =
  g.panel.stat.new('Total Ranked')
  + c.pos(6, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_ranked" slug:$slug | stats count() as total'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local uniqueSourcesStat =
  g.panel.stat.new('Active Sources')
  + c.pos(12, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_extracted" slug:$slug | stats count_uniq(route_origin) as sources'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local tier1Stat =
  g.panel.stat.new('Tier 1 Jobs')
  + c.pos(18, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_ranked" slug:$slug tier:1 | stats count() as tier1'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 1 },
    { color: 'green', value: 3 },
  ]);

// ── Row 1: Jobs per Source (volume) ─────────────────────────────────────────

local jobsPerSourceTs =
  g.panel.timeSeries.new('Jobs Extracted per Source')
  + c.pos(0, 5, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_extracted" slug:$slug | stats by(route_origin) count() as jobs'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local jobsPerSourcePie =
  g.panel.pieChart.new('Source Share (Extracted)')
  + c.pos(12, 5, 12, 8)
  + g.panel.pieChart.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_extracted" slug:$slug | stats by(route_origin) count() as jobs'),
  ])
  + g.panel.pieChart.options.withPieType('donut')
  + g.panel.pieChart.options.withDisplayLabels(['name', 'percent']);

// ── Row 2: Quality per Source ───────────────────────────────────────────────

local rankedPerSourceTs =
  g.panel.timeSeries.new('Jobs Ranked per Source')
  + c.pos(0, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_ranked" slug:$slug | stats by(route_origin) count() as ranked'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local avgScorePerSourceTs =
  g.panel.timeSeries.new('Avg Score per Source')
  + c.pos(12, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_ranked" slug:$slug | stats by(route_origin) avg(score) as avg_score'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.standardOptions.withDecimals(3);

// ── Row 3: Tier Distribution per Source ─────────────────────────────────────

local tier1PerSourceTs =
  g.panel.timeSeries.new('Tier 1 per Source')
  + c.pos(0, 23, 8, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_ranked" slug:$slug tier:1 | stats by(route_origin) count() as tier1'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local tier2PerSourceTs =
  g.panel.timeSeries.new('Tier 2 per Source')
  + c.pos(8, 23, 8, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_ranked" slug:$slug tier:2 | stats by(route_origin) count() as tier2'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local tier3PerSourceTs =
  g.panel.timeSeries.new('Tier 3 per Source')
  + c.pos(16, 23, 8, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_ranked" slug:$slug tier:3 | stats by(route_origin) count() as tier3'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

// ── Row 4: Source Table — Scorecard ─────────────────────────────────────────

local sourceScorecard =
  g.panel.table.new('Source Scorecard')
  + c.pos(0, 32, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    hLogsStatsQ(
      '_msg:"job_ranked" slug:$slug | stats by(route_origin) count() as total, avg(score) as avg_score, count_if(tier:1) as tier1, count_if(tier:2) as tier2, count_if(tier:3) as tier3',
      step='30d'
    ),
  ])
  + g.panel.table.queryOptions.withTransformations([
    { id: 'sortBy', options: { sort: [{ field: 'tier1', desc: true }] } },
  ]);

// ── Row 5: Candidate Comparison ─────────────────────────────────────────────

local perCandidateTs =
  g.panel.timeSeries.new('Jobs per Source × Candidate')
  + c.pos(0, 41, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_extracted" | stats by(route_origin, slug) count() as jobs'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

// ── Row 6: Raw Logs ─────────────────────────────────────────────────────────

local logsExtracted =
  g.panel.logs.new('Recent Extracted Jobs (by source)')
  + c.pos(0, 50, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    hLogsQ('_msg:"job_extracted" slug:$slug | fields route_origin, slug, title, url, source'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard Assembly ──────────────────────────────────────────────────────

g.dashboard.new('Hunter Sources')
+ g.dashboard.withUid('hunter-sources')
+ g.dashboard.withDescription('Search source performance: volume, quality, and tier distribution per route_origin')
+ g.dashboard.withTags(['hunter', 'pipeline', 'sources'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.time.withFrom('now-7d')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([hunterLogsDsVar, slugVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Overview') + c.pos(0, 0, 24, 1),
  totalExtractedStat, totalRankedStat, uniqueSourcesStat, tier1Stat,

  g.panel.row.new('📡 Volume per Source') + c.pos(0, 4, 24, 1),
  jobsPerSourceTs, jobsPerSourcePie,

  g.panel.row.new('🎯 Quality per Source') + c.pos(0, 13, 24, 1),
  rankedPerSourceTs, avgScorePerSourceTs,

  g.panel.row.new('🏆 Tier Distribution per Source') + c.pos(0, 22, 24, 1),
  tier1PerSourceTs, tier2PerSourceTs, tier3PerSourceTs,

  g.panel.row.new('📋 Scorecard') + c.pos(0, 31, 24, 1),
  sourceScorecard,

  g.panel.row.new('👥 Per Candidate') + c.pos(0, 40, 24, 1),
  perCandidateTs,

  g.panel.row.new('📝 Raw Logs') + c.pos(0, 49, 24, 1),
  logsExtracted,
])
