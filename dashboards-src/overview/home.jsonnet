// Dashboard: Pin SI — Home
//
// Navigation Status Hub — full-viewport launchpad with hierarchical layout.
// Kiosk mode active via nginx CSS injection (modules/nginx.nix [data-page-type="home"]).
//
// Layout (top → bottom, priority order):
//   Header       — branded banner + live clock
//   Status Bar   — services up/down, alerts firing, host CPU
//   Infrastructure — databases (6w) + utilities (4w), green/red health
//   Hunter Pipeline — 3 large cards + 6 nav cards
//   Dashboard Directory — markdown panels with all dashboard links
//   Claude/MCP   — Claude Proxy, Claude Code, MCP Vanguard, SBTCP
//   Grafana Tools — explore, drilldown, dashboards nav
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Constants ────────────────────────────────────────────────────────────────

local ALL_JOBS = 'alertmanager|clickhouse|elasticsearch-exporter|firecrawl|grafana|postgres-exporter|redis-exporter|redpanda|temporal|victoriametrics-self|victorialogs|vmalert';

// ── Card helpers ─────────────────────────────────────────────────────────────

// Base card: PromQL query drives green/red background. Click navigates same tab.
local svcCard(title, subtitle, query, url) =
  g.panel.stat.new('')
  + g.panel.stat.panelOptions.withDescription(subtitle)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('max(' + query + ')')])
  + g.panel.stat.standardOptions.withDisplayName(title)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'red', value: null },
      { color: 'red', value: 0 },
      { color: 'green', value: 1 },
    ])
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name')
  + g.panel.stat.panelOptions.withLinks([{ title: title, url: url, targetBlank: false }]);

// Grafana nav links — no real metric, always green.
local navCard(title, subtitle, url) =
  svcCard(title, subtitle, 'vector(1)', url);

// Dashboard health card — green if job is up, red if down/absent.
local dbCard(title, subtitle, healthJob, url) =
  svcCard(title, subtitle, 'max(up{job="' + healthJob + '"})', url);

// Markdown panel for dashboard directory sections.
local linkPanel(title, content, x, y, w, h) =
  g.panel.text.new(title)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(content)
  + c.pos(x, y, w, h);

// ── Datasource ───────────────────────────────────────────────────────────────

// Restrict to production VictoriaMetrics (avoid HunterMetrics-Dev on port 9430).
local homeDsVar =
  g.dashboard.variable.datasource.new('datasource', 'victoriametrics-metrics-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('Metrics')
  + g.dashboard.variable.datasource.withRegex('^VictoriaMetrics$');

// ── Header (y=0, h=2) ───────────────────────────────────────────────────────

local headerHtml = |||
  <style>
    #pin-header {
      display:flex; align-items:center; justify-content:space-between;
      padding: 14px 24px;
      background: linear-gradient(135deg, #7c3aed 0%, #6d28d9 100%);
      border-radius: 10px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      box-sizing: border-box;
      height: 100%;
      color: #fff;
    }
    #pin-header .brand { display:flex; align-items:center; gap:14px; }
    #pin-header .logo {
      width:36px; height:36px; flex-shrink:0;
      background: rgba(255,255,255,0.2);
      border-radius:8px;
      display:flex; align-items:center; justify-content:center;
      color:#fff; font-size:18px; font-weight:900;
      border: 1px solid rgba(255,255,255,0.25);
    }
    #pin-header .name { font-size:15px; font-weight:700; color:#fff; letter-spacing:-0.02em; }
    #pin-header .tagline {
      font-size:10px; color:rgba(255,255,255,0.7); letter-spacing:0.1em;
      text-transform:uppercase; margin-top:2px;
      font-family: "SFMono-Regular", Consolas, monospace;
    }
    #pin-clock {
      font-family: "SFMono-Regular", Consolas, monospace;
      font-size:12px; color:rgba(255,255,255,0.85);
      font-variant-numeric: tabular-nums;
    }
  </style>
  <div id="pin-header">
    <div class="brand">
      <div class="logo">P</div>
      <div>
        <div class="name">Pin Soluciones Informáticas</div>
        <div class="tagline">observability.hub</div>
      </div>
    </div>
    <div id="pin-clock"></div>
  </div>
  <script>
    (function() {
      function tick() {
        var el = document.getElementById('pin-clock');
        if (el) el.textContent = new Date().toLocaleString('es-ES', {
          weekday:'short', year:'numeric', month:'short', day:'numeric',
          hour:'2-digit', minute:'2-digit', second:'2-digit'
        });
      }
      tick();
      setInterval(tick, 1000);
    })();
  </script>
