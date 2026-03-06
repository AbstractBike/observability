// Services Health Super-Dashboard
//
// Consolidated view of all service health: status, errors, latency.
// Provides instant visibility into infrastructure health without navigating
// to individual service dashboards.

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Health Summary Stats ───────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('observability', col=0);

local healthyServicesStat =
  g.panel.stat.new('✅ Healthy Services')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~"(postgres|redis|temporal|grafana|alertmanager|victoriametrics|victorialogs|vector|skywalking-oap)"} == 1) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 5 },
    { color: 'green', value: 10 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local downServicesStat =
  g.panel.stat.new('❌ Down Services')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~"(postgres|redis|temporal|grafana|alertmanager|victoriametrics|victorialogs|vector|skywalking-oap)"} == 0) or vector(0)'),
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

local errorRateStat =
  g.panel.stat.new('⚠️ Avg Error Rate')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('avg(rate(http_requests_total{status=~"5.."}[5m]) or vector(0)) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local avgLatencyStat =
  g.panel.stat.new('⏱️ Avg Latency')
  + c.statPos(4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.95, sum by(le) (rate(http_request_duration_seconds_bucket[5m])))) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Service Status Grid ────────────────────────────────────────────────────

local serviceStat(title, jobName, col) =
  g.panel.stat.new(title)
  + c.pos(col * 6, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('up{job="' + jobName + '"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name')
  + g.panel.stat.options.withGraphMode('none');

local services = [
  serviceStat('PostgreSQL', 'postgres-exporter', 0),
  serviceStat('Redis', 'redis-exporter', 1),
  serviceStat('Temporal', 'temporal', 2),
  serviceStat('Grafana', 'grafana', 3),
  serviceStat('Alertmanager', 'alertmanager', 4),
  serviceStat('VictoriaMetrics', 'victoriametrics-self', 5),
  serviceStat('VictoriaLogs', 'victorialogs', 6),
  serviceStat('Vector', 'vector', 7),
];

// ── Error Rate Trends ─────────────────────────────────────────────────────

local errorRateTs =
  g.panel.timeSeries.new('Error Rate by Service (5m avg)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(rate(http_requests_total{status=~"5.."}[5m]) or vector(0)) * 100',
      '{{job}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Latency Trends ────────────────────────────────────────────────────────

local latencyTs =
  g.panel.timeSeries.new('Request Latency p95 (5m avg)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(histogram_quantile(0.95, sum by(le, job) (rate(http_request_duration_seconds_bucket[5m]))) or vector(0)) * 1000',
      '{{job}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Service Info ──────────────────────────────────────────────────────────

local infoPanel =
  g.panel.text.new('🔗 Quick Navigation & Related Dashboards')
  + c.pos(0, 19, 24, 3)
  + g.panel.text.options.withContent(|||
    ### 📊 Key Dashboards (Related to Service Health)

    **SLO & Compliance**: [SLO Overview](/d/slo-overview) — Monthly error budget tracking
    **Performance**: [Performance & Optimization](/d/performance-optimization) — Query latency, storage, cardinality
    **Alerts**: [Observability — Alerts](/d/alerts-dashboard) — Active alerts, firing rate
    **Metrics Catalog**: [Metrics Discovery](/d/metrics-discovery) — Available metrics, cardinality analysis
    **Logs**: [Observability — Logs](/d/observability-logs) — All-services log exploration

    ### 🖥️ Service Dashboards

    **Overview**: [Homelab](/d/homelab-overview) | [Heater System](/d/heater-system)

    **Databases**: [PostgreSQL](/d/services-postgresql) | [Redis](/d/services-redis) | [ClickHouse](/d/services-clickhouse) | [Elasticsearch](/d/services-elasticsearch)

    **Observability**: [Grafana](/d/observability-grafana) | [SkyWalking](/d/observability-skywalking) | [Alertmanager](/d/observability-alertmanager)

    **Pipeline & APM**: [Vector](/d/pipeline-vector) | [Temporal](/d/services-temporal) | [Matrix APM](/d/matrix-apm-skywalking)
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('observability', [
  { symptom: 'Service Down', runbook: 'services/outage-response', check: 'Check "Down Services" stat and service grid for specific issue' },
  { symptom: 'Error Rate Spike', runbook: 'services/error-spike', check: 'Review "Avg Error Rate" and correlate with service logs' },
  { symptom: 'Latency Degradation', runbook: 'services/latency-issue', check: 'Monitor "Avg Latency" trend and check database performance' },
  { symptom: 'Multi-Service Failures', runbook: 'services/cascade-failure', check: 'Check infrastructure health and resource contention' },
], y=20);

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Error Logs (all services)', 'homelab', y=28, host='homelab');

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Overview — Services Health')
+ g.dashboard.withUid('services-health')
+ g.dashboard.withDescription('Infrastructure health summary: service status, error rates, latency trends, quick navigation.')
+ g.dashboard.withTags(['overview', 'health', 'services', 'sla', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Health Summary') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, healthyServicesStat, downServicesStat, errorRateStat, avgLatencyStat,

  g.panel.row.new('⚡ Service Status') + c.pos(0, 4, 24, 1),
]
+ services
+ [
  g.panel.row.new('📈 Trends') + c.pos(0, 9, 24, 1),
  errorRateTs, latencyTs,

  g.panel.row.new('🔗 Navigation & Info') + c.pos(0, 18, 24, 1),
  infoPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 19, 24, 1),
  troubleGuide,

  g.panel.row.new('📝 Logs') + c.pos(0, 27, 24, 1),
  logsPanel,
])
