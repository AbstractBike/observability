local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Grafana self-monitoring dashboard.
// Grafana exposes its own /metrics on port 3001 (scraped by VictoriaMetrics via job="grafana").
// Key metric families: grafana_http_*, grafana_alerting_*, grafana_stat_*,
//   grafana_database_conn_*, grafana_datasource_request_*, grafana_api_*.

// ── Stats ───────────────────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('grafana', col=0);

// 5-stat layout: alert(6) + httpRate(4) + activeAlerts(4) + dashboards(5) + dbConn(5) = 24
local httpRateStat =
  g.panel.stat.new('HTTP Requests/s')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(grafana_http_request_duration_seconds_count{job="grafana"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local activeAlertsStat =
  g.panel.stat.new('Active Alerts')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(grafana_alerting_active_alerts{job="grafana"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local dashboardsStat =
  g.panel.stat.new('Dashboards')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('grafana_stat_totals_dashboard{job="grafana"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local dbConnStat =
  g.panel.stat.new('DB Connections (in use)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('grafana_database_conn_in_use{job="grafana"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

// ── Time series ─────────────────────────────────────────────────────────────

local httpRateTs =
  g.panel.timeSeries.new('HTTP Request Rate by Handler')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (sum by (handler) (rate(grafana_http_request_duration_seconds_count{job="grafana"}[5m])) or vector(0)))',
      '{{handler}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local httpLatTs =
  g.panel.timeSeries.new('HTTP Latency p99 (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(histogram_quantile(0.99, sum by (le, handler) (rate(grafana_http_request_duration_seconds_bucket{job="grafana"}[5m])) or vector(0))) * 1000',
      '{{handler}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local dsRateTs =
  g.panel.timeSeries.new('Datasource Requests/s by Datasource')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(sum by (datasource) (rate(grafana_datasource_request_total{job="grafana"}[5m])) or vector(0))',
      '{{datasource}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local dsLatTs =
  g.panel.timeSeries.new('Datasource Request Latency p99 (ms)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(histogram_quantile(0.99, sum by (le, datasource) (rate(grafana_datasource_request_duration_seconds_bucket{job="grafana"}[5m])) or vector(0))) * 1000',
      '{{datasource}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Logs ─────────────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Grafana Logs', 'grafana-start', y=22);

local troubleGuide = c.serviceTroubleshootingGuide('grafana', [
  { symptom: 'High HTTP Latency', runbook: 'grafana/latency', check: 'Check "HTTP Latency p99" and handler breakdown' },
  { symptom: 'Datasource Errors', runbook: 'grafana/datasource', check: 'Monitor "Datasource Request Latency" and logs' },
  { symptom: 'High Memory Usage', runbook: 'grafana/memory', check: 'Check "DB Connections" and dashboard count' },
  { symptom: 'Alert System Issues', runbook: 'grafana/alerting', check: 'Verify "Active Alerts" in Grafana UI' },
], y=33);

// ── Dashboard ────────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Grafana')
+ g.dashboard.withUid('observability-grafana')
+ g.dashboard.withDescription('Grafana self-monitoring: HTTP request rate, latency, alerting, datasource performance.')
+ g.dashboard.withTags(['observability', 'grafana', 'critical', 'infrastructure'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, httpRateStat, activeAlertsStat, dashboardsStat, dbConnStat,
  g.panel.row.new('⚡ HTTP Traffic') + c.pos(0, 4, 24, 1),
  httpRateTs, httpLatTs,
  g.panel.row.new('🔧 Datasources') + c.pos(0, 12, 24, 1),
  dsRateTs, dsLatTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 21, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 32, 24, 1),
  troubleGuide,
])