|||;

local headerPanel =
  g.panel.text.new('')
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(headerHtml)
  + c.pos(0, 0, 24, 2);

// ── Status Bar (y=2, h=2) — 4 stat panels, 6w each ─────────────────────────

local statusUpPanel =
  g.panel.stat.new('Services Up')
  + c.pos(0, 2, 6, 2)
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
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.panelOptions.withLinks([{ title: 'Services Health', url: '/d/services-health', targetBlank: false }]);

local statusDownPanel =
  g.panel.stat.new('Services Down')
  + c.pos(6, 2, 6, 2)
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
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.panelOptions.withLinks([{ title: "What's Down?", url: '/d/home-whats-down', targetBlank: false }]);

local statusAlertsPanel =
  g.panel.stat.new('Alerts Firing')
  + c.pos(12, 2, 6, 2)
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
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.panelOptions.withLinks([{ title: 'Alerting', url: '/alerting/list', targetBlank: false }]);

local statusCpuPanel =
  g.panel.stat.new('Host CPU')
  + c.pos(18, 2, 6, 2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.panelOptions.withLinks([{ title: 'Homelab Overview', url: '/d/homelab-overview', targetBlank: false }]);

// ── Infrastructure — Databases (y=4, h=3) — 4+4 cards, 6w each ─────────────

local infraRow = g.panel.row.new('Infrastructure') + c.pos(0, 4, 24, 1);

local vmCard       = svcCard('VictoriaMetrics', 'Metrics storage',    'up{job="victoriametrics-self"}',   'http://victoria.pin')   + c.pos(0,  5, 6, 3);
local vlogsCard    = svcCard('VictoriaLogs',    'Log storage',        'up{job="victorialogs"}',           'http://logs.pin')       + c.pos(6,  5, 6, 3);
local pgCard       = svcCard('PostgreSQL',      'Relational DB',      'up{job="postgres-exporter"}',      '/d/services-postgresql') + c.pos(12, 5, 6, 3);
local chCard       = svcCard('ClickHouse',      'Columnar analytics', 'up{job="clickhouse"}',             'http://clickhouse.pin') + c.pos(18, 5, 6, 3);

local redisCard    = svcCard('Redis',           'In-memory cache',    'up{job="redis-exporter"}',         '/d/services-redis')      + c.pos(0,  8, 6, 3);
local esCard       = svcCard('Elasticsearch',   'Search & analytics', 'up{job="elasticsearch-exporter"}', '/d/services-elasticsearch') + c.pos(6, 8, 6, 3);
local rpCard       = svcCard('Redpanda',        'Kafka-compat MQ',    'up{job="redpanda"}',               'http://redpanda.pin')   + c.pos(12, 8, 6, 3);
local temporalCard = svcCard('Temporal',        'Workflow engine',    'probe_success{instance="http://temporal.pin"}', 'http://temporal.pin') + c.pos(18, 8, 6, 3);

// ── Infrastructure — Utilities (y=11, h=3) — 6 cards, 4w each ──────────────

local alertmgrCard  = svcCard('Alertmanager', 'Alert routing',    'up{job="alertmanager"}',                        '/alerting')             + c.pos(0,  11, 4, 3);
local firecrawlCard = svcCard('Firecrawl',    'Web scraping',     'up{job="firecrawl"}',                           'http://firecrawl.pin')  + c.pos(4,  11, 4, 3);
local adguardCard   = svcCard('AdGuard',      'DNS filtering',    'probe_success{instance="http://adguard.pin"}',  'http://adguard.pin')    + c.pos(8,  11, 4, 3);
local nexusCard     = svcCard('Nexus',        'Artifact registry','probe_success{instance="http://nexus.pin"}',    'http://nexus.pin')      + c.pos(12, 11, 4, 3);
local matrixCard    = svcCard('Matrix',       'Chat server',      'probe_success{instance="http://matrix.pin"}',   'http://matrix.pin')     + c.pos(16, 11, 4, 3);
local supersetCard  = svcCard('Superset',     'Data analytics',   'probe_success{instance="http://superset.pin"}', 'http://superset.pin')   + c.pos(20, 11, 4, 3);

// ── Hunter Pipeline (y=14, h=9) ─────────────────────────────────────────────

local hunterRow = g.panel.row.new('Hunter Pipeline') + c.pos(0, 14, 24, 1);

// 3 large cards (8w×4h)
local hunterPipelineCard  = dbCard('Hunter Pipeline',     'Main pipeline metrics',  'hunter',              '/d/hunter-pipeline-main')  + c.pos(0,  15, 8, 4);
local hunterSourcesCard   = dbCard('Hunter Sources',      'Source health & volume',  'hunter',              '/d/hunter-sources')        + c.pos(8,  15, 8, 4);
local hunterNamespaceCard = dbCard('Namespace Health',    'Namespace consolidation', 'hunter',              '/d/hunter-namespace-health') + c.pos(16, 15, 8, 4);

// 6 nav cards (4w×2h)
local cotCard       = navCard('CoT Ranking',       'Chain-of-thought quality',    '/d/hunter-cot-ranking')      + c.pos(0,  19, 4, 2);
local prefetchCard  = navCard('Prefetch',          'Prefetch pipeline',           '/d/services-job-hunter')     + c.pos(4,  19, 4, 2);
local arbitrajeCard = navCard('Arbitraje',         'Trading arbitrage',           '/d/arbitraje-main')          + c.pos(8,  19, 4, 2);
local scalableCard  = navCard('Scalable Market',   'Market data pipeline',        '/d/scalable-market-main')    + c.pos(12, 19, 4, 2);
local pathrankerCard= navCard('PathRanker',        'Path ranking engine',         '/d/pathranker-main')         + c.pos(16, 19, 4, 2);
local routeCard     = navCard('Route Comparison',  'Route comparison analysis',   '/d/hunter-route-comparison') + c.pos(20, 19, 4, 2);

// ── Dashboard Directory (y=21, h=6) — 2 markdown panels ────────────────────

local directoryRow = g.panel.row.new('Dashboard Directory') + c.pos(0, 21, 24, 1);

local directoryLeft = linkPanel(
  'Observability / APM / SLO',
  |||
    **Observability**
    - [Services Health](/d/services-health) — live up/down status
    - [What's Down?](/d/home-whats-down) — incident diagnosis
    - [Dashboard Index](/d/dashboard-index) — complete navigator
    - [Grafana](/d/observability-grafana) — Grafana self-monitoring
    - [Alertmanager](/d/observability-alertmanager) — alert routing
    - [VMAlert](/d/observability-vmalert) — rule evaluation
    - [Logs](/d/observability-logs) — structured log search
    - [Alerts](/d/alerts-dashboard) — active alerts overview
    - [Metrics Discovery](/d/metrics-discovery) — cardinality & ingestion
    - [Performance](/d/performance-optimization) — query latency
    - [Cost Tracking](/d/cost-tracking) — storage & retention

    **APM & Traces**
    - [Pin Traces](/d/pin-traces) — distributed tracing
    - [Unified Traces](/d/apm-traces) — trace explorer
    - [API Gateway Tracing](/d/tracing-api-gateway) — request flows
    - [PostgreSQL Tracing](/d/tracing-postgresql) — slow query correlation

    **SLO & Analytics**
    - [SLO Overview](/d/slo-overview) — error budgets
    - [Health Scoring](/d/system-health-scoring) — risk analysis
    - [Service Dependencies](/d/service-dependencies) — blast radius
    - [Dashboard Usage](/d/dashboard-usage-analytics) — usage analytics
    - [Query Performance](/d/query-performance) — datasource latency
  |||,
  0, 22, 12, 6,
);

local directoryRight = linkPanel(
  'Services / Heater / Overview',
  |||
    **Services**
    - [PostgreSQL](/d/services-postgresql) · [Redis](/d/services-redis) · [ClickHouse](/d/services-clickhouse)
    - [Elasticsearch](/d/services-elasticsearch) · [Redpanda](/d/services-redpanda) · [Temporal](/d/services-temporal)
    - [Matrix](/d/services-matrix) · [NixOS MCP](/d/services-nixos-mcp) · [NixOS Deployer](/d/services-nixos-deployer)
    - [VictoriaLogs General](/d/pin-si-victorialogs-general) · [Homelab System](/d/services-homelab-system)

    **Heater (workstation)**
    - [Heater Home](/d/heater-home) — workstation overview
    - [System](/d/heater-system) · [Processes](/d/heater-processes) · [JVM](/d/heater-jvm)
    - [GPU](/d/heater-gpu) · [Networking](/d/heater-networking)
    - [Claude Code](/d/heater-claude-code) — agent activity

    **Overview**
    - [Homelab Overview](/d/homelab-overview) — system health
    - [Vector Pipeline](/d/pipeline-vector) — log/metric routing
    - [SkyWalking](/d/observability-skywalking) — distributed tracing OAP
    - [Serena Backends](/d/overview-serena-backends) — MCP backends

    **Data**
    - [Cockpit](http://cockpit.pin) · [Searxng](http://searxng.pin)
  |||,
  12, 22, 12, 6,
);

// ── Claude / MCP (y=28, h=3) ────────────────────────────────────────────────

local claudeRow = g.panel.row.new('Claude / MCP') + c.pos(0, 28, 24, 1);

local claudeProxyCard  = navCard('Claude Proxy',   'API proxy metrics',    '/d/claude-proxy')          + c.pos(0,  29, 6, 3);
local claudeCodeCard   = navCard('Claude Code',    'Agent activity',       '/d/heater-claude-code')    + c.pos(6,  29, 6, 3);
local mcpVanguardCard  = navCard('MCP Vanguard',   'MCP server metrics',   '/d/services-mcp-vanguard') + c.pos(12, 29, 6, 3);
local sbtcpCard        = navCard('SBTCP',          'Entity overview',      '/d/sbtcp-entity-overview') + c.pos(18, 29, 6, 3);

// ── Grafana Tools (y=32, h=3) ───────────────────────────────────────────────

local toolsRow = g.panel.row.new('Grafana Tools') + c.pos(0, 32, 24, 1);

// Logs Explore URL pre-selects VictoriaLogs datasource.
local logsExploreUrl = '/explore?schemaVersion=1&panes=%7B%22logs%22%3A%7B%22datasource%22%3A%22PD775F2863313E6C7%22%2C%22queries%22%3A%5B%7B%22refId%22%3A%22A%22%7D%5D%2C%22range%22%3A%7B%22from%22%3A%22now-1h%22%2C%22to%22%3A%22now%22%7D%7D%7D&orgId=1';

local exploreMetrics   = navCard('Metrics Explore',   'VictoriaMetrics query', '/explore')                         + c.pos(0,  33, 4, 3);
local exploreLogs      = navCard('Logs Explore',      'VictoriaLogs query',    logsExploreUrl)                     + c.pos(4,  33, 4, 3);
local tracesDrilldown  = navCard('Traces Drilldown',  'Traces explore app',    '/a/grafana-exploretraces-app/explore') + c.pos(8, 33, 4, 3);
local metricsDrilldown = navCard('Metrics Drilldown', 'Metrics drilldown app', '/a/grafana-metricsdrilldown-app/') + c.pos(12, 33, 4, 3);
local logsDrilldown    = navCard('Logs Drilldown',    'Logs explore app',      '/a/grafana-lokiexplore-app/')       + c.pos(16, 33, 4, 3);
local dashboardsNav    = navCard('Dashboards',        'All dashboard folders', '/dashboards')                       + c.pos(20, 33, 4, 3);

// ── Dashboard assembly ──────────────────────────────────────────────────────

g.dashboard.new('Pin SI — Home')
+ g.dashboard.withUid('pin-si-home')
+ g.dashboard.withDescription('Pin Soluciones Informáticas — Navigation Status Hub')
+ g.dashboard.withTags(['home', 'pin-si', 'navigation'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withEditable(false)
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([homeDsVar])
+ g.dashboard.withPanels([
    // Header
    headerPanel,
    // Status bar
    statusUpPanel, statusDownPanel, statusAlertsPanel, statusCpuPanel,
    // Infrastructure — Databases
    infraRow,
    vmCard, vlogsCard, pgCard, chCard,
    redisCard, esCard, rpCard, temporalCard,
    // Infrastructure — Utilities
    alertmgrCard, firecrawlCard, adguardCard, nexusCard, matrixCard, supersetCard,
    // Hunter Pipeline
    hunterRow,
    hunterPipelineCard, hunterSourcesCard, hunterNamespaceCard,
    cotCard, prefetchCard, arbitrajeCard, scalableCard, pathrankerCard, routeCard,
    // Dashboard Directory
    directoryRow,
    directoryLeft, directoryRight,
    // Claude / MCP
    claudeRow,
    claudeProxyCard, claudeCodeCard, mcpVanguardCard, sbtcpCard,
    // Grafana Tools
    toolsRow,
    exploreMetrics, exploreLogs, tracesDrilldown, metricsDrilldown, logsDrilldown, dashboardsNav,
  ])
