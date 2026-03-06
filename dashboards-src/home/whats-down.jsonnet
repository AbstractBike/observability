// Dashboard: What's Down?
// Question:  "What services are down RIGHT NOW?"
//
// Incident-focused view. Designed for fast diagnosis:
//   1. Big counters at the top (how bad is it?)
//   2. Service status grid (what is down?)
//   3. Firing alerts table (what triggered?)
//   4. Recent error logs (what is it saying?)
//
// Linked from: home dashboard, services-health dashboard
// Links to: individual service dashboards

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local ALL_JOBS = 'alertmanager|clickhouse|elasticsearch-exporter|grafana|postgres-exporter|redis-exporter|redpanda|skywalking-oap|temporal|victoriametrics-self|victorialogs|vmalert';

// ── Top Stats (y=1) ──────────────────────────────────────────────────────────

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

// ── Service Status Grid (y=5) ────────────────────────────────────────────────
// Same 12-service grid as services-health. Red = investigate.

local servicesList = [
  { job: 'postgres-exporter',      name: 'PostgreSQL',      uid: 'services-postgresql' },
  { job: 'redis-exporter',         name: 'Redis',           uid: 'services-redis' },
  { job: 'temporal',               name: 'Temporal',        uid: 'services-temporal' },
  { job: 'grafana',                name: 'Grafana',         uid: 'observability-grafana' },
  { job: 'alertmanager',           name: 'Alertmanager',    uid: 'observability-alertmanager' },
  { job: 'victoriametrics-self',   name: 'VictoriaMetrics', uid: 'vm-overview' },
  { job: 'victorialogs',           name: 'VictoriaLogs',    uid: 'observability-logs' },
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

local servicesGrid = std.mapWithIndex(function(idx, svc) svcStat(svc, idx), servicesList);

// ── Availability Timeline (y=12) ─────────────────────────────────────────────
// Last 15 minutes — highlights exactly when something went down.

local availabilityTs =
  g.panel.timeSeries.new('Availability Timeline — Last 15 Minutes')
  + c.pos(0, 12, 24, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('up{job=~"' + ALL_JOBS + '"}', '{{job}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.standardOptions.withMin(0)
  + g.panel.timeSeries.standardOptions.withMax(1.1)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + g.panel.timeSeries.options.tooltip.withMode('multi')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ]);

// ── Firing Alerts Table (y=19) ───────────────────────────────────────────────

local alertsTable =
  g.panel.table.new('🚨 Firing Alerts')
  + c.pos(0, 19, 24, 6)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('ALERTS{alertstate="firing"}', ''),
  ])
  + g.panel.table.options.withSortBy([{ displayName: 'alertname', desc: false }]);

// ── Error Logs (y=26) ────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Recent Error Logs (homelab)', 'homelab', y=26, host='homelab');

// ── Back Link (y=37) ─────────────────────────────────────────────────────────

local backPanel =
  g.panel.text.new('🔗 Navigation')
  + c.pos(0, 37, 24, 2)
  + g.panel.text.options.withContent(|||
    ← [Back to Home](/d/pin-si-home) · [Services Health](/d/services-health) · [Alerts](/alerting/list)
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Dashboard ────────────────────────────────────────────────────────────────

g.dashboard.new("What's Down?")
+ g.dashboard.withUid('home-whats-down')
+ g.dashboard.withDescription("Incident view: which services are down right now, which alerts are firing, and what the logs say. Default time range: last 15 minutes.")
+ g.dashboard.withTags(['home', 'incident', 'critical'])
+ g.dashboard.withRefresh('10s')
+ g.dashboard.time.withFrom('now-15m')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels(
  [
    g.panel.row.new('🔴 Status') + c.pos(0, 0, 24, 1),
    downCountStat, alertCountStat, healthyCountStat, totalServicesStat,
    g.panel.row.new('⚡ Service Grid') + c.pos(0, 4, 24, 1),
  ]
  + servicesGrid
  + [
    g.panel.row.new('📈 Timeline') + c.pos(0, 11, 24, 1),
    availabilityTs,
    g.panel.row.new('🚨 Alerts') + c.pos(0, 18, 24, 1),
    alertsTable,
    g.panel.row.new('📝 Logs') + c.pos(0, 25, 24, 1),
    logsPanel,
    backPanel,
  ]
)
