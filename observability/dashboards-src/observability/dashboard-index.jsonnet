// Dashboard Index - Central Navigator
//
// Comprehensive guide to all Grafana dashboards in homelab.
// Organized by category with tags and search hints.

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Overview Section ─────────────────────────────────────────────────────────

local overviewText =
  g.panel.text.new('📊 Observability Dashboard Index')
  + c.pos(0, 0, 24, 2)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    # 🗂️ Dashboard Navigator

    Welcome to the homelab observability platform. Use the sections below to find the dashboard you need.
    Each dashboard is tagged with keywords for easy searching (filter by tag at the top).

    **Navigation Tips:**
    - Use the `Tag` filter at the top-left to narrow dashboards by category
    - Click any dashboard title to open it
    - All dashboards auto-refresh every 30 seconds
  |||);

// ── Core Observability ───────────────────────────────────────────────────────

local coreObsText =
  g.panel.text.new('🎯 Core Observability — Start Here')
  + c.pos(0, 2, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [Services Health](/d/services-health) | Real-time service status, uptime, error rates | `core`, `health`, `services` |
    | [Homelab System](/d/homelab-system) | Host-level metrics (CPU, memory, disk, network) | `core`, `system`, `infrastructure` |
    | [Observability — Logs](/d/observability-logs) | All-services structured logs with filtering | `core`, `logs`, `troubleshooting` |
    | [Observability — Alerts](/d/alerts-dashboard) | Active alerts, firing rates, alertmanager status | `core`, `alerts`, `incident-response` |
  |||);

// ── Performance & Optimization ───────────────────────────────────────────────

local perfText =
  g.panel.text.new('⚡ Performance & Optimization')
  + c.pos(0, 3, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [Observability — Performance & Optimization](/d/performance-optimization) | Query latency, storage growth, cardinality, CPU by service | `performance`, `optimization`, `troubleshooting` |
    | [Observability — Metric Discovery](/d/metrics-discovery) | Catalog all metrics, cardinality per job, ingestion rate | `metrics`, `discovery`, `troubleshooting` |
    | [Dashboard Usage](/d/dashboard-usage) | Which dashboards are used most, by whom, when | `analytics`, `meta-observability` |
    | [Cost Tracking](/d/cost-tracking) | Storage costs, data retention, optimization ROI | `cost`, `optimization` |
  |||);

// ── Infrastructure & Services ──────────────────────────────────────────────────

local infraText =
  g.panel.text.new('🏗️ Infrastructure & Databases')
  + c.pos(0, 4, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [PostgreSQL](/d/postgres-db) | Connection count, query latency, replication lag | `database`, `postgresql` |
    | [Redis](/d/redis-db) | Memory usage, hit rate, evictions, command latency | `cache`, `redis` |
    | [Elasticsearch](/d/elasticsearch-db) | Cluster health, indexing rate, query latency | `search`, `elasticsearch` |
    | [ClickHouse](/d/clickhouse-db) | Merges, queries, compression ratio, disk usage | `database`, `clickhouse` |
    | [Redpanda](/d/redpanda-db) | Broker lag, throughput, replication, consumer groups | `streaming`, `kafka` |
  |||);

// ── Observability Stack ─────────────────────────────────────────────────────────

local stackText =
  g.panel.text.new('🔧 Observability Stack Components')
  + c.pos(0, 5, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [Observability — Grafana](/d/observability-grafana) | Grafana itself: memory, CPU, request latency, errors | `meta`, `grafana` |
    | [Observability — VictoriaMetrics](/d/victoriametrics) | Metrics DB: ingestion rate, query latency, storage | `metrics`, `storage` |
    | [Observability — VMAlert](/d/observability-vmalert) | Alert rule evaluation, alert processing latency | `alerts`, `alerting` |
    | [Observability — Alertmanager](/d/observability-alertmanager) | Alert routing, grouping, notification success rate | `alerts`, `routing` |
    | [Observability — SkyWalking](/d/observability-skywalking) | Distributed tracing: OAP uptime, heap, GC, trace latency | `traces`, `apm`, `distributed-tracing` |
  |||);

// ── Application Tracing ───────────────────────────────────────────────────────

local tracingText =
  g.panel.text.new('📡 Application Tracing & APM')
  + c.pos(0, 6, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [SkyWalking Traces](/d/observability-skywalking-traces) | Live traces, topology visualization, span details | `traces`, `apm`, `distributed-tracing` |
    | [PostgreSQL Query Tracing](/d/postgres-query-tracing) | Slow query correlation with traces | `traces`, `database`, `postgresql` |
    | [API Gateway Tracing](/d/api-gateway-tracing) | Request flow through API gateway with spans | `traces`, `api-gateway` |
    | [Matrix/Synapse APM](/d/matrix-apm) | Matrix homeserver performance, federation metrics | `traces`, `matrix`, `messaging` |
  |||);

// ── SLOs & Health ──────────────────────────────────────────────────────────────

