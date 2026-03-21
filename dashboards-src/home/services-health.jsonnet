// Dashboard: Overview — Services Health
// Question:  "How is each service doing?"
//
// Shows live up/down status of all 12 monitored services, availability
// trends, and error logs. Entry point for service-level investigation.
//
// Data links: each service panel → individual service dashboard.
//
// Bugs fixed vs previous version:
//   - http_requests_total generic metric does not exist; replaced with
//     real available metrics (vm_http_requests_total, ALERTS)
//   - Added missing services: clickhouse, elasticsearch-exporter,
//     redpanda, skywalking-oap, vmalert
//   - alertCountPanel now queries ALL firing alerts (was wrong service label)
//   - Service grid positions recalculated: 6 per row, 4 wide each

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// All monitored job names (up{} metric)
local ALL_JOBS = 'alertmanager|clickhouse|elasticsearch-exporter|grafana|postgres-exporter|redis-exporter|redpanda|skywalking-oap|temporal|victoriametrics-self|victorialogs|vmalert';

// ── Summary Stats (y=3, statPos = 6 wide × 3 tall) ──────────────────────────

// Fix: count ALL firing alerts, not just service="observability" (that label does not exist)
local alertStat =
  g.panel.stat.new('🚨 Active Alerts')
  + c.statPos(0)
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

// Fix: include all 12 services in the count
local healthyStat =
  g.panel.stat.new('✅ Healthy Services')
  + c.statPos(1)
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
  + g.panel.stat.options.withGraphMode('area');

local downStat =
  g.panel.stat.new('❌ Down Services')
  + c.statPos(2)
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
  + g.panel.stat.options.withGraphMode('area');

// Fix: http_requests_total does not exist generically.
// Use vm_http_requests_total (VictoriaMetrics own HTTP) as a proxy signal.
local vmReqRateStat =
  g.panel.stat.new('📈 VM Request Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(vm_http_requests_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'blue', value: null },
  ])
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Service Status Grid (y=7) ────────────────────────────────────────────────
// 12 services × 4 wide = 6 per row × 2 rows. Grid ends at y=13.

local servicesList = [
  { job: 'postgres-exporter',    name: 'PostgreSQL',      uid: 'services-postgresql' },
  { job: 'redis-exporter',       name: 'Redis',           uid: 'services-redis' },
  { job: 'temporal',             name: 'Temporal',        uid: 'services-temporal' },
  { job: 'grafana',              name: 'Grafana',         uid: 'observability-grafana' },
  { job: 'alertmanager',         name: 'Alertmanager',    uid: 'observability-alertmanager' },
  { job: 'victoriametrics-self', name: 'VictoriaMetrics', uid: 'vm-overview' },
  { job: 'victorialogs',         name: 'VictoriaLogs',    uid: 'observability-logs' },
  { job: 'clickhouse',           name: 'ClickHouse',      uid: 'services-clickhouse' },
  { job: 'elasticsearch-exporter', name: 'Elasticsearch', uid: 'services-elasticsearch' },
  { job: 'redpanda',             name: 'Redpanda',        uid: 'services-redpanda' },
  { job: 'skywalking-oap',       name: 'SkyWalking OAP', uid: 'observability-skywalking' },
  { job: 'vmalert',              name: 'vmalert',         uid: 'observability-vmalert' },
];

local serviceStat(svc, idx) =
  local col = idx % 6;
  local row = std.floor(idx / 6);
  g.panel.stat.new(svc.name)
  + c.pos(col * 4, 5 + row * 3, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('up{job="' + svc.job + '"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name')
  + g.panel.stat.options.withGraphMode('none')
  + { links: [{ title: svc.name + ' Dashboard', url: '/d/' + svc.uid, targetBlank: false }] };

local servicesGrid = std.mapWithIndex(function(idx, svc) serviceStat(svc, idx), servicesList);

// ── Availability Trends (y=14) ───────────────────────────────────────────────
// Fix: replace broken http_requests_total time series with real up{} trends.

local availabilityTs =
  g.panel.timeSeries.new('Service Availability Over Time')
  + c.pos(0, 12, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('up{job=~"' + ALL_JOBS + '"}', '{{job}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.standardOptions.withMin(0)
  + g.panel.timeSeries.standardOptions.withMax(1.1)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ]);

// ── Error Logs (y=23) ────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Error Logs (homelab — all services)', 'homelab', y=23, host='homelab');

// ── Quick Navigation (y=34) ─────────────────────────────────────────────────

local navPanel =
  g.panel.text.new('🔗 Service Dashboards')
  + c.pos(0, 32, 24, 3)
  + g.panel.text.options.withContent(|||
    **Databases**: [PostgreSQL](/d/services-postgresql) · [Redis](/d/services-redis) · [ClickHouse](/d/services-clickhouse) · [Elasticsearch](/d/services-elasticsearch)

    **Messaging & Workflows**: [Redpanda](/d/services-redpanda) · [Temporal](/d/services-temporal)

    **Observability Stack**: [Grafana](/d/observability-grafana) · [SkyWalking](/d/observability-skywalking) · [Alertmanager](/d/observability-alertmanager) · [vmalert](/d/observability-vmalert) · [VictoriaMetrics](/d/vm-overview) · [Logs](/d/observability-logs)

    **Diagnostics**: [What's Down?](/d/home-whats-down) · [SLO Overview](/d/slo-overview) · [Homelab System](/d/services-homelab-system)
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Overview — Services Health')
+ g.dashboard.withUid('services-health')
+ g.dashboard.withDescription('All 12 services up/down status with availability trends. Entry point: see a red tile → click it → individual service dashboard.')
+ g.dashboard.withTags(['home', 'health', 'services', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels(
  [
    g.panel.row.new('📊 Summary') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

    alertStat, healthyStat, downStat, vmReqRateStat,

    g.panel.row.new('⚡ Service Status') + c.pos(0, 6, 24, 1),
  ]
  + servicesGrid
  + [
    g.panel.row.new('📈 Availability Trends') + c.pos(0, 13, 24, 1),
    availabilityTs,

    g.panel.row.new('📝 Error Logs') + c.pos(0, 22, 24, 1),
    logsPanel,

    g.panel.row.new('🔗 Navigation') + c.pos(0, 33, 24, 1),
    navPanel,
  ]
)
