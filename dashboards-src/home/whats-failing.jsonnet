// Dashboard: What's Failing?
// Entry point: expanded coverage combining status, activity, SLO, and overview sections.
//
// Sections (top → bottom):
//   0-32  What's Down content (extended job list)
//   33-37 Activity — informational stat panels (GPU, Claude, Hunter, Scalable)
//   38+   SLO Overview, Homelab Overview (via withYOffset)

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Extended job list (adds node-exporter and vector to the original 12)
local ALL_JOBS = 'alertmanager|clickhouse|elasticsearch-exporter|grafana|node-exporter|postgres-exporter|redis-exporter|redpanda|skywalking-oap|temporal|vector|victoriametrics-self|victorialogs-general|vmalert';

// ── Top Stats (y=3) ──────────────────────────────────────────────────────────

local downCountStat =
  g.panel.stat.new('❌ Services Down')
  + c.statPos(0)
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
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(ALERTS{alertstate="firing"}) or vector(0)'),
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

local healthyCountStat =
  g.panel.stat.new('✅ Services Up')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~"' + ALL_JOBS + '"} == 1) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 8 },
    { color: 'green', value: 12 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local totalServicesStat =
  g.panel.stat.new('📊 Services Monitored')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~"' + ALL_JOBS + '"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'blue', value: null },
  ])
  + g.panel.stat.options.withColorMode('value')
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
  + g.panel.stat.options.withTextMode('none')
  + g.panel.stat.options.withGraphMode('none')
  + { links: [{ title: svc.name + ' Dashboard', url: '/d/' + svc.uid, targetBlank: false }] };

local servicesGrid = std.mapWithIndex(function(idx, svc) svcStat(svc, idx), servicesList);

// ── Firing Alerts Table (y=12) ───────────────────────────────────────────────

local alertsTable =
  g.panel.table.new('🚨 Firing Alerts')
  + c.pos(0, 12, 24, 6)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('ALERTS{alertstate="firing"}', ''),
  ])
  + g.panel.table.options.withSortBy([{ displayName: 'alertname', desc: false }]);

// ── Error Logs (y=21) ────────────────────────────────────────────────────────

local logsPanel =
  g.panel.logs.new('Recent Error Logs (homelab — all services)')
  + c.logPos(21)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",level=~"(error|warn|critical)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Activity panels (y=33..37) ───────────────────────────────────────────────

local activityRowY = 33;

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
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

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

// ── Homelab Overview panels (prefix ohl_) ─────────────────────────────────────
// Copied from overview/homelab.jsonnet — panels at their original y coords (0-relative)

local ohl_alertPanel = c.alertCountPanel('homelab', col=0);

