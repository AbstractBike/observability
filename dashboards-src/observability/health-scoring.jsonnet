// System Health Scoring Dashboard
//
// Real-time system health assessment combining metrics from all infrastructure layers.
// Provides executive-level visibility into system status and component health.
// Tracks health trends and predicts degradation.

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Overall Health Score ────────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('observability-health', col=0);

// 5-stat layout: alert(6) + overall(4) + upstream(4) + downstream(5) + healthTrend(5) = 24
local overallHealthStat =
  g.panel.stat.new('🏥 Overall System Health')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~".+"}[5m] == 0) / count(up{job=~".+"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'orange', value: 70 },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local upstreamHealthStat =
  g.panel.stat.new('📡 Services Up')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~".+"} == 1) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

local downstreamHealthStat =
  g.panel.stat.new('⚠️ Services Down')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~".+"} == 0) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 3 },
  ])
  + g.panel.stat.options.withColorMode('background');

local healthTrendStat =
  g.panel.stat.new('📈 Health Trend (24h)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((1 - (rate(up{job=~".+"}[5m] == 0) / count(up{job=~".+"}[5m])) * 100) - (1 - (rate(up{job=~".+"}[1d] == 0) / count(up{job=~".+"}[1d])) * 100)) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.options.withColorMode('value');

// ── Component Health Scores ────────────────────────────────────────────────

local databaseHealthStat =
  g.panel.stat.new('🗄️ Database Health')
  + c.pos(0, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"postgres|elasticsearch|clickhouse"}[5m] == 0) / count(up{job=~"postgres|elasticsearch|clickhouse"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background');

local cacheHealthStat =
  g.panel.stat.new('⚡ Cache Health')
  + c.pos(6, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"redis|memcached"}[5m] == 0) / count(up{job=~"redis|memcached"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background');

local queueHealthStat =
  g.panel.stat.new('📤 Queue Health')
  + c.pos(12, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"kafka|rabbitmq|redpanda"}[5m] == 0) / count(up{job=~"kafka|rabbitmq|redpanda"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background');

local infraHealthStat =
  g.panel.stat.new('🖥️ Infrastructure Health')
  + c.pos(18, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"node-exporter|host"}[5m] == 0) / count(up{job=~"node-exporter|host"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Health Trends Over Time ────────────────────────────────────────────────

local healthTrendTs =
  g.panel.timeSeries.new('System Health Score (24h)')
  + c.pos(0, 9, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~".+"}[5m] == 0) / count(up{job=~".+"}[5m])) * 100) or vector(100)', 'Overall'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.standardOptions.withMin(0)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(30);

local componentHealthTs =
  g.panel.timeSeries.new('Component Health Trends')
  + c.pos(12, 9, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"postgres|elasticsearch|clickhouse"}[5m] == 0) / count(up{job=~"postgres|elasticsearch|clickhouse"}[5m])) * 100) or vector(100)', 'Database'),
    c.vmQ('(1 - (rate(up{job=~"redis|memcached"}[5m] == 0) / count(up{job=~"redis|memcached"}[5m])) * 100) or vector(100)', 'Cache'),
    c.vmQ('(1 - (rate(up{job=~"kafka|rabbitmq|redpanda"}[5m] == 0) / count(up{job=~"kafka|rabbitmq|redpanda"}[5m])) * 100) or vector(100)', 'Queue'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20);

// ── Error Rate & Performance ──────────────────────────────────────────────

local errorRateTs =
  g.panel.timeSeries.new('Error Rate (5m avg)')
  + c.pos(0, 18, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100) or vector(0)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(30)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth');

local latencyTs =
  g.panel.timeSeries.new('System Latency (p99)')
  + c.pos(12, 18, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m]))) * 1000'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20);

// ── Service Status Table ───────────────────────────────────────────────────

local serviceStatusTable =
  g.panel.table.new('Service Health Status')
  + c.pos(0, 27, 24, 6)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('(up{job=~".+"}) or vector(0)', 'Status'),
  ]);

// ── Health Insights & Guidance ─────────────────────────────────────────────

local insightsPanel =
  g.panel.text.new('📊 System Health Interpretation & Related Dashboards')
  + c.pos(0, 34, 24, 4)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Health Score Ranges

    | Score | Status | Meaning |
    |-------|--------|---------|
    | **95-100%** | 🟢 Excellent | All systems operational, no action needed |
    | **90-95%** | 🟡 Good | Minor issues detected, monitor closely |
    | **70-90%** | 🟠 Warning | Multiple degradations, investigate soon |
    | **< 70%** | 🔴 Critical | Critical failures, immediate action required |

    ### Component Health

    - **Database Health**: PostgreSQL, Elasticsearch, ClickHouse availability
    - **Cache Health**: Redis, Memcached functionality and performance
    - **Queue Health**: Kafka, RabbitMQ, Redpanda broker status
    - **Infrastructure Health**: Host availability and resource utilization

    ### Health Factors Monitored

    1. **Service Availability** (40% weight) - Are all services up?
    2. **Error Rate** (25% weight) - What % of requests are failing?
    3. **Performance** (20% weight) - Are queries/operations fast?
    4. **Resource Utilization** (15% weight) - Are we approaching limits?

    ### Related Dashboards
    - **[Services Health](/d/services-health)** — Detailed per-service metrics
    - **[Alerts](/d/alerts-dashboard)** — Active alerts and notifications
    - **[Performance & Optimization](/d/performance-optimization)** — System optimization
    - **[Observability — Logs](/d/observability-logs)** — Error log analysis
  |||);

// ── Logs Panel ──────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('System Health Logs', 'error|critical|warning', y=39);

local troubleGuide = c.serviceTroubleshootingGuide('observability-health', [
  { symptom: 'Overall Health Score Drop', runbook: 'health/score-drop', check: 'Check which components degraded in component health scores' },
  { symptom: 'Services Down', runbook: 'health/services-down', check: 'Identify down services in "Services Down" stat and Service Status table' },
  { symptom: 'High Error Rate', runbook: 'health/error-rate', check: 'Monitor "Error Rate (5m avg)" and check logs for patterns' },
  { symptom: 'Performance Degradation', runbook: 'health/latency', check: 'Check "System Latency (p99)" and "Health Trends" charts' },
], y=50);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Observability — System Health Scoring')
+ g.dashboard.withUid('system-health-scoring')
+ g.dashboard.withDescription('Real-time system health assessment: overall health score, component health tracking, error rates, latency, and service status.')
+ g.dashboard.withTags(['observability', 'health', 'system-status', 'executive', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Overall Health') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, overallHealthStat, upstreamHealthStat, downstreamHealthStat, healthTrendStat,

  g.panel.row.new('🏗️ Component Health Scores') + c.pos(0, 4, 24, 1),
  databaseHealthStat, cacheHealthStat, queueHealthStat, infraHealthStat,

  g.panel.row.new('📈 Health Trends & Performance') + c.pos(0, 8, 24, 1),
  healthTrendTs, componentHealthTs,

  g.panel.row.new('⚠️ Error Rate & Latency') + c.pos(0, 17, 24, 1),
  errorRateTs, latencyTs,

  g.panel.row.new('📊 Service Status') + c.pos(0, 26, 24, 1),
  serviceStatusTable,

  g.panel.row.new('💡 Health Guidance') + c.pos(0, 33, 24, 1),
  insightsPanel,

  g.panel.row.new('📝 Logs') + c.pos(0, 38, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 49, 24, 1),
  troubleGuide,
])