local sloText =
  g.panel.text.new('📈 SLOs & Health Scoring')
  + c.pos(0, 7, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [SLO Overview](/d/slo-overview) | Service-level objectives, error budgets, compliance | `slo`, `health` |
    | [Health Scoring](/d/health-scoring) | Overall system health index, risk analysis | `health`, `scoring` |
    | [Service Dependencies](/d/service-dependencies) | Dependency graph, blast radius analysis | `dependencies`, `topology` |
  |||);

// ── Data Pipelines ────────────────────────────────────────────────────────────

local pipelineText =
  g.panel.text.new('🔄 Data Pipelines & Processing')
  + c.pos(0, 8, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [Vector Pipeline](/d/vector-pipeline) | Log/metric collection, routing, transformation | `pipeline`, `vector`, `data-integration` |
    | [Arbitraje Pipeline](/d/arbitraje-pipeline) | Trading arbitrage bot metrics and health | `pipeline`, `arbitrage`, `trading` |
    | [Arbitraje Dev](/d/arbitraje-dev) | Dev environment testing for arbitrage bot | `pipeline`, `arbitrage`, `dev` |
  |||);

// ── Host-Specific ──────────────────────────────────────────────────────────────

local hostText =
  g.panel.text.new('🖥️ Host-Specific Dashboards')
  + c.pos(0, 9, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Host | Purpose | Tags |
    |-----------|------|---------|------|
    | [System](/d/heater-system) | heater | Physical host system metrics | `heater`, `system` |
    | [Processes](/d/heater-processes) | heater | Running process monitoring | `heater`, `processes` |
    | [JVM](/d/heater-jvm) | heater | Java apps on heater | `heater`, `jvm` |
    | [GPU](/d/heater-gpu) | heater | GPU monitoring (if available) | `heater`, `gpu` |
    | [Claude Code](/d/heater-claude-code) | heater | Claude Code agent activity | `heater`, `claude`, `development` |
  |||);

// ── Internal/Meta ──────────────────────────────────────────────────────────────

local metaText =
  g.panel.text.new('🔬 Internal/Meta Observability')
  + c.pos(0, 10, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [Serena MCP Backend](/d/serena-mcp) | Serena language server MCP performance | `meta`, `serena`, `development` |
    | [Serena Backends](/d/serena-backends) | Multi-backend Serena infrastructure | `meta`, `serena`, `development` |
  |||);

// ── Tips & Shortcuts ───────────────────────────────────────────────────────────

local tipsText =
  g.panel.text.new('💡 Tips & Quick Links')
  + c.pos(0, 11, 24, 2)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Quick Access
    - 🔍 **Search dashboards**: Use Ctrl+K → type dashboard name
    - 📌 **Favorite dashboards**: Star any dashboard to pin to top
    - 🏷️ **Filter by tag**: Use the `Tag` filter (top-left) to narrow down
    - 🔗 **External links**: Click the 🔗 icon (top-right corner) for VictoriaMetrics, VictoriaLogs, SkyWalking UIs

    ### For Troubleshooting
    1. **Service not responding?** Start with [Services Health](/d/services-health)
    2. **Slow queries?** Check [Performance & Optimization](/d/performance-optimization)
    3. **Storage growing fast?** Review [Metric Discovery](/d/metrics-discovery)
    4. **Alerts firing?** Look at [Observability — Alerts](/d/alerts-dashboard)
    5. **Request trace needed?** Go to [SkyWalking Traces](/d/observability-skywalking-traces)

    ### Runbooks & On-Call
    - See alert details in [Observability — Alerts](/d/alerts-dashboard) for context
    - Links in alert panels point to runbooks and remediation steps
  |||);

// ── Dashboard ──────────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Dashboard Index')
+ g.dashboard.withUid('dashboard-index')
+ g.dashboard.withDescription('Central navigator for all observability dashboards. Organized by category with quick-access links and search tags.')
+ g.dashboard.withTags(['observability', 'meta', 'navigation', 'index'])
+ g.dashboard.withRefresh('off')  // Static content, no need to refresh
+ g.dashboard.time.withFrom('now-6h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([
  // Tag filter to help users narrow down
  g.dashboard.variable.custom.new('tag', [
    { key: 'All', value: '' },
    { key: 'Core', value: 'core' },
    { key: 'Performance', value: 'performance' },
    { key: 'Infrastructure', value: 'infrastructure' },
    { key: 'Database', value: 'database' },
    { key: 'Traces/APM', value: 'traces' },
    { key: 'Alerts', value: 'alerts' },
    { key: 'Meta', value: 'meta' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Quick Filter')
  + g.dashboard.variable.custom.generalOptions.withCurrent('All', ''),
])
+ g.dashboard.withPanels([
  overviewText,
  coreObsText,
  perfText,
  infraText,
  stackText,
  tracingText,
  sloText,
  pipelineText,
  hostText,
  metaText,
  tipsText,
])
