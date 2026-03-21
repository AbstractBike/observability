local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Pipeline Dashboard ──────────────────────────────────────────────────────
//
// Merges 9 source dashboards into one scrollable view:
//   Hunter group (1-4):
//     1. services/job-hunter.jsonnet
//     2. pipeline/hunter-sources.jsonnet
//     3. pipeline/hunter-pipeline.jsonnet
//     4. pipeline/hunter-namespace-health.jsonnet
//   Scalable Market group (5-9):
//     5. pipeline/scalable-market.jsonnet
//     6. pipeline/scalable-pathranker.jsonnet
//     7. pipeline/route-comparison.jsonnet
//     8. pipeline/arbitraje.jsonnet
//     9. pipeline/vector.jsonnet

// ════════════════════════════════════════════════════════════════════════════
// ── 1. services/job-hunter ──────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local jobHunterAlertPanel = c.alertCountPanel('job-hunter', col=0);

local jh_totalOffersTodayStat =
  g.panel.stat.new('Offers Today')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(increase(hunter_jobs_found{tier="all"}[1d])) by (slug) or vector(0)', '{{slug}}'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local jh_avgScoreStat =
  g.panel.gauge.new('Avg Score by Slug')
  + c.statPos(2)
  + g.panel.gauge.queryOptions.withTargets([
    c.vmQ('avg(hunter_jobs_found{tier="all"}) by (slug) or vector(0)', '{{slug}}'),
  ])
  + g.panel.gauge.standardOptions.withUnit('short')
  + g.panel.gauge.standardOptions.withMin(0)
  + g.panel.gauge.standardOptions.withMax(100)
  + g.panel.gauge.standardOptions.thresholds.withMode('absolute')
  + g.panel.gauge.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 30 },
    { color: 'green', value: 60 },
  ]);

local jh_errorsStat =
  g.panel.stat.new('Errors (1h)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(increase(hunter_errors_total[1h])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + c.errorThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local jh_jobsFoundTs =
  g.panel.timeSeries.new('Offers Found by Slug')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('hunter_jobs_found{tier="all"}', '{{slug}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' });

