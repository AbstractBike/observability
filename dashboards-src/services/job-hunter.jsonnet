local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// job-hunter pushes metrics via Vector local HTTP to VictoriaMetrics.
// Key metrics:
//   hunter_jobs_found{slug,mode,tier}          — offers found per run
//   hunter_search_duration_seconds{slug,mode}  — total search time
//   hunter_email_sent{slug,status}             — email delivery status
//   hunter_sources_searched{slug}              — unique sources queried
//   hunter_errors_total{slug,phase}            — errors by phase

// ── Row 0: Status stats ─────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('job-hunter', col=0);

local totalOffersTodayStat =
  g.panel.stat.new('Offers Today')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(increase(hunter_jobs_found{tier="all"}[1d])) by (slug) or vector(0)', '{{slug}}'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local avgScoreStat =
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

local errorsStat =
  g.panel.stat.new('Errors (1h)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(increase(hunter_errors_total[1h])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + c.errorThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

// ── Row 1: Time series ──────────────────────────────────────────────────────

local jobsFoundTs =
  g.panel.timeSeries.new('Offers Found by Slug')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('hunter_jobs_found{tier="all"}', '{{slug}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' });

local searchDurationTs =
  g.panel.timeSeries.new('Search Duration by Slug')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('hunter_search_duration_seconds', '{{slug}} / {{mode}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: Delivery & errors ────────────────────────────────────────────────

local emailStatusTs =
  g.panel.timeSeries.new('Email Delivery Status')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('hunter_email_sent', '{{slug}} / {{status}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local errorsTs =
  g.panel.timeSeries.new('Errors by Phase')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('hunter_errors_total', '{{slug}} / {{phase}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Logs ────────────────────────────────────────────────────────────────────

local logsPanel =
  c.serviceLogsPanel('job-hunter Logs', 'job_hunter', host='heater');

// ── Troubleshooting ─────────────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('job-hunter', [
  { symptom: 'No offers found', runbook: 'job-hunter/dry-spell', check: '"Offers Found" flat at zero — check search sources and network' },
  { symptom: 'Email failures', runbook: 'job-hunter/email', check: '"Email Delivery Status" shows errors — check SMTP config' },
  { symptom: 'High error count', runbook: 'job-hunter/errors', check: '"Errors by Phase" rising — inspect logs for stack traces' },
  { symptom: 'Slow searches', runbook: 'job-hunter/latency', check: '"Search Duration" above 60s — check source availability' },
], y=35);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Services — job_hunter')
+ g.dashboard.withUid('services-job-hunter')
+ g.dashboard.withDescription('job_hunter: automated job search — offers found, search duration, email delivery, errors.')
+ g.dashboard.withTags(['services', 'job-hunter'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, totalOffersTodayStat, avgScoreStat, errorsStat,
  g.panel.row.new('Search Activity') + c.pos(0, 6, 24, 1),
  jobsFoundTs, searchDurationTs,
  g.panel.row.new('Delivery & Errors') + c.pos(0, 14, 24, 1),
  emailStatusTs, errorsTs,
  g.panel.row.new('Logs') + c.pos(0, 23, 24, 1),
  logsPanel,
  g.panel.row.new('Troubleshooting') + c.pos(0, 34, 24, 1),
  troubleGuide,
])