local ohl_cpuStat =
  g.panel.stat.new('CPU')
  + c.pos(0, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(100 - avg(rate(host_cpu_seconds_total{mode="idle",host="homelab"}[5m])) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local ohl_ramStat =
  g.panel.stat.new('RAM')
  + c.pos(6, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(host_memory_used_bytes{host="homelab"} / host_memory_total_bytes{host="homelab"} * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local ohl_diskStat =
  g.panel.stat.new('Disk /')
  + c.pos(12, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(host_filesystem_used_ratio{host="homelab",mountpoint="/"} * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local ohl_uptimeStat =
  g.panel.stat.new('Host Uptime')
  + c.pos(18, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('host_uptime{host="homelab"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local ohl_svcStat(title, upExpr, col, row) =
  g.panel.stat.new(title)
  + c.pos(col * 6, 5 + row * 3, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(' + upExpr + ') or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.options.withTextMode('name');

local ohl_services = [
  ohl_svcStat('PostgreSQL',      'up{job="postgres-exporter"}',                                                           0, 0),
  ohl_svcStat('Redis',           'up{job="redis-exporter"}',                                                              1, 0),
  ohl_svcStat('Elasticsearch',   'up{job="elasticsearch-exporter"}',                                                      2, 0),
  ohl_svcStat('ClickHouse',      'up{job="clickhouse"}',                                                                  3, 0),
  ohl_svcStat('Redpanda',        'up{job="redpanda"}',                                                                    0, 1),
  ohl_svcStat('Temporal',        'up{job="temporal"}',                                                                    1, 1),
  ohl_svcStat('VictoriaMetrics', 'up{job="victoriametrics-self"}',                                                        2, 1),
  ohl_svcStat('VictoriaLogs',    'up{job="victorialogs-general"}',                                                        3, 1),
  ohl_svcStat('Grafana',         'up{job="grafana"}',                                                                     0, 2),
  ohl_svcStat('Alertmanager',    'up{job="alertmanager"}',                                                                1, 2),
  ohl_svcStat('VMAlert',         'up{job="vmalert"}',                                                                     2, 2),
  ohl_svcStat('Vector',          'clamp_max(clamp_min(min_over_time(vector_uptime_seconds{host="homelab"}[2m]),0),1)',     3, 2),
  ohl_svcStat('SkyWalking OAP',  'up{job="skywalking-oap"}',                                                              0, 3),
];

local ohl_systemLogsPanel =
  g.panel.logs.new('System Logs')
  + c.logPos(23)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",level=~"(warn|error|critical)"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

local ohl_sloStat(title, expr, targetPct, col) =
  g.panel.stat.new(title)
  + c.pos(col * 6, 19, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(' + expr + ') or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: targetPct - 0.5 },
    { color: 'green', value: targetPct },
  ])
  + g.panel.stat.options.withColorMode('background');

local ohl_troubleGuide = c.serviceTroubleshootingGuide('homelab', [
  { symptom: 'Host CPU High', runbook: 'host/cpu-spike', check: 'Monitor CPU stat and check top processes in "Services" grid' },
  { symptom: 'Memory Pressure', runbook: 'host/memory-pressure', check: 'Review RAM usage and service memory consumption' },
  { symptom: 'Disk Space Low', runbook: 'host/disk-cleanup', check: 'Check Disk / percentage and identify large files' },
  { symptom: 'Service Outage', runbook: 'host/service-recovery', check: 'Review "Services" grid and SLO compliance stats' },
], y=36);

local overviewHomelabPanels =
  [
    g.panel.row.new('🏠 Homelab — Host') + c.pos(0, 0, 24, 1),
    g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

    c.externalLinksPanel(y=3, x=18),
    ohl_alertPanel,
    ohl_cpuStat,
    ohl_ramStat,
    ohl_diskStat,
    ohl_uptimeStat,

    g.panel.row.new('⚡ Services') + c.pos(0, 6, 24, 1),
  ]
  + ohl_services
  + [
    g.panel.row.new('💯 SLO Compliance') + c.pos(0, 20, 24, 1),
    ohl_sloStat('SLO: Host Uptime',  '(1 - slo:host_uptime:error_ratio_30d) * 100',  99.5, 0),
    ohl_sloStat('SLO: PostgreSQL',   '(1 - slo:postgresql:error_ratio_30d) * 100',   99.9, 1),
    ohl_sloStat('SLO: Redis',        '(1 - slo:redis:error_ratio_30d) * 100',        99.9, 2),
    ohl_sloStat('SLO: Grafana',      '(1 - slo:grafana:error_ratio_30d) * 100',      99.0, 3),
    g.panel.row.new('📝 Logs') + c.pos(0, 24, 24, 1),
    ohl_systemLogsPanel,
    g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 35, 24, 1),
    ohl_troubleGuide,
  ];
// overviewHomelabHeight: troubleGuide at y=36, h=5 → max(y+h) = 41

// ── Dashboard heights for stacking ───────────────────────────────────────────

local whatDownHeight = 32;

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
      g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
      downCountStat, alertCountStat, healthyCountStat, totalServicesStat,
    ]
    + servicesGrid
    + [
      g.panel.row.new('🚨 Alerts') + c.pos(0, 11, 24, 1),
      alertsTable,
      g.panel.row.new('📝 Logs') + c.pos(0, 20, 24, 1),
      logsPanel,
      // Activity row
      g.panel.row.new('⚡ Activity') + c.pos(0, activityRowY, 24, 1),
      gpuActivityStat, claudeActivityStat, hunterActivityStat, scalableActivityStat,
    ]
    + c.withYOffset(sloPanels, whatDownHeight + activityHeight)
    + c.withYOffset(overviewHomelabPanels, whatDownHeight + activityHeight + sloHeight)
  )
