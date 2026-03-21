local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Hunter Pipeline — Daily Job Search Workflow ─────────────────────────────
//
// Temporal workflow: HunterPipelineWorkflow (hunter-daily-<slug>)
// Schedule: hunter-daily-<slug>, 07:00 mar-vie
// Activities: SearchActivity → ScrapeExtractActivity → RankActivity → SummarizeRenderSendActivity
//
// Storage topology (per environment):
//   VictoriaLogs  — document store (job payloads, source configs)
//   VictoriaMetrics — numeric counters and histograms
//
// VictoriaLogs _msg tags:
//   job_extracted  ← ScrapeExtractActivity writes scraped+parsed job data
//   job_ranked     ← RankActivity writes scored jobs with tier/flags
//   job_sent       ← SummarizeRenderSendActivity marks delivered jobs (dedup)
//   source_config  ← SearchActivity persists source definitions

// ── Variables ───────────────────────────────────────────────────────────────

local envVar =
  g.dashboard.variable.custom.new('env', [
    { key: 'prod', value: 'prod' },
    { key: 'dev', value: 'dev' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Environment')
  + g.dashboard.variable.custom.generalOptions.withCurrent('prod', 'prod');

local hunterLogsDsVar =
  g.dashboard.variable.datasource.new('hunterlogs', 'victoriametrics-logs-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('Hunter Logs')
  + g.dashboard.variable.datasource.withRegex('^VictoriaLogs$');

local hunterMetricsDsVar =
  g.dashboard.variable.datasource.new('huntermetrics', 'victoriametrics-metrics-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('Hunter Metrics')
  + g.dashboard.variable.datasource.withRegex('^VictoriaMetrics$');

// ── Query helpers ───────────────────────────────────────────────────────────

local hQ(expr, legend='') =
  g.query.prometheus.new('$huntermetrics', expr)
  + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {});

local hLogsQ(expr) = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${hunterlogs}' },
  expr: expr,
  refId: 'A',
  queryType: 'range',
  legendFormat: '',
  editorMode: 'code',
};

local hLogsStatsQ(expr, refId='A', step='5m') = {
  datasource: { type: 'victoriametrics-logs-datasource', uid: '${hunterlogs}' },
  expr: expr,
  refId: refId,
  queryType: 'statsRange',
  legendFormat: '',
  editorMode: 'code',
  step: step,
};

// ── Row 0: Key Stats ────────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('hunter-pipeline', col=0);

local jobsTodayStat =
  g.panel.stat.new('Jobs Today')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    hQ('hunter_jobs_extracted_total or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local tier1Stat =
  g.panel.stat.new('Tier 1 Jobs')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    hQ('hunter_jobs_ranked_total{tier="1"} or vector(0)'),
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

local emailsSentStat =
  g.panel.stat.new('Emails Sent')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    hQ('hunter_emails_sent_total or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local linksPanel = c.customExternalLinksPanel([
  { icon: '📊', title: 'Hunter Metrics (VM)', url: 'http://192.168.0.4:9430/vmui' },
  { icon: '📝', title: 'Hunter Logs (VLogs)', url: 'http://192.168.0.4:9432/select/vmui' },
  { icon: '⏱', title: 'Temporal UI', url: 'http://temporal.pin' },
], y=3, x=22);

// ── Row 1: Pipeline Duration & Workflow Status ──────────────────────────────

local pipelineDurationTs =
  g.panel.timeSeries.new('Pipeline Duration (end-to-end)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('histogram_quantile(0.50, rate(hunter_pipeline_duration_seconds_bucket[1h]) or vector(0))', 'P50'),
    hQ('histogram_quantile(0.95, rate(hunter_pipeline_duration_seconds_bucket[1h]) or vector(0))', 'P95'),
    hQ('hunter_pipeline_duration_seconds_sum / hunter_pipeline_duration_seconds_count or vector(0)', 'Avg'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local workflowStatusTs =
  g.panel.timeSeries.new('Workflow Runs (success / fail)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('increase(hunter_workflow_completed_total{status="success"}[1d]) or vector(0)', 'Success'),
    hQ('increase(hunter_workflow_completed_total{status="failed"}[1d]) or vector(0)', 'Failed'),
    hQ('increase(hunter_workflow_completed_total{status="timeout"}[1d]) or vector(0)', 'Timeout'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: SearchActivity ───────────────────────────────────────────────────

local searchSourcesTs =
  g.panel.timeSeries.new('Sources Scanned & Results')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('increase(hunter_search_sources_scanned_total[1d]) or vector(0)', 'Sources scanned'),
    hQ('increase(hunter_search_results_total[1d]) or vector(0)', 'Raw results'),
    hQ('increase(hunter_search_results_after_dedup_total[1d]) or vector(0)', 'After dedup (35d)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local searchDedupTs =
  g.panel.timeSeries.new('Dedup & Fallback')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('increase(hunter_search_dedup_hits_total[1d]) or vector(0)', 'Dedup hits (35d window)'),
    hQ('increase(hunter_search_fallback_total{backend="firecrawl"}[1d]) or vector(0)', 'Firecrawl primary'),
    hQ('increase(hunter_search_fallback_total{backend="zai_mcp"}[1d]) or vector(0)', 'z.ai MCP fallback'),
    hQ('increase(hunter_search_errors_total[1d]) or vector(0)', 'Search errors'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: ScrapeExtractActivity ────────────────────────────────────────────

local scrapeDurationTs =
  g.panel.timeSeries.new('Scrape + LLM Extract Duration')
  + c.tsPos(0, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('histogram_quantile(0.50, rate(hunter_scrape_duration_seconds_bucket[1h]) or vector(0))', 'Scrape P50'),
    hQ('histogram_quantile(0.95, rate(hunter_scrape_duration_seconds_bucket[1h]) or vector(0))', 'Scrape P95'),
    hQ('histogram_quantile(0.50, rate(hunter_llm_extract_duration_seconds_bucket[1h]) or vector(0))', 'LLM Extract P50'),
    hQ('histogram_quantile(0.95, rate(hunter_llm_extract_duration_seconds_bucket[1h]) or vector(0))', 'LLM Extract P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local scrapeResultsTs =
  g.panel.timeSeries.new('Scrape Results (fan-out)')
  + c.tsPos(1, 2)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('increase(hunter_scrape_success_total[1d]) or vector(0)', 'Success'),
    hQ('increase(hunter_scrape_soft_fail_total[1d]) or vector(0)', 'Soft-fail (non-blocking)'),
    hQ('increase(hunter_scrape_hard_fail_total[1d]) or vector(0)', 'Hard-fail'),
    hQ('hunter_scrape_parallelism or vector(0)', 'Active goroutines'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 4: RankActivity ─────────────────────────────────────────────────────

local rankScoresTs =
  g.panel.timeSeries.new('TF-IDF Cosine Similarity Scores')
  + c.tsPos(0, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('hunter_rank_score_avg or vector(0)', 'Avg score'),
    hQ('hunter_rank_score_max or vector(0)', 'Max score'),
    hQ('hunter_rank_score_min or vector(0)', 'Min score'),
    hQ('hunter_rank_score_p50 or vector(0)', 'Median'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.standardOptions.withDecimals(3)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local rankTiersTs =
  g.panel.timeSeries.new('Tier Distribution & Red Flags')
  + c.tsPos(1, 3)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('increase(hunter_jobs_ranked_total{tier="1"}[1d]) or vector(0)', 'Tier 1'),
    hQ('increase(hunter_jobs_ranked_total{tier="2"}[1d]) or vector(0)', 'Tier 2'),
    hQ('increase(hunter_jobs_ranked_total{tier="3"}[1d]) or vector(0)', 'Tier 3'),
    hQ('increase(hunter_red_flags_total[1d]) or vector(0)', 'Red flags detected'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 5: SummarizeRenderSendActivity ──────────────────────────────────────

local emailRenderTs =
  g.panel.timeSeries.new('Email Render & Send')
  + c.tsPos(0, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('histogram_quantile(0.50, rate(hunter_email_render_duration_seconds_bucket[1h]) or vector(0))', 'Claude render P50'),
    hQ('histogram_quantile(0.95, rate(hunter_email_render_duration_seconds_bucket[1h]) or vector(0))', 'Claude render P95'),
    hQ('histogram_quantile(0.95, rate(hunter_smtp_send_duration_seconds_bucket[1h]) or vector(0))', 'SMTP send P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local emailDeliveryTs =
  g.panel.timeSeries.new('Delivery Status')
  + c.tsPos(1, 4)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('increase(hunter_emails_sent_total[1d]) or vector(0)', 'Emails sent'),
    hQ('increase(hunter_email_jobs_included_total[1d]) or vector(0)', 'Jobs included'),
    hQ('increase(hunter_email_errors_total[1d]) or vector(0)', 'SMTP errors'),
    hQ('increase(hunter_jobs_marked_sent_total[1d]) or vector(0)', 'Jobs marked sent (dedup)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 6: Activity Duration Breakdown ──────────────────────────────────────

local activityDurationTs =
  g.panel.timeSeries.new('Activity Duration Breakdown')
  + c.pos(0, 45, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hQ('histogram_quantile(0.95, rate(hunter_activity_duration_seconds_bucket{activity="search"}[1h]) or vector(0))', 'SearchActivity P95'),
    hQ('histogram_quantile(0.95, rate(hunter_activity_duration_seconds_bucket{activity="scrape_extract"}[1h]) or vector(0))', 'ScrapeExtractActivity P95'),
    hQ('histogram_quantile(0.95, rate(hunter_activity_duration_seconds_bucket{activity="rank"}[1h]) or vector(0))', 'RankActivity P95'),
    hQ('histogram_quantile(0.95, rate(hunter_activity_duration_seconds_bucket{activity="summarize_send"}[1h]) or vector(0))', 'SummarizeRenderSendActivity P95'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 7: VictoriaLogs Event Volume ────────────────────────────────────────

local logsVolumeTs =
  g.panel.timeSeries.new('Event Volume by Type')
  + c.pos(0, 54, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    hLogsStatsQ('_msg:"job_extracted" | stats count() as extracted', 'A'),
    hLogsStatsQ('_msg:"job_ranked" | stats count() as ranked', 'B'),
    hLogsStatsQ('_msg:"job_sent" | stats count() as sent', 'C'),
    hLogsStatsQ('_msg:"source_config" | stats count() as sources', 'D'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 8: Troubleshooting ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('hunter-pipeline', [
  { symptom: 'No jobs extracted', runbook: 'hunter/no-jobs', check: 'Check SearchActivity: sources reachable, Firecrawl healthy, dedup not filtering everything' },
  { symptom: 'All jobs soft-fail', runbook: 'hunter/scrape-fail', check: 'Check ScrapeExtractActivity: target sites blocking, LLM API quota, rate limiting' },
  { symptom: 'Low Tier 1 count', runbook: 'hunter/low-tier1', check: 'Review dimensions.toml weights, profile.md freshness, TF-IDF scores distribution' },
  { symptom: 'Email not sent', runbook: 'hunter/email-fail', check: 'Check SMTP credentials, Gmail app password, Claude API quota for render' },
  { symptom: 'Pipeline timeout', runbook: 'hunter/timeout', check: 'Check Activity Duration panel — which activity is slow? Firecrawl latency? LLM cold start?' },
  { symptom: 'Dedup too aggressive', runbook: 'hunter/dedup-window', check: 'Review 35-day dedup window, check if sources recycling same listings' },
  { symptom: 'Red flags missed', runbook: 'hunter/red-flags', check: 'Review 8 red flag detectors in RankActivity, check is_agency threshold' },
  { symptom: 'Stale sources', runbook: 'hunter/stale-sources', check: 'Check source_config events in VLogs, verify VictoriaLogs source definitions' },
], y=65);

// ── Row 9: Logs — Extracted Jobs ────────────────────────────────────────────

local logsExtracted =
  g.panel.logs.new('job_extracted — Scraped & Parsed Jobs')
  + c.pos(0, 69, 24, 8)
  + g.panel.logs.queryOptions.withTargets([
    hLogsQ('_msg:"job_extracted"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Row 10: Logs — Ranked Jobs ──────────────────────────────────────────────

local logsRanked =
  g.panel.logs.new('job_ranked — Scored & Tiered Jobs')
  + c.pos(0, 78, 24, 8)
  + g.panel.logs.queryOptions.withTargets([
    hLogsQ('_msg:"job_ranked"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Row 11: Logs — Sent Jobs ────────────────────────────────────────────────

local logsSent =
  g.panel.logs.new('job_sent — Delivered via Email')
  + c.pos(0, 87, 24, 8)
  + g.panel.logs.queryOptions.withTargets([
    hLogsQ('_msg:"job_sent"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Hunter Pipeline — Daily Job Search')
+ g.dashboard.withUid('hunter-pipeline-main')
+ g.dashboard.withDescription(|||
  HunterPipelineWorkflow (Temporal) — daily job search pipeline.
  Activities: Search → ScrapeExtract → Rank → SummarizeRenderSend.
  Storage: VictoriaLogs (job_extracted, job_ranked, job_sent).
  Schedule: 07:00 mar-vie, MaxResults 10, Dedup 35 days.
|||)
+ g.dashboard.withTags(['hunter', 'pipeline', 'temporal', 'job-search', 'observability'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.time.withFrom('now-24h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([envVar, hunterLogsDsVar, hunterMetricsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  alertPanel, jobsTodayStat, tier1Stat, emailsSentStat,
  linksPanel,

  g.panel.row.new('Pipeline Duration & Workflows') + c.pos(0, 6, 24, 1),
  pipelineDurationTs, workflowStatusTs,

  g.panel.row.new('1. SearchActivity') + c.pos(0, 15, 24, 1),
  searchSourcesTs, searchDedupTs,

  g.panel.row.new('2. ScrapeExtractActivity (fan-out)') + c.pos(0, 24, 24, 1),
  scrapeDurationTs, scrapeResultsTs,

  g.panel.row.new('3. RankActivity (TF-IDF + dimensions)') + c.pos(0, 33, 24, 1),
  rankScoresTs, rankTiersTs,

  g.panel.row.new('4. SummarizeRenderSendActivity') + c.pos(0, 42, 24, 1),
  emailRenderTs, emailDeliveryTs,

  g.panel.row.new('Activity Duration Breakdown') + c.pos(0, 46, 24, 1),
  activityDurationTs,

  g.panel.row.new('VictoriaLogs Event Volume') + c.pos(0, 55, 24, 1),
  logsVolumeTs,

  g.panel.row.new('Troubleshooting') + c.pos(0, 64, 24, 1),
  troubleGuide,

  g.panel.row.new('job_extracted') + c.pos(0, 70, 24, 1),
  logsExtracted,

  g.panel.row.new('job_ranked') + c.pos(0, 79, 24, 1),
  logsRanked,

  g.panel.row.new('job_sent') + c.pos(0, 88, 24, 1),
  logsSent,
])