local jh_searchDurationTs =
  g.panel.timeSeries.new('Search Duration by Slug')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('hunter_search_duration_seconds', '{{slug}} / {{mode}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local jh_emailStatusTs =
  g.panel.timeSeries.new('Email Delivery Status')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('hunter_email_sent', '{{slug}} / {{status}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local jh_errorsTs =
  g.panel.timeSeries.new('Errors by Phase')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('hunter_errors_total', '{{slug}} / {{phase}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local jh_logsPanel =
  c.serviceLogsPanel('job-hunter Logs', 'job_hunter', host='heater');

local jh_troubleGuide = c.serviceTroubleshootingGuide('job-hunter', [
  { symptom: 'No offers found', runbook: 'job-hunter/dry-spell', check: '"Offers Found" flat at zero — check search sources and network' },
  { symptom: 'Email failures', runbook: 'job-hunter/email', check: '"Email Delivery Status" shows errors — check SMTP config' },
  { symptom: 'High error count', runbook: 'job-hunter/errors', check: '"Errors by Phase" rising — inspect logs for stack traces' },
  { symptom: 'Slow searches', runbook: 'job-hunter/latency', check: '"Search Duration" above 60s — check source availability' },
], y=35);

local jobHunterPanels = [
  g.panel.row.new('Job Hunter') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Status') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=4),
  jobHunterAlertPanel, jh_totalOffersTodayStat, jh_avgScoreStat, jh_errorsStat,
  g.panel.row.new('Search Activity') + c.pos(0, 7, 24, 1),
  jh_jobsFoundTs, jh_searchDurationTs,
  g.panel.row.new('Delivery & Errors') + c.pos(0, 15, 24, 1),
  jh_emailStatusTs, jh_errorsTs,
  g.panel.row.new('Logs') + c.pos(0, 23, 24, 1),
  jh_logsPanel,
  g.panel.row.new('Troubleshooting') + c.pos(0, 34, 24, 1),
  jh_troubleGuide,
];

// max y+h: troubleGuide at y=35, h=5 → 40
local jobHunterHeight = 40;

// ════════════════════════════════════════════════════════════════════════════
// ── 2. pipeline/hunter-sources ───────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local hs_hunterLogsDsVar =
  g.dashboard.variable.datasource.new('hunterlogs', 'victoriametrics-logs-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('Hunter Logs')
  + g.dashboard.variable.datasource.withRegex('^VictoriaLogs$');

local hs_slugVar =
  g.dashboard.variable.custom.new('slug', [
    { key: 'all', value: '*' },
    { key: 'mar', value: 'mar' },
    { key: 'silvio', value: 'silvio' },
    { key: 'macarena', value: 'macarena' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Candidate')
  + g.dashboard.variable.custom.generalOptions.withCurrent('all', '*');

local hs_hLogsStatsQ(expr, refId='A', step='1d') = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${hunterlogs}' },
  expr: expr,
  refId: refId,
  queryType: 'statsRange',
  legendFormat: '',
  editorMode: 'code',
  step: step,
};

local hs_hLogsQ(expr) = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${hunterlogs}' },
  expr: expr,
  refId: 'A',
  queryType: 'range',
  legendFormat: '',
  editorMode: 'code',
};

local hs_totalExtractedStat =
  g.panel.stat.new('Total Extracted')
  + c.pos(0, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_extracted" slug:$slug | stats count() as total'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local hs_totalRankedStat =
  g.panel.stat.new('Total Ranked')
  + c.pos(6, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_ranked" slug:$slug | stats count() as total'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local hs_uniqueSourcesStat =
  g.panel.stat.new('Active Sources')
  + c.pos(12, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_extracted" slug:$slug | stats count_uniq(route_origin) as sources'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local hs_tier1Stat =
  g.panel.stat.new('Tier 1 Jobs')
  + c.pos(18, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_ranked" slug:$slug tier:1 | stats count() as tier1'),
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

local hs_jobsPerSourceTs =
  g.panel.timeSeries.new('Jobs Extracted per Source')
  + c.pos(0, 5, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_extracted" slug:$slug | stats by(route_origin) count() as jobs'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local hs_jobsPerSourcePie =
  g.panel.pieChart.new('Source Share (Extracted)')
  + c.pos(12, 5, 12, 8)
  + g.panel.pieChart.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_extracted" slug:$slug | stats by(route_origin) count() as jobs'),
  ])
  + g.panel.pieChart.options.withPieType('donut')
  + g.panel.pieChart.options.withDisplayLabels(['name', 'percent']);

local hs_rankedPerSourceTs =
  g.panel.timeSeries.new('Jobs Ranked per Source')
  + c.pos(0, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_ranked" slug:$slug | stats by(route_origin) count() as ranked'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local hs_avgScorePerSourceTs =
  g.panel.timeSeries.new('Avg Score per Source')
  + c.pos(12, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_ranked" slug:$slug | stats by(route_origin) avg(score) as avg_score'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.standardOptions.withDecimals(3);

local hs_tier1PerSourceTs =
  g.panel.timeSeries.new('Tier 1 per Source')
  + c.pos(0, 23, 8, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_ranked" slug:$slug tier:1 | stats by(route_origin) count() as tier1'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local hs_tier2PerSourceTs =
  g.panel.timeSeries.new('Tier 2 per Source')
  + c.pos(8, 23, 8, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_ranked" slug:$slug tier:2 | stats by(route_origin) count() as tier2'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local hs_tier3PerSourceTs =
  g.panel.timeSeries.new('Tier 3 per Source')
  + c.pos(16, 23, 8, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_ranked" slug:$slug tier:3 | stats by(route_origin) count() as tier3'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local hs_sourceScorecard =
  g.panel.table.new('Source Scorecard')
  + c.pos(0, 32, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    hs_hLogsStatsQ(
      '_msg:"job_ranked" slug:$slug | stats by(route_origin) count() as total, avg(score) as avg_score, count_if(tier:1) as tier1, count_if(tier:2) as tier2, count_if(tier:3) as tier3',
      step='30d'
    ),
  ])
  + g.panel.table.queryOptions.withTransformations([
    { id: 'sortBy', options: { sort: [{ field: 'tier1', desc: true }] } },
  ]);

local hs_perCandidateTs =
  g.panel.timeSeries.new('Jobs per Source × Candidate')
  + c.pos(0, 41, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hs_hLogsStatsQ('_msg:"job_extracted" | stats by(route_origin, slug) count() as jobs'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.standardOptions.withUnit('short');

local hs_logsExtracted =
  g.panel.logs.new('Recent Extracted Jobs (by source)')
  + c.pos(0, 50, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    hs_hLogsQ('_msg:"job_extracted" slug:$slug | fields route_origin, slug, title, url, source'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local hunterSourcesPanels = [
  g.panel.row.new('Hunter Sources') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Overview') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  hs_totalExtractedStat, hs_totalRankedStat, hs_uniqueSourcesStat, hs_tier1Stat,

  g.panel.row.new('Volume per Source') + c.pos(0, 6, 24, 1),
  hs_jobsPerSourceTs, hs_jobsPerSourcePie,

  g.panel.row.new('Quality per Source') + c.pos(0, 15, 24, 1),
  hs_rankedPerSourceTs, hs_avgScorePerSourceTs,

  g.panel.row.new('Tier Distribution per Source') + c.pos(0, 24, 24, 1),
  hs_tier1PerSourceTs, hs_tier2PerSourceTs, hs_tier3PerSourceTs,

  g.panel.row.new('Scorecard') + c.pos(0, 33, 24, 1),
  hs_sourceScorecard,

  g.panel.row.new('Per Candidate') + c.pos(0, 42, 24, 1),
  hs_perCandidateTs,

  g.panel.row.new('Raw Logs') + c.pos(0, 51, 24, 1),
  hs_logsExtracted,
];

// max y+h: logsExtracted at y=50, h=10 → 60
local hunterSourcesHeight = 60;

// ════════════════════════════════════════════════════════════════════════════
// ── 3. pipeline/hunter-pipeline ─────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local hp_hQ(expr, legend='') =
  g.query.prometheus.new('$huntermetrics', expr)
  + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {});

local hp_hLogsQ(expr) = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${hunterlogs}' },
  expr: expr,
  refId: 'A',
  queryType: 'range',
  legendFormat: '',
  editorMode: 'code',
};

local hp_hLogsStatsQ(expr, refId='A', step='5m') = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${hunterlogs}' },
  expr: expr,
  refId: refId,
  queryType: 'statsRange',
  legendFormat: '',
  editorMode: 'code',
  step: step,
};

local hunterPipelineAlertPanel = c.alertCountPanel('hunter-pipeline', col=0);

local hp_jobsTodayStat =
  g.panel.stat.new('Jobs Today')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    hp_hQ('hunter_jobs_extracted_total or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local hp_tier1Stat =
  g.panel.stat.new('Tier 1 Jobs')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    hp_hQ('hunter_jobs_ranked_total{tier="1"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'yellow', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local hp_emailsSentStat =
  g.panel.stat.new('Emails Sent')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    hp_hQ('hunter_emails_sent_total or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local hp_linksPanel = c.customExternalLinksPanel([
  { icon: '📊', title: 'Hunter Metrics (VM)', url: 'http://192.168.0.4:9430/vmui' },
  { icon: '📝', title: 'Hunter Logs (VLogs)', url: 'http://192.168.0.4:9432/select/vmui' },
  { icon: '⏱', title: 'Temporal UI', url: 'http://temporal.pin' },
], y=3, x=22);

local hp_pipelineDurationTs =
  g.panel.timeSeries.new('Pipeline Duration (end-to-end)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('histogram_quantile(0.50, rate(hunter_pipeline_duration_seconds_bucket[1h]) or vector(0))', 'P50'),
    hp_hQ('histogram_quantile(0.95, rate(hunter_pipeline_duration_seconds_bucket[1h]) or vector(0))', 'P95'),
    hp_hQ('hunter_pipeline_duration_seconds_sum / hunter_pipeline_duration_seconds_count or vector(0)', 'Avg'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_workflowStatusTs =
  g.panel.timeSeries.new('Workflow Runs (success / fail)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('increase(hunter_workflow_completed_total{status="success"}[1d]) or vector(0)', 'Success'),
    hp_hQ('increase(hunter_workflow_completed_total{status="failed"}[1d]) or vector(0)', 'Failed'),
    hp_hQ('increase(hunter_workflow_completed_total{status="timeout"}[1d]) or vector(0)', 'Timeout'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_searchSourcesTs =
  g.panel.timeSeries.new('Sources Scanned & Results')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('increase(hunter_search_sources_scanned_total[1d]) or vector(0)', 'Sources scanned'),
    hp_hQ('increase(hunter_search_results_total[1d]) or vector(0)', 'Raw results'),
    hp_hQ('increase(hunter_search_results_after_dedup_total[1d]) or vector(0)', 'After dedup (35d)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_searchDedupTs =
  g.panel.timeSeries.new('Dedup & Fallback')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('increase(hunter_search_dedup_hits_total[1d]) or vector(0)', 'Dedup hits (35d window)'),
    hp_hQ('increase(hunter_search_fallback_total{backend="firecrawl"}[1d]) or vector(0)', 'Firecrawl primary'),
    hp_hQ('increase(hunter_search_fallback_total{backend="zai_mcp"}[1d]) or vector(0)', 'z.ai MCP fallback'),
    hp_hQ('increase(hunter_search_errors_total[1d]) or vector(0)', 'Search errors'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_scrapeDurationTs =
  g.panel.timeSeries.new('Scrape + LLM Extract Duration')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('histogram_quantile(0.50, rate(hunter_scrape_duration_seconds_bucket[1h]) or vector(0))', 'Scrape P50'),
    hp_hQ('histogram_quantile(0.95, rate(hunter_scrape_duration_seconds_bucket[1h]) or vector(0))', 'Scrape P95'),
    hp_hQ('histogram_quantile(0.50, rate(hunter_llm_extract_duration_seconds_bucket[1h]) or vector(0))', 'LLM Extract P50'),
    hp_hQ('histogram_quantile(0.95, rate(hunter_llm_extract_duration_seconds_bucket[1h]) or vector(0))', 'LLM Extract P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_scrapeResultsTs =
  g.panel.timeSeries.new('Scrape Results (fan-out)')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('increase(hunter_scrape_success_total[1d]) or vector(0)', 'Success'),
    hp_hQ('increase(hunter_scrape_soft_fail_total[1d]) or vector(0)', 'Soft-fail (non-blocking)'),
    hp_hQ('increase(hunter_scrape_hard_fail_total[1d]) or vector(0)', 'Hard-fail'),
    hp_hQ('hunter_scrape_parallelism or vector(0)', 'Active goroutines'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_rankScoresTs =
  g.panel.timeSeries.new('TF-IDF Cosine Similarity Scores')
  + c.tsPos(0, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('hunter_rank_score_avg or vector(0)', 'Avg score'),
    hp_hQ('hunter_rank_score_max or vector(0)', 'Max score'),
    hp_hQ('hunter_rank_score_min or vector(0)', 'Min score'),
    hp_hQ('hunter_rank_score_p50 or vector(0)', 'Median'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.standardOptions.withDecimals(3)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_rankTiersTs =
  g.panel.timeSeries.new('Tier Distribution & Red Flags')
  + c.tsPos(1, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('increase(hunter_jobs_ranked_total{tier="1"}[1d]) or vector(0)', 'Tier 1'),
    hp_hQ('increase(hunter_jobs_ranked_total{tier="2"}[1d]) or vector(0)', 'Tier 2'),
    hp_hQ('increase(hunter_jobs_ranked_total{tier="3"}[1d]) or vector(0)', 'Tier 3'),
    hp_hQ('increase(hunter_red_flags_total[1d]) or vector(0)', 'Red flags detected'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_emailRenderTs =
  g.panel.timeSeries.new('Email Render & Send')
  + c.tsPos(0, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('histogram_quantile(0.50, rate(hunter_email_render_duration_seconds_bucket[1h]) or vector(0))', 'Claude render P50'),
    hp_hQ('histogram_quantile(0.95, rate(hunter_email_render_duration_seconds_bucket[1h]) or vector(0))', 'Claude render P95'),
    hp_hQ('histogram_quantile(0.95, rate(hunter_smtp_send_duration_seconds_bucket[1h]) or vector(0))', 'SMTP send P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_emailDeliveryTs =
  g.panel.timeSeries.new('Delivery Status')
  + c.tsPos(1, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('increase(hunter_emails_sent_total[1d]) or vector(0)', 'Emails sent'),
    hp_hQ('increase(hunter_email_jobs_included_total[1d]) or vector(0)', 'Jobs included'),
    hp_hQ('increase(hunter_email_errors_total[1d]) or vector(0)', 'SMTP errors'),
    hp_hQ('increase(hunter_jobs_marked_sent_total[1d]) or vector(0)', 'Jobs marked sent (dedup)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_activityDurationTs =
  g.panel.timeSeries.new('Activity Duration Breakdown')
  + c.pos(0, 45, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hQ('histogram_quantile(0.95, rate(hunter_activity_duration_seconds_bucket{activity="search"}[1h]) or vector(0))', 'SearchActivity P95'),
    hp_hQ('histogram_quantile(0.95, rate(hunter_activity_duration_seconds_bucket{activity="scrape_extract"}[1h]) or vector(0))', 'ScrapeExtractActivity P95'),
    hp_hQ('histogram_quantile(0.95, rate(hunter_activity_duration_seconds_bucket{activity="rank"}[1h]) or vector(0))', 'RankActivity P95'),
    hp_hQ('histogram_quantile(0.95, rate(hunter_activity_duration_seconds_bucket{activity="summarize_send"}[1h]) or vector(0))', 'SummarizeRenderSendActivity P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_logsVolumeTs =
  g.panel.timeSeries.new('Event Volume by Type')
  + c.pos(0, 54, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hp_hLogsStatsQ('_msg:"job_extracted" | stats count() as extracted', 'A'),
    hp_hLogsStatsQ('_msg:"job_ranked" | stats count() as ranked', 'B'),
    hp_hLogsStatsQ('_msg:"job_sent" | stats count() as sent', 'C'),
    hp_hLogsStatsQ('_msg:"source_config" | stats count() as sources', 'D'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local hp_troubleGuide = c.serviceTroubleshootingGuide('hunter-pipeline', [
  { symptom: 'No jobs extracted', runbook: 'hunter/no-jobs', check: 'Check SearchActivity: sources reachable, Firecrawl healthy, dedup not filtering everything' },
  { symptom: 'All jobs soft-fail', runbook: 'hunter/scrape-fail', check: 'Check ScrapeExtractActivity: target sites blocking, LLM API quota, rate limiting' },
  { symptom: 'Low Tier 1 count', runbook: 'hunter/low-tier1', check: 'Review dimensions.toml weights, profile.md freshness, TF-IDF scores distribution' },
  { symptom: 'Email not sent', runbook: 'hunter/email-fail', check: 'Check SMTP credentials, Gmail app password, Claude API quota for render' },
  { symptom: 'Pipeline timeout', runbook: 'hunter/timeout', check: 'Check Activity Duration panel — which activity is slow? Firecrawl latency? LLM cold start?' },
  { symptom: 'Dedup too aggressive', runbook: 'hunter/dedup-window', check: 'Review 35-day dedup window, check if sources recycling same listings' },
  { symptom: 'Red flags missed', runbook: 'hunter/red-flags', check: 'Review 8 red flag detectors in RankActivity, check is_agency threshold' },
  { symptom: 'Stale sources', runbook: 'hunter/stale-sources', check: 'Check source_config events in VLogs, verify VictoriaLogs source definitions' },
], y=65);

local hp_logsExtracted =
  g.panel.logs.new('job_extracted — Scraped & Parsed Jobs')
  + c.pos(0, 69, 24, 8)
  + g.panel.logs.queryOptions.withTargets([
    hp_hLogsQ('_msg:"job_extracted"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local hp_logsRanked =
  g.panel.logs.new('job_ranked — Scored & Tiered Jobs')
  + c.pos(0, 78, 24, 8)
  + g.panel.logs.queryOptions.withTargets([
    hp_hLogsQ('_msg:"job_ranked"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local hp_logsSent =
  g.panel.logs.new('job_sent — Delivered via Email')
  + c.pos(0, 87, 24, 8)
  + g.panel.logs.queryOptions.withTargets([
    hp_hLogsQ('_msg:"job_sent"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local hunterPipelinePanels = [
  g.panel.row.new('Hunter Pipeline — Daily Job Search') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Status') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  hunterPipelineAlertPanel, hp_jobsTodayStat, hp_tier1Stat, hp_emailsSentStat,
  hp_linksPanel,

  g.panel.row.new('Pipeline Duration & Workflows') + c.pos(0, 6, 24, 1),
  hp_pipelineDurationTs, hp_workflowStatusTs,

  g.panel.row.new('1. SearchActivity') + c.pos(0, 15, 24, 1),
  hp_searchSourcesTs, hp_searchDedupTs,

  g.panel.row.new('2. ScrapeExtractActivity (fan-out)') + c.pos(0, 24, 24, 1),
  hp_scrapeDurationTs, hp_scrapeResultsTs,

  g.panel.row.new('3. RankActivity (TF-IDF + dimensions)') + c.pos(0, 33, 24, 1),
  hp_rankScoresTs, hp_rankTiersTs,

  g.panel.row.new('4. SummarizeRenderSendActivity') + c.pos(0, 42, 24, 1),
  hp_emailRenderTs, hp_emailDeliveryTs,

  g.panel.row.new('Activity Duration Breakdown') + c.pos(0, 46, 24, 1),
  hp_activityDurationTs,

  g.panel.row.new('VictoriaLogs Event Volume') + c.pos(0, 55, 24, 1),
  hp_logsVolumeTs,

  g.panel.row.new('Troubleshooting') + c.pos(0, 64, 24, 1),
  hp_troubleGuide,

  g.panel.row.new('job_extracted') + c.pos(0, 70, 24, 1),
  hp_logsExtracted,

  g.panel.row.new('job_ranked') + c.pos(0, 79, 24, 1),
  hp_logsRanked,

  g.panel.row.new('job_sent') + c.pos(0, 88, 24, 1),
  hp_logsSent,
];

// max y+h: logsSent at y=87, h=8 → 95
local hunterPipelineHeight = 95;

// ════════════════════════════════════════════════════════════════════════════
// ── 4. pipeline/hunter-namespace-health ─────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local hnh_hQ(expr, legend='') =
  g.query.prometheus.new('$huntermetrics', expr)
  + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {});

local hnh_workerUp = 'hunter_namespace_worker_up{namespace="hunter-prod", service="hunter-engine", host="homelab", env="$env"}';

local hnh_upDownThresholds =
  g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ]);

local hnh_upDownMappings =
  g.panel.stat.standardOptions.withMappings([
    { type: 'value', options: { '0': { text: 'DOWN' }, '1': { text: 'UP' } } },
  ]);

local hnh_workerStatusStat =
  g.panel.stat.new(c.panelTitle('Status', 'Hunter', 'Worker Up'))
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    hnh_hQ(hnh_workerUp, 'hunter-prod'),
  ])
  + hnh_upDownThresholds
  + hnh_upDownMappings
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local hnh_workerHistoryTs =
  g.panel.timeSeries.new(c.panelTitle('Timeseries', 'Hunter', 'Worker Up History'))
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    hnh_hQ(hnh_workerUp, 'hunter-prod'),
  ])
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ]);

local hunterNamespaceHealthPanels = [
  g.panel.row.new('Hunter — Namespace Health') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Worker Status — hunter-prod') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  hnh_workerStatusStat,

  g.panel.row.new('History') + c.pos(0, 6, 24, 1),
  hnh_workerHistoryTs,
];

// max y+h: workerHistoryTs via tsPos(0,0) = pos(0,7,12,8) → y=7, h=8 → 15
local hunterNamespaceHealthHeight = 15;

// ════════════════════════════════════════════════════════════════════════════
// ── 5. pipeline/scalable-market ─────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local sm_instanceVar =
  g.dashboard.variable.custom.new('instance', [
    { key: 'homelab (prod)', value: '192.168.0.4.*' },
    { key: 'heater (dev)', value: '192.168.0.3.*' },
    { key: 'all', value: '.*' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Instance')
  + g.dashboard.variable.custom.generalOptions.withCurrent('homelab (prod)', '192.168.0.4.*');

local sm_q(expr, legend='') =
  c.vmQ(std.strReplace(expr, 'application="%s"', 'application="%s",instance=~"$instance"'), legend);

local scalableMarketAlertPanel = c.alertCountPanel('scalable-market', col=0);

local sm_scanRateStat =
  g.panel.stat.new('Scans / sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    sm_q('arbitrage_scan_rate{application="market.scalable"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local sm_pathsRateStat =
  g.panel.stat.new('Paths / sec')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    sm_q('arbitrage_paths_rate{application="market.scalable"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local sm_maxProfitStat =
  g.panel.stat.new('Max Profit (USDC)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    sm_q('arbitrage_max_profit_usdc{application="market.scalable"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(4)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local sm_circuitBreakerStat =
  g.panel.stat.new('Binance API Circuit (closed=1)')
  + c.statPos(4)
  + g.panel.stat.queryOptions.withTargets([
    sm_q('resilience4j_circuitbreaker_state{application="market.scalable",name="binanceApi",state="closed"} or vector(0)', 'closed'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local sm_scanDurationTs =
  g.panel.timeSeries.new('Scan Duration (P50 / P95 / P99)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('histogram_quantile(0.50, rate(arbitrage_scan_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P50'),
    sm_q('histogram_quantile(0.95, rate(arbitrage_scan_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P95'),
    sm_q('histogram_quantile(0.99, rate(arbitrage_scan_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_opportunitiesTs =
  g.panel.timeSeries.new('Opportunities Found / min')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('(rate(arbitrage_opportunity_found_total{application="market.scalable"}[5m]) or vector(0)) * 60', 'found/min'),
    sm_q('(rate(arbitrage_opportunities_filtered{application="market.scalable"}[5m]) or vector(0)) * 60', 'filtered/min ({{reason}})'),
    sm_q('(rate(arbitrage_opportunity_finding_duration_seconds_count{application="market.scalable"}[5m]) or vector(0)) * 60', 'finding attempts/min'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_persistenceQueueTs =
  g.panel.timeSeries.new('Persistence Queue Sizes')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('arbitrage_paths_persistence_queue_size{application="market.scalable"} or vector(0)', 'Paths'),
    sm_q('orderbook_persistence_queue_size{application="market.scalable"} or vector(0)', 'OrderBook'),
    sm_q('feed_trades_queue_size{application="market.scalable"} or vector(0)', 'Trades'),
    sm_q('feed_prices_queue_size{application="market.scalable"} or vector(0)', 'Prices'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_persistenceRatesTs =
  g.panel.timeSeries.new('Persistence Rates (persisted/sec)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('(rate(arbitrage_paths_persisted_total{application="market.scalable"}[5m]) or vector(0)) * 60', 'Paths/min'),
    sm_q('(rate(orderbook_persistence_total{application="market.scalable"}[5m]) or vector(0)) * 60', 'OrderBook/min'),
    sm_q('(rate(feed_trades_persisted{application="market.scalable"}[5m]) or vector(0)) * 60', 'Trades/min'),
    sm_q('(rate(feed_prices_persisted{application="market.scalable"}[5m]) or vector(0)) * 60', 'Prices/min'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_persistenceErrorsTs =
  g.panel.timeSeries.new('Persistence Errors / Dropped (5m)')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('increase(arbitrage_paths_persistence_errors_total{application="market.scalable"}[5m]) or vector(0)', 'Paths errors'),
    sm_q('increase(orderbook_persistence_errors_total{application="market.scalable"}[5m]) or vector(0)', 'OrderBook errors'),
    sm_q('increase(arbitrage_paths_persistence_dropped_total{application="market.scalable"}[5m]) or vector(0)', 'Paths dropped'),
    sm_q('increase(orderbook_persistence_dropped_total{application="market.scalable"}[5m]) or vector(0)', 'OrderBook dropped'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_persistenceLatencyTs =
  g.panel.timeSeries.new('Persistence Latency (P95)')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('histogram_quantile(0.95, rate(arbitrage_paths_persistence_latency_ms_bucket{application="market.scalable"}[5m]) or vector(0))', 'Paths'),
    sm_q('histogram_quantile(0.95, rate(orderbook_persistence_latency_ms_bucket{application="market.scalable"}[5m]) or vector(0))', 'OrderBook'),
    sm_q('histogram_quantile(0.95, rate(feed_trades_latency_bucket{application="market.scalable"}[5m]) or vector(0))', 'Trades'),
    sm_q('histogram_quantile(0.95, rate(feed_prices_latency_bucket{application="market.scalable"}[5m]) or vector(0))', 'Prices'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_executionDurationTs =
  g.panel.timeSeries.new('Execution Duration (P95)')
  + c.tsPos(0, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('histogram_quantile(0.95, rate(execution_trade_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Trade ({{service}})'),
    sm_q('histogram_quantile(0.95, rate(execution_slippage_evaluation_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Slippage eval'),
    sm_q('histogram_quantile(0.95, rate(execution_recovery_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Recovery'),
    sm_q('histogram_quantile(0.95, rate(execution_audit_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Audit'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_executionWorkflowTs =
  g.panel.timeSeries.new('Execution Workflow & Results')
  + c.tsPos(1, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('histogram_quantile(0.95, rate(execution_workflow_total_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Workflow P95'),
    sm_q('(rate(execution_trade_result_total{application="market.scalable"}[5m]) or vector(0)) * 60', 'Results/min ({{status}})'),
    sm_q('(increase(arbitrage_execution_aborted_total{application="market.scalable"}[5m]) or vector(0))', 'Aborted ({{reason}})'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_profitDeviationTs =
  g.panel.timeSeries.new('Profit & Dust Deviation (USDC)')
  + c.tsPos(0, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('arbitrage_execution_profit_deviation{application="market.scalable"} or vector(0)', 'Profit deviation'),
    sm_q('arbitrage_execution_dust_deviation{application="market.scalable"} or vector(0)', 'Dust deviation ({{instrument}})'),
    sm_q('increase(arbitrage_dust_amount_total{application="market.scalable"}[5m]) or vector(0))', 'Dust accumulated ({{type}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_slippageTs =
  g.panel.timeSeries.new('Slippage Detection')
  + c.tsPos(1, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('arbitrage_slippage_detected{application="market.scalable"} or vector(0)', 'Detected ({{status}})'),
    sm_q('(rate(arbitrage_execution_aborted_total{application="market.scalable",reason="slippage"}[5m]) or vector(0)) * 60', 'Aborted due to slippage/min'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_smokeCheckTs =
  g.panel.timeSeries.new('Smoke Check Results (5m)')
  + c.tsPos(0, 5)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('increase(smoke_check_passed_total{application="market.scalable"}[5m]) or vector(0)', 'Passed'),
    sm_q('increase(smoke_check_failed_total{application="market.scalable"}[5m]) or vector(0)', 'Failed ({{reason}})'),
    sm_q('histogram_quantile(0.95, rate(smoke_check_latency_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Latency P95'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_kafkaTs =
  g.panel.timeSeries.new('Kafka Operations Duration (P95)')
  + c.tsPos(1, 5)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('histogram_quantile(0.95, rate(kafka_publish_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Publish P95'),
    sm_q('histogram_quantile(0.95, rate(kafka_consume_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'Consume P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_explorerTs =
  g.panel.timeSeries.new('Explorer Metrics')
  + c.tsPos(0, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('(rate(matrix_subspace_explored_total{application="matrix.explorer"}[5m]) or vector(0)) * 60', 'Subspaces/min ({{type}})'),
    sm_q('histogram_quantile(0.95, rate(matrix_subspace_exploration_time_seconds_bucket{application="matrix.explorer"}[5m]) or vector(0))', 'Exploration P95 ({{type}})'),
    sm_q('(rate(matrix_point_state_saved_count_total{application="matrix.explorer"}[5m]) or vector(0)) * 60', 'States saved/min ({{type}})'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_explorerDistributionTs =
  g.panel.timeSeries.new('Explorer Distributions (USDT)')
  + c.tsPos(1, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('matrix_subspace_max_total_usdt{application="matrix.explorer"} or vector(0)', 'Max total ({{type}})'),
    sm_q('matrix_subspace_min_total_usdt{application="matrix.explorer"} or vector(0)', 'Min total ({{type}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_explorerScoresTs =
  g.panel.timeSeries.new('Asset Scores')
  + c.tsPos(0, 7)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('matrix_asset_score{application="matrix.explorer"} or vector(0)', 'Score ({{indicator}})'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_explorerTimingTs =
  g.panel.timeSeries.new('Explorer Timing')
  + c.tsPos(1, 7)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('histogram_quantile(0.95, rate(matrix_points_best_buy_asset_time_seconds_bucket{application="matrix.explorer"}[5m]) or vector(0))', 'Best buy asset P95'),
    sm_q('(rate(matrix_subspace_explored_total{application="matrix.explorer"}[5m]) or vector(0)) * 60', 'Subspaces/min'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_binanceJobTs =
  g.panel.timeSeries.new('Binance Job Strategies')
  + c.tsPos(0, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('matrix_binance_strategies_raw{application="binance-job"} or vector(0)', 'Raw strategies ({{client}}, {{asset}})'),
    sm_q('matrix_binance_strategies_usdt{application="binance-job"} or vector(0)', 'USDT strategies ({{client}}, {{asset}})'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_binanceApiTs =
  g.panel.timeSeries.new('Binance API Latency (P50 / P95 / P99)')
  + c.tsPos(0, 9)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('histogram_quantile(0.50, rate(binance_api_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P50'),
    sm_q('histogram_quantile(0.95, rate(binance_api_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P95'),
    sm_q('histogram_quantile(0.99, rate(binance_api_duration_seconds_bucket{application="market.scalable"}[5m]) or vector(0))', 'P99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_httpRequestsTs =
  g.panel.timeSeries.new('HTTP Requests / sec')
  + c.tsPos(1, 9)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('sum(rate(http_server_requests_seconds_count{application=~"market\\.scalable|matrix\\.explorer|technicals|vault"}[5m]) or vector(0)) by (application, uri, status)', '{{application}} {{uri}} {{status}}'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_jvmHeapTs =
  g.panel.timeSeries.new('Heap Memory (Used / Max)')
  + c.tsPos(0, 10)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('jvm_memory_used_bytes{application=~"market\\.scalable|matrix\\.explorer|technicals|vault",area="heap"} or vector(0)', 'Used ({{application}})'),
    sm_q('jvm_memory_max_bytes{application=~"market\\.scalable|matrix\\.explorer|technicals|vault",area="heap"} or vector(0)', 'Max ({{application}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_cpuAndGcTs =
  g.panel.timeSeries.new('CPU & GC Pause')
  + c.tsPos(1, 10)
  + g.panel.timeSeries.queryOptions.withTargets([
    sm_q('process_cpu_usage{application=~"market\\.scalable|matrix\\.explorer|technicals|vault"} or vector(0)', 'CPU ({{application}})'),
    sm_q('rate(jvm_gc_pause_seconds_sum{application=~"market\\.scalable|matrix\\.explorer|technicals|vault"}[5m]) or vector(0)', 'GC pause/s ({{application}}, {{cause}})'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percentunit')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sm_troubleGuide = c.serviceTroubleshootingGuide('scalable-market', [
  { symptom: 'Scan Rate Drop', runbook: 'scalable-market/scan-stall', check: 'Check Scans/sec stat and review scan duration trends' },
  { symptom: 'Binance API Down', runbook: 'scalable-market/api-failure', check: 'Monitor Circuit Breaker state and check Binance latency' },
  { symptom: 'No Opportunities', runbook: 'scalable-market/market-dry', check: 'Review Opportunities Found metric and market conditions' },
  { symptom: 'Persistence Backlog', runbook: 'scalable-market/persistence-lag', check: 'Check Queue Sizes panel and ClickHouse health' },
  { symptom: 'JVM Memory High', runbook: 'scalable-market/oom-risk', check: 'Check Heap Memory panel and review GC activity' },
  { symptom: 'Kafka Lag', runbook: 'scalable-market/kafka-lag', check: 'Check Kafka Operations Duration and consumer lag' },
  { symptom: 'Execution Failures', runbook: 'scalable-market/execution-errors', check: 'Check Execution Workflow panel and abort reasons' },
  { symptom: 'Slippage Detected', runbook: 'scalable-market/slippage-alert', check: 'Check Slippage Detection panel and instrument liquidity' },
], y=93);

local sm_logsPanelArbitraje =
  g.panel.logs.new('Arbitraje Logs')
  + c.pos(0, 97, 12, 8)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"scalable-orderbook.*"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local sm_logsPanelExplorer =
  g.panel.logs.new('Explorer Logs')
  + c.pos(12, 97, 12, 8)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service="scalable-explorer"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local sm_logsPanelBinanceJob =
  g.panel.logs.new('Binance Job Logs')
  + c.pos(0, 105, 12, 8)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"binance.*"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local sm_logsPanelOther =
  g.panel.logs.new('Vault & Technicals Logs')
  + c.pos(12, 105, 12, 8)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"vault|technicals"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local scalableMarketPanels = [
  g.panel.row.new('Scalable Market') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Status') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  scalableMarketAlertPanel, sm_scanRateStat, sm_pathsRateStat, sm_maxProfitStat, sm_circuitBreakerStat,

  g.panel.row.new('Arbitrage Engine') + c.pos(0, 6, 24, 1),
  sm_scanDurationTs, sm_opportunitiesTs,

  g.panel.row.new('Data Persistence') + c.pos(0, 15, 24, 1),
  sm_persistenceQueueTs, sm_persistenceRatesTs,

  g.panel.row.new('Data Persistence (cont.)') + c.pos(0, 23, 24, 1),
  sm_persistenceErrorsTs, sm_persistenceLatencyTs,

  g.panel.row.new('Execution') + c.pos(0, 31, 24, 1),
  sm_executionDurationTs, sm_executionWorkflowTs,

  g.panel.row.new('Execution (cont.)') + c.pos(0, 39, 24, 1),
  sm_profitDeviationTs, sm_slippageTs,

  g.panel.row.new('Smoke Checks & Kafka') + c.pos(0, 47, 24, 1),
  sm_smokeCheckTs, sm_kafkaTs,

  g.panel.row.new('Explorer') + c.pos(0, 55, 24, 1),
  sm_explorerTs, sm_explorerDistributionTs,

  g.panel.row.new('Explorer (cont.)') + c.pos(0, 63, 24, 1),
  sm_explorerScoresTs, sm_explorerTimingTs,

  g.panel.row.new('Binance Job') + c.pos(0, 71, 24, 1),
  sm_binanceJobTs,

  g.panel.row.new('Binance API & HTTP') + c.pos(0, 79, 24, 1),
  sm_binanceApiTs, sm_httpRequestsTs,

  g.panel.row.new('JVM') + c.pos(0, 87, 24, 1),
  sm_jvmHeapTs, sm_cpuAndGcTs,

  g.panel.row.new('Troubleshooting') + c.pos(0, 93, 24, 1),
  sm_troubleGuide,

  g.panel.row.new('Logs — Arbitraje & Explorer') + c.pos(0, 98, 24, 1),
  sm_logsPanelArbitraje, sm_logsPanelExplorer,

  g.panel.row.new('Logs — Binance Job & Vault') + c.pos(0, 106, 24, 1),
  sm_logsPanelBinanceJob, sm_logsPanelOther,
];

// max y+h: logsPanelOther at y=105, h=8 → 113
local scalableMarketHeight = 113;

// ════════════════════════════════════════════════════════════════════════════
// ── 6. pipeline/scalable-pathranker ─────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local pr_svc = 'service="scalable-pathranker"';

local scalablePathrankerAlertPanel = c.alertCountPanel('pathranker', col=0);

local pr_profitablePathsStat =
  g.panel.stat.new('Profitable Paths')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('pathranker_profitable_paths{' + pr_svc + '} or vector(0)'),
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

local pr_totalPathsStat =
  g.panel.stat.new('Total Paths')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('pathranker_total_paths{' + pr_svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local pr_bestReturnStat =
  g.panel.stat.new('Best Return Ratio')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('pathranker_best_return_ratio{' + pr_svc + '} or vector(0)'),
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

local pr_pathsTs =
  g.panel.timeSeries.new('Paths Found per Scan')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pathranker_total_paths{' + pr_svc + '} or vector(0)', 'total'),
    c.vmQ('pathranker_profitable_paths{' + pr_svc + '} or vector(0)', 'profitable'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pr_scanRateTs =
  g.panel.timeSeries.new('Scan Rate & Duration')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(pathranker_scans_total{' + pr_svc + '}[5m]) or vector(0)', 'scans/s'),
    c.vmQ(
      'rate(pathranker_scan_duration_seconds_sum{' + pr_svc + '}[5m]) / rate(pathranker_scan_duration_seconds_count{' + pr_svc + '}[5m]) or vector(0)',
      'avg duration (s)'
    ),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pr_returnRatioTs =
  g.panel.timeSeries.new('Best Return Ratio over Time')
  + c.pos(0, 13, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('pathranker_best_return_ratio{' + pr_svc + '} or vector(0)', 'best ratio'),
  ])
  + g.panel.timeSeries.standardOptions.withDecimals(5)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pr_logsPanel =
  g.panel.logs.new('Pathranker Logs')
  + c.logPos(24)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service="podman-scalable-pathranker"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local pr_troubleGuide = c.serviceTroubleshootingGuide('pathranker', [
  { symptom: 'Zero paths found', runbook: 'pathranker/no-paths', check: 'Check instruments gauge — if 0, orderbook is not pushing to VM' },
  { symptom: 'No profitable paths', runbook: 'pathranker/market-dry', check: 'Best Return Ratio < 1.0 — market too tight or fees too high' },
  { symptom: 'Metrics missing', runbook: 'pathranker/no-metrics', check: 'Push goroutine failed — check VM_URL env and VM reachability' },
  { symptom: 'Scan duration spike', runbook: 'pathranker/slow-scan', check: 'Graph too dense — consider reducing MAX_HOPS or ENDPOINTS' },
  { symptom: 'Worker stopped', runbook: 'pathranker/temporal-dead', check: 'Check Temporal UI — workflow may have failed; restart container' },
], y=35);

local scalablePathrankerPanels = [
  g.panel.row.new('Scalable Pathranker') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Status') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  scalablePathrankerAlertPanel, pr_profitablePathsStat, pr_totalPathsStat, pr_bestReturnStat,

  g.panel.row.new('Scanning') + c.pos(0, 6, 24, 1),
  pr_pathsTs, pr_scanRateTs,
  pr_returnRatioTs,

  g.panel.row.new('Logs') + c.pos(0, 23, 24, 1),
  pr_logsPanel,

  g.panel.row.new('Troubleshooting') + c.pos(0, 34, 24, 1),
  pr_troubleGuide,
];

// max y+h: troubleGuide at y=35, h=5 → 40
local scalablePathrankerHeight = 40;

// ════════════════════════════════════════════════════════════════════════════
// ── 7. pipeline/route-comparison ────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local rc_hQ(expr, legend='') =
  g.query.prometheus.new('$huntermetrics', expr)
  + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {});

local rc_directHitsStat =
  g.panel.stat.new('Direct Hits')
  + c.pos(0, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    rc_hQ('hunter_route_hits{route="direct"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local rc_aucklandHitsStat =
  g.panel.stat.new('Auckland Hits')
  + c.pos(6, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    rc_hQ('hunter_route_hits{route="auckland"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local rc_pragueHitsStat =
  g.panel.stat.new('Prague Hits')
  + c.pos(12, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    rc_hQ('hunter_route_hits{route="prague"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local rc_overlapStat =
  g.panel.stat.new('URL Overlap')
  + c.pos(18, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    rc_hQ('hunter_route_overlap'),
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

local rc_hitsOverTimeTs =
  g.panel.timeSeries.new('Hits per Route')
  + c.pos(0, 5, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    rc_hQ('hunter_route_hits{route="direct"}', 'Direct'),
    rc_hQ('hunter_route_hits{route="auckland"}', 'Auckland (NZ)'),
    rc_hQ('hunter_route_hits{route="prague"}', 'Prague (CZ)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local rc_exclusiveOverTimeTs =
  g.panel.timeSeries.new('Exclusive Finds per Route')
  + c.pos(12, 5, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    rc_hQ('hunter_route_exclusive{route="direct"}', 'Direct only'),
    rc_hQ('hunter_route_exclusive{route="auckland"}', 'Auckland only'),
    rc_hQ('hunter_route_exclusive{route="prague"}', 'Prague only'),
    rc_hQ('hunter_route_overlap', 'Overlap (2+ routes)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local rc_latencyTs =
  g.panel.timeSeries.new('Search Latency per Route')
  + c.pos(0, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    rc_hQ('hunter_route_latency_ms{route="direct"}', 'Direct'),
    rc_hQ('hunter_route_latency_ms{route="auckland"}', 'Auckland (NZ)'),
    rc_hQ('hunter_route_latency_ms{route="prague"}', 'Prague (CZ)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local rc_failuresTs =
  g.panel.timeSeries.new('Route Failures')
  + c.pos(12, 14, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    rc_hQ('hunter_route_failed{route="direct"}', 'Direct'),
    rc_hQ('hunter_route_failed{route="auckland"}', 'Auckland (NZ)'),
    rc_hQ('hunter_route_failed{route="prague"}', 'Prague (CZ)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 1 },
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local rc_efficiencyBarTs =
  g.panel.timeSeries.new('Route Value — Exclusive vs Overlap')
  + c.pos(0, 23, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    rc_hQ('hunter_route_exclusive{route="direct"} / (hunter_route_hits{route="direct"} > 0) or vector(0)', 'Direct exclusive %'),
    rc_hQ('hunter_route_exclusive{route="auckland"} / (hunter_route_hits{route="auckland"} > 0) or vector(0)', 'Auckland exclusive %'),
    rc_hQ('hunter_route_exclusive{route="prague"} / (hunter_route_hits{route="prague"} > 0) or vector(0)', 'Prague exclusive %'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percentunit')
  + g.panel.timeSeries.standardOptions.withDecimals(1)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local routeComparisonPanels = [
  g.panel.row.new('Route Comparison — Multi-Route Firecrawl') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Route Stats') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  rc_directHitsStat, rc_aucklandHitsStat, rc_pragueHitsStat, rc_overlapStat,

  g.panel.row.new('Hits & Exclusive Finds') + c.pos(0, 6, 24, 1),
  rc_hitsOverTimeTs, rc_exclusiveOverTimeTs,

  g.panel.row.new('Latency & Failures') + c.pos(0, 15, 24, 1),
  rc_latencyTs, rc_failuresTs,

  g.panel.row.new('Route Efficiency') + c.pos(0, 24, 24, 1),
  rc_efficiencyBarTs,
];

// max y+h: efficiencyBarTs at y=23, h=8 → 31
local routeComparisonHeight = 31;

// ════════════════════════════════════════════════════════════════════════════
// ── 8. pipeline/arbitraje ───────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local arb_svc = 'service="matrix-arbitraje"';

local arbitrajeAlertPanel = c.alertCountPanel('arbitraje', col=0);

local arb_scanRateStat =
  g.panel.stat.new('Scans / sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('arbitrage_scan_rate_per_sec{' + arb_svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local arb_pathsRateStat =
  g.panel.stat.new('Paths / sec')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('arbitrage_paths_rate_per_sec{' + arb_svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local arb_maxProfitStat =
  g.panel.stat.new('Max Profit (USDC)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('arbitrage_max_profit_usdc{' + arb_svc + '} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(4)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local arb_scanRateTs =
  g.panel.timeSeries.new('Scan & Path Rate')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('arbitrage_scan_rate_per_sec{' + arb_svc + '} or vector(0)', 'scans/s'),
    c.vmQ('arbitrage_paths_rate_per_sec{' + arb_svc + '} or vector(0)', 'paths/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local arb_opportunitiesTs =
  g.panel.timeSeries.new('Opportunities & Filters')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('arbitrage_opportunities_total{' + arb_svc + '} or vector(0)', 'total found'),
    c.vmQ(
      '(rate(arbitrage_opportunities_filtered_total{' + arb_svc + '}[5m]) or vector(0)) * 60',
      'filtered ({{reason}})/min'
    ),
    c.vmQ('arbitrage_scans_total{' + arb_svc + '} or vector(0)', 'scans total'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local arb_profitTs =
  g.panel.timeSeries.new('Max Profit over Time (USDC)')
  + c.pos(0, 13, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('arbitrage_max_profit_usdc{' + arb_svc + '} or vector(0)', 'max profit USDC'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local arb_logsPanel = c.serviceLogsPanel('Arbitraje Logs', 'arbitraje', y=24);

local arb_troubleGuide = c.serviceTroubleshootingGuide('arbitraje', [
  { symptom: 'Scan Rate Drop', runbook: 'arbitraje/scan-stall', check: 'Check Scans/sec stat — drop means the scanning loop stalled' },
  { symptom: 'No Opportunities', runbook: 'arbitraje/market-dry', check: 'Review Opportunities Total — market may be dry or service hung' },
  { symptom: 'Metrics Missing', runbook: 'arbitraje/instrumentation', check: 'Missing: circuit breaker, binance API latency, JVM, HTTP — needs Micrometer config' },
], y=35);

local arbitrajePanels = [
  g.panel.row.new('Arbitraje — Market Scalable') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Status') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  arbitrajeAlertPanel, arb_scanRateStat, arb_pathsRateStat, arb_maxProfitStat,

  g.panel.row.new('Arbitrage Engine') + c.pos(0, 6, 24, 1),
  arb_scanRateTs, arb_opportunitiesTs,
  arb_profitTs,

  g.panel.row.new('Logs') + c.pos(0, 23, 24, 1),
  arb_logsPanel,

  g.panel.row.new('Troubleshooting') + c.pos(0, 34, 24, 1),
  arb_troubleGuide,
];

// max y+h: troubleGuide at y=35, h=5 → 40
local arbitrajeHeight = 40;

// ════════════════════════════════════════════════════════════════════════════
// ── 9. pipeline/vector ──────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

local vec_hostVar =
  g.dashboard.variable.custom.new('host', [
    { key: 'All', value: '.*' },
    { key: 'heater', value: 'heater' },
    { key: 'homelab', value: 'homelab' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Host')
  + g.dashboard.variable.custom.generalOptions.withCurrent('heater', 'heater');

local vectorAlertPanel = c.alertCountPanel('vector', col=0);

local vec_uptimeStat =
  g.panel.stat.new('Vector Uptime')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(vector_uptime_seconds{host=~"$host"}) or vector(0)', '{{host}}'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local vec_eventsInStat =
  g.panel.stat.new('Events In/sec')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_received_events_total{host=~"$host"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local vec_eventsOutStat =
  g.panel.stat.new('Events Out/sec')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_sent_events_total{host=~"$host"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local vec_errorRateStat =
  g.panel.stat.new('Error Rate')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vector_component_errors_total{host=~"$host"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 0.01 },
    { color: 'red', value: 0.1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local vec_eventsTs =
  g.panel.timeSeries.new('Events per Component (In)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (rate(vector_component_received_events_total{host=~"$host"}[5m]) or vector(0)))',
      '{{host}} · {{component_id}} ({{component_type}})'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vec_eventsOutTs =
  g.panel.timeSeries.new('Events per Component (Out)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (rate(vector_component_sent_events_total{host=~"$host"}[5m]) or vector(0)))',
      '{{host}} · {{component_id}} ({{component_type}})'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vec_errorsTs =
  g.panel.timeSeries.new('Errors per Component')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(rate(vector_component_errors_total{host=~"$host"}[5m]) or vector(0))',
      '{{host}} · {{component_id}} — {{error_type}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vec_bytesTs =
  g.panel.timeSeries.new('Bytes Processed per Component')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (rate(vector_component_sent_bytes_total{host=~"$host"}[5m]) or vector(0)))',
      '{{host}} · {{component_id}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vec_logsPanel =
  g.panel.logs.new('Vector Service Logs')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host=~"$host",service="vector"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local vec_troubleGuide = c.serviceTroubleshootingGuide('vector', [
  { symptom: 'Vector Down', runbook: 'vector/not-running', check: 'Verify Vector Uptime stat and check service logs' },
  { symptom: 'Events Backlog', runbook: 'vector/backpressure', check: 'Compare Events In/sec vs Out/sec - check for buffering' },
  { symptom: 'High Error Rate', runbook: 'vector/errors', check: 'Review Error Rate stat and "Errors & Bytes" trends' },
  { symptom: 'Data Loss', runbook: 'vector/data-loss', check: 'Check processed bytes and component error logs' },
], y=35);

local vectorPanels = [
  g.panel.row.new('Vector') + c.pos(0, 0, 24, 1),
  g.panel.row.new('Status') + c.pos(0, 1, 24, 1),
  // Transparent spacer
  g.panel.text.new('') + c.pos(0, 2, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  vectorAlertPanel, vec_uptimeStat, vec_eventsInStat, vec_eventsOutStat, vec_errorRateStat,
  g.panel.row.new('Throughput') + c.pos(0, 6, 24, 1),
  vec_eventsTs, vec_eventsOutTs,
  g.panel.row.new('Errors & Bytes') + c.pos(0, 14, 24, 1),
  vec_errorsTs, vec_bytesTs,
  g.panel.row.new('Logs') + c.pos(0, 23, 24, 1),
  vec_logsPanel,
  g.panel.row.new('Troubleshooting') + c.pos(0, 34, 24, 1),
  vec_troubleGuide,
];

// max y+h: troubleGuide at y=35, h=5 → 40
local vectorHeight = 40;

// ════════════════════════════════════════════════════════════════════════════
// ── Dashboard assembly ───────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════
//
// Cumulative offsets:
//   jobHunter            offset=0,   height=40
//   hunterSources        offset=40,  height=60
//   hunterPipeline       offset=100, height=95
//   hunterNamespaceHealth offset=195, height=15
//   scalableMarket       offset=210, height=113
//   scalablePathranker   offset=323, height=40
//   routeComparison      offset=363, height=31
//   arbitraje            offset=394, height=40
//   vector               offset=434, height=40

g.dashboard.new('Pipeline')
+ g.dashboard.withUid('home-pipeline')
+ g.dashboard.withDescription('Hunter job pipeline and Scalable Market data processing — sources, ranking, routing.')
+ g.dashboard.withTags(['pipeline', 'hunter', 'scalable-market'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, hs_hunterLogsDsVar, hs_slugVar, sm_instanceVar, vec_hostVar, c.vmAdhocVar, c.vlogsAdhocVar])
+ g.dashboard.withPanels(
    c.withYOffset(jobHunterPanels, 0)
    + c.withYOffset(hunterSourcesPanels, jobHunterHeight)
    + c.withYOffset(hunterPipelinePanels, jobHunterHeight + hunterSourcesHeight)
    + c.withYOffset(hunterNamespaceHealthPanels, jobHunterHeight + hunterSourcesHeight + hunterPipelineHeight)
    + c.withYOffset(scalableMarketPanels, jobHunterHeight + hunterSourcesHeight + hunterPipelineHeight + hunterNamespaceHealthHeight)
    + c.withYOffset(scalablePathrankerPanels, jobHunterHeight + hunterSourcesHeight + hunterPipelineHeight + hunterNamespaceHealthHeight + scalableMarketHeight)
    + c.withYOffset(routeComparisonPanels, jobHunterHeight + hunterSourcesHeight + hunterPipelineHeight + hunterNamespaceHealthHeight + scalableMarketHeight + scalablePathrankerHeight)
    + c.withYOffset(arbitrajePanels, jobHunterHeight + hunterSourcesHeight + hunterPipelineHeight + hunterNamespaceHealthHeight + scalableMarketHeight + scalablePathrankerHeight + routeComparisonHeight)
    + c.withYOffset(vectorPanels, jobHunterHeight + hunterSourcesHeight + hunterPipelineHeight + hunterNamespaceHealthHeight + scalableMarketHeight + scalablePathrankerHeight + routeComparisonHeight + arbitrajeHeight)
  )
