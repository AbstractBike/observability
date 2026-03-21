// Dashboard: What's Failing?
// Entry point: expanded coverage combining status, activity, SLO, and overview sections.
//
// Sections (top → bottom):
//   0-32  What's Down content (extended job list)
//   33-37 Activity — informational stat panels (GPU, Claude, Hunter, Scalable)
//   38+   SLO Overview (via withYOffset)

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Extended job list (adds node-exporter and vector to the original 12)
local ALL_JOBS = 'alertmanager|clickhouse|elasticsearch-exporter|grafana|nixos-mcp|node-exporter|postgres-exporter|redis-exporter|redpanda|skywalking-oap|temporal|vector|victoriametrics-self|victorialogs-general|vmalert';

// ── Top Stats (y=3) ──────────────────────────────────────────────────────────

local downCountStat =
  g.panel.stat.new('❌ Services Down')
  + c.pos(0, 3, 12, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~"' + ALL_JOBS + '"} == 0) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 2 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local alertCountStat =
  g.panel.stat.new('🚨 Alerts Firing')
  + c.pos(12, 3, 12, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(ALERTS{alertstate="firing"})'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 3 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

// ── Service Status Grid (y=7) ────────────────────────────────────────────────

local servicesList = [
  { job: 'postgres-exporter',      name: 'PostgreSQL',      uid: 'services-postgresql' },
  { job: 'redis-exporter',         name: 'Redis',           uid: 'services-redis' },
  { job: 'temporal',               name: 'Temporal',        uid: 'services-temporal' },
  { job: 'grafana',                name: 'Grafana',         uid: 'observability-grafana' },
  { job: 'alertmanager',           name: 'Alertmanager',    uid: 'observability-alertmanager' },
  { job: 'victoriametrics-self',   name: 'VictoriaMetrics', uid: 'vm-overview' },
  { job: 'victorialogs-general',   name: 'VictoriaLogs',    uid: 'observability-logs' },
  { job: 'clickhouse',             name: 'ClickHouse',      uid: 'services-clickhouse' },
  { job: 'elasticsearch-exporter', name: 'Elasticsearch',   uid: 'services-elasticsearch' },
  { job: 'redpanda',               name: 'Redpanda',        uid: 'services-redpanda' },
  { job: 'skywalking-oap',         name: 'SkyWalking OAP',  uid: 'observability-skywalking' },
  { job: 'vmalert',                name: 'vmalert',         uid: 'observability-vmalert' },
  { job: 'nixos-mcp',              name: 'NixOS MCP',       uid: 'observability-nixos-mcp' },
];

local svcStat(svc, idx) =
  local col = idx % 6;
  local row = std.floor(idx / 6);
  g.panel.stat.new(svc.name)
  + c.pos(col * 4, 5 + row * 3, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(up{job="' + svc.job + '"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name')
  + g.panel.stat.options.withGraphMode('none')
  + { fieldConfig+: { defaults+: { links: [{ title: svc.name + ' Dashboard', url: '/d/' + svc.uid, targetBlank: false }] } } };

local servicesGrid = std.mapWithIndex(function(idx, svc) svcStat(svc, idx), servicesList);

// ── Firing Alerts Table (y=12) ───────────────────────────────────────────────

local alertsTable =
  g.panel.table.new('🚨 Firing Alerts')
  + c.pos(0, 12, 24, 6)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('ALERTS{alertstate="firing"}', ''),
  ])
  + g.panel.table.options.withSortBy([{ displayName: 'alertname', desc: false }])
  + {
    transformations: [
      { id: 'labelsToFields', options: { mode: 'columns' } },
      {
        id: 'organize',
        options: {
          excludeByName: { alertstate: true, Time: true, Value: true },
          indexByName: { alertname: 0, severity: 1, alertgroup: 2 },
        },
      },
    ],
  };

// ── Error Logs (y=21) ────────────────────────────────────────────────────────

// Top error sources — quickly identifies which service dominates the error log
local errorByServiceTable =
  g.panel.table.new('🔊 Top Error Sources')
  + c.pos(0, 21, 24, 4)
  + g.panel.table.queryOptions.withTargets([
    c.vlogsStatsQ('{host="homelab",level="error"} | stats by (service) count() as errors | sort by (errors) desc | limit 10'),
  ]);

local logsPanel =
  g.panel.logs.new('Recent Error Logs (homelab — all services)')
  + c.pos(0, 25, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",level=~"(error|warn|critical)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Activity panels (y=37..41) ───────────────────────────────────────────────

local activityRowY = 37;

local gpuActivityStat =
  g.panel.stat.new('GPU Present')
  + c.pos(0, activityRowY + 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(nvidia_smi_gpu_utilization_ratio{host="heater"}) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local claudeActivityStat =
  g.panel.stat.new('Claude Active (1h rate)')
  + c.pos(6, activityRowY + 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(claude_session_cost_usd[1h])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.options.withColorMode('value');

local hunterActivityStat =
  g.panel.stat.new('Hunter Jobs (5h)')
  + c.pos(12, activityRowY + 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(hunter_jobs_total[5h])) * 300 or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local scalableActivityStat =
  g.panel.stat.new('Scalable Market Req (5h)')
  + c.pos(18, activityRowY + 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(scalable_market_requests_total[5h])) * 300 or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

// activityHeight: row(1) + stats(3) = 4, but total span from y=40 to y=44 (exclusive) = 5
local activityHeight = 5;

// ── SLO Overview panels (prefix slo_) ────────────────────────────────────────
// Copied from slo/overview.jsonnet — panels at their original y coords (0-relative)

local slo_alertPanel = c.alertCountPanel('slo', col=0);

local slo_sloStatPos = [
  c.pos(6, 1, 4, 3),
  c.pos(10, 1, 4, 3),
  c.pos(14, 1, 5, 3),
  c.pos(19, 1, 5, 3),
];

local slo_sloStatPanel(title, errorRatioExpr, targetPct, col) =
  g.panel.stat.new(title)
  + slo_sloStatPos[col]
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((1 - ' + errorRatioExpr + ') * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(3)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: targetPct - 0.5 },
    { color: 'green', value: targetPct },
  ])
  + g.panel.stat.options.withColorMode('background');

local slo_budgetTs(title, errorRatioExpr, targetErrorRatio, col, row) =
  g.panel.timeSeries.new(title)
  + c.tsPos(col, row)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '((1 - (' + errorRatioExpr + ' / ' + std.toString(targetErrorRatio) + ')) * 100) or vector(0)',
      'budget remaining %'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMin(0)
  + g.panel.timeSeries.standardOptions.withMax(100);

local slo_guidancePanel =
  g.panel.text.new('📚 SLO Guidance')
  + c.pos(0, 22, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    **SLO Budget Tracking**: Each service has a monthly error budget. When the budget reaches 0%, the service has violated its SLO target.

    **Budget Formula**: `Remaining % = (1 - (Actual Error Rate / Target Error Rate)) × 100`

    - **Green (>50%)**: Healthy budget, room for degradation
    - **Yellow (0-50%)**: Limited budget, monitor closely
    - **Red (<0%)**: SLO breach, immediate action required

    ### Related Dashboards
    - **[Services Health](/d/services-health)** — Current operational status and error rates
    - **[Observability — Alerts](/d/alerts-dashboard)** — Active alerts and firing rate
    - **[Performance & Optimization](/d/performance-optimization)** — System performance tracking
  |||);

local slo_troubleGuide = c.serviceTroubleshootingGuide('slo', [
  { symptom: 'SLO Violation Alert', runbook: 'slo/violation', check: 'Review specific service compliance stat and error budget burndown' },
  { symptom: 'Budget Exhausted', runbook: 'slo/budget-exhausted', check: 'Check "Error Budget Remaining" charts for affected service' },
  { symptom: 'Unexpected Spike', runbook: 'slo/spike-investigation', check: 'Correlate error budget drop with specific timestamp in logs' },
  { symptom: 'SLO Target Change', runbook: 'slo/target-update', check: 'Verify new target percentage is correctly configured' },
], y=28);

local sloPanels = [
  g.panel.row.new('📊 SLO Overview') + c.pos(0, 0, 24, 1),

  c.externalLinksPanel(y=3),
  slo_alertPanel,
  slo_sloStatPanel('Host Uptime (99.5%)', 'slo:host_uptime:error_ratio_30d', 99.5, 0),
  slo_sloStatPanel('PostgreSQL (99.9%)', 'slo:postgresql:error_ratio_30d', 99.9, 1),
  slo_sloStatPanel('Redis (99.9%)', 'slo:redis:error_ratio_30d', 99.9, 2),
  slo_sloStatPanel('Grafana (99%)', 'slo:grafana:error_ratio_30d', 99.0, 3),

  g.panel.row.new('💯 Error Budget Remaining (30d)') + c.pos(0, 6, 24, 1),
  slo_budgetTs('PostgreSQL Error Budget', 'slo:postgresql:error_ratio_30d', 0.001, 0, 0),
  slo_budgetTs('Redis Error Budget', 'slo:redis:error_ratio_30d', 0.001, 1, 0),
  slo_budgetTs('Host Error Budget', 'slo:host_uptime:error_ratio_30d', 0.005, 0, 1),
  slo_budgetTs('Grafana Error Budget', 'slo:grafana:error_ratio_30d', 0.01, 1, 1),

  g.panel.row.new('💡 Guidance') + c.pos(0, 23, 24, 1),
  slo_guidancePanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 27, 24, 1),
  slo_troubleGuide,
];
// sloHeight: troubleGuide at y=28, h=5 → max(y+h) = 33
local sloHeight = 33;

// ── Cross-Signal Correlation (prefix corr_) ─────────────────────────────────

local corr_overlayTs =
  g.panel.timeSeries.new('Cross-Signal Correlation')
  + c.pos(0, 1, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(100 - avg(rate(host_cpu_seconds_total{mode="idle",host="homelab"}[5m])) * 100)', 'CPU %'),
    c.vmQ('avg(claude_duration_api_seconds) / clamp_min(avg(claude_prompt_count), 1) * 10', 'Claude API Wait (x10s)'),
    c.vmQ('sum(rate(service_error_with_type{job="temporal"}[5m])) * 1000', 'Temporal Errors (x1000)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local corrPanels = [
  g.panel.row.new('🔗 Correlation') + c.pos(0, 0, 24, 1),
  corr_overlayTs,
];
local corrHeight = 9;

// ── Nginx Traffic Intelligence (prefix nx_) ──────────────────────────────

local nx_errorRateTs =
  g.panel.timeSeries.new('HTTP Errors by Status Code')
  + c.pos(0, 1, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vlogsStatsQ('{service="nginx"} AND status:>=400 | stats by (status) count() as errors'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local nx_topErrorUrisTs =
  g.panel.timeSeries.new('Top Error URIs')
  + c.pos(12, 1, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vlogsStatsQ('{service="nginx"} AND status:>=400 | stats by (uri) count() as errors | sort by (errors) desc | limit 10'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local nxPanels = [
  g.panel.row.new('🌐 Traffic Intelligence') + c.pos(0, 0, 24, 1),
  nx_errorRateTs, nx_topErrorUrisTs,
];
local nxHeight = 9;

// ── Probe Latency (prefix prb_) ──────────────────────────────────────────

local prb_latencyTs =
  g.panel.timeSeries.new('Service Probe Latency')
  + c.pos(0, 1, 16, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('probe_duration_seconds{job="blackbox-http"} or vector(0)', '{{instance}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.standardOptions.withDecimals(3)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local prb_successStat =
  g.panel.stat.new('Services Up')
  + c.pos(16, 1, 8, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(probe_success{job="blackbox-http"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 5 },
    { color: 'green', value: 7 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local prb_slowestStat =
  g.panel.stat.new('Slowest Probe')
  + c.pos(16, 5, 8, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(probe_duration_seconds{job="blackbox-http"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.standardOptions.withDecimals(3)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 3 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local probePanels = [
  g.panel.row.new('📡 Probe Latency') + c.pos(0, 0, 24, 1),
  prb_latencyTs, prb_successStat, prb_slowestStat,
];
local probeHeight = 9;

// ── Deploy Impact (prefix dpl_) ──────────────────────────────────────────

local dpl_impactTs =
  g.panel.timeSeries.new('Deploy Impact — Error Rate Around Deploys')
  + c.pos(0, 1, 16, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(service_error_with_type{job="temporal"}[5m])) or vector(0)', 'Temporal Errors/s'),
    c.vmQ('sum(rate(service_requests{operation="StartWorkflowExecution",service_name="frontend",job="temporal"}[5m])) or vector(0)', 'Deploy Starts/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local dpl_impactStat =
  g.panel.stat.new('Deploy Impact Score')
  + c.pos(16, 1, 8, 8)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(rate(service_error_with_type{job="temporal"}[5m])) / clamp_min(sum(rate(service_error_with_type{job="temporal"}[30m])), 0.0001) - 1) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 20 },
    { color: 'red', value: 100 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local deployPanels = [
  g.panel.row.new('🚀 Deploy Impact') + c.pos(0, 0, 24, 1),
  dpl_impactTs, dpl_impactStat,
];
local deployHeight = 9;

// ── Dashboard heights for stacking ───────────────────────────────────────────

local whatDownHeight = 36;

// ── Dashboard assembly ────────────────────────────────────────────────────────

g.dashboard.new("What's Failing")
+ g.dashboard.withUid('home-whats-failing')
+ g.dashboard.withDescription('Entry point: what is down right now? Services, alerts, activity.')
+ g.dashboard.withTags(['home', 'overview', 'status'])
+ g.dashboard.withRefresh('10s')
+ g.dashboard.time.withFrom('now-15m')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.vmAdhocVar, c.vlogsAdhocVar])
+ g.dashboard.withPanels(
    [
      g.panel.row.new('🔴 Status') + c.pos(0, 0, 24, 1),
      downCountStat, alertCountStat,
    ]
    + servicesGrid
    + [
      g.panel.row.new('🚨 Alerts') + c.pos(0, 11, 24, 1),
      alertsTable,
      g.panel.row.new('📝 Logs') + c.pos(0, 20, 24, 1),
      errorByServiceTable,
      logsPanel,
      // Activity row
      g.panel.row.new('⚡ Activity') + c.pos(0, activityRowY, 24, 1),
      gpuActivityStat, claudeActivityStat, hunterActivityStat, scalableActivityStat,
    ]
    + c.withYOffset(corrPanels, whatDownHeight + activityHeight)
    + c.withYOffset(nxPanels, whatDownHeight + activityHeight + corrHeight)
    + c.withYOffset(probePanels, whatDownHeight + activityHeight + corrHeight + nxHeight)
    + c.withYOffset(deployPanels, whatDownHeight + activityHeight + corrHeight + nxHeight + probeHeight)
    + c.withYOffset(sloPanels, whatDownHeight + activityHeight + corrHeight + nxHeight + probeHeight + deployHeight)
  )
