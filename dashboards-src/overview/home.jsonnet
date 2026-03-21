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
//   Claude/MCP   — Claude Proxy, Claude Code, MCP Vanguard, SBTCP
//   Grafana Tools — explore, drilldown, dashboards nav
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Constants ────────────────────────────────────────────────────────────────

local ALL_JOBS = 'alertmanager|clickhouse|elasticsearch-exporter|firecrawl|grafana|postgres-exporter|redis-exporter|redpanda|temporal|victoriametrics-self|victorialogs|vmalert';

// ── Card helpers ─────────────────────────────────────────────────────────────

// Base card: PromQL query drives green/red background. Entire card is clickable.
// Data links make the stat value area clickable; panel links cover the header.
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
  + g.panel.stat.standardOptions.withLinks([{ title: title, url: url, targetBlank: false }])
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name');

// Grafana nav links — no real metric, always green.
local navCard(title, subtitle, url) =
  svcCard(title, subtitle, 'vector(1)', url);

// Dashboard health card — green if job is up, red if down/absent.
local dbCard(title, subtitle, healthJob, url) =
  svcCard(title, subtitle, 'max(up{job="' + healthJob + '"})', url);

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
  + g.panel.stat.standardOptions.withLinks([{ title: 'Services Health', url: '/d/services-health', targetBlank: false }]);

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
  + g.panel.stat.standardOptions.withLinks([{ title: "What's Down?", url: '/d/home-whats-down', targetBlank: false }]);

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
  + g.panel.stat.standardOptions.withLinks([{ title: 'Alerting', url: '/d/alerts-dashboard', targetBlank: false }]);

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
  + g.panel.stat.standardOptions.withLinks([{ title: 'Homelab Overview', url: '/d/homelab-overview', targetBlank: false }]);

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

local alertmgrCard  = svcCard('Alertmanager', 'Alert routing',    'up{job="alertmanager"}',                        '/d/observability-alertmanager')             + c.pos(0,  11, 4, 3);
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

// ── Claude / MCP (y=21, h=3) ────────────────────────────────────────────────

local claudeRow = g.panel.row.new('Claude / MCP') + c.pos(0, 21, 24, 1);

local claudeProxyCard  = navCard('Claude Proxy',   'API proxy metrics',    '/d/claude-proxy')          + c.pos(0,  22, 6, 3);
local claudeCodeCard   = navCard('Claude Code',    'Agent activity',       '/d/heater-claude-code')    + c.pos(6,  22, 6, 3);
local mcpVanguardCard  = navCard('MCP Vanguard',   'MCP server metrics',   '/d/services-mcp-vanguard') + c.pos(12, 22, 6, 3);
local sbtcpCard        = navCard('SBTCP',          'Entity overview',      '/d/sbtcp-entity-overview') + c.pos(18, 22, 6, 3);

// ── Grafana Tools (y=25, h=3) ───────────────────────────────────────────────

local toolsRow = g.panel.row.new('Grafana Tools') + c.pos(0, 25, 24, 1);

// Explore URLs pre-select the correct datasource.
local metricsExploreUrl = '/explore?schemaVersion=1&panes=%7B%22vm%22%3A%7B%22datasource%22%3A%22P4169E866C3094E38%22%2C%22queries%22%3A%5B%7B%22refId%22%3A%22A%22%2C%22datasource%22%3A%7B%22type%22%3A%22victoriametrics-metrics-datasource%22%2C%22uid%22%3A%22P4169E866C3094E38%22%7D%7D%5D%2C%22range%22%3A%7B%22from%22%3A%22now-1h%22%2C%22to%22%3A%22now%22%7D%2C%22compact%22%3Afalse%7D%7D&orgId=1';
local logsExploreUrl = '/explore?schemaVersion=1&panes=%7B%22qfl%22%3A%7B%22datasource%22%3A%22PD775F2863313E6C7%22%2C%22queries%22%3A%5B%7B%22refId%22%3A%22A%22%2C%22datasource%22%3A%7B%22type%22%3A%22victoriametrics-logs-datasource%22%2C%22uid%22%3A%22PD775F2863313E6C7%22%7D%7D%5D%2C%22range%22%3A%7B%22from%22%3A%22now-1h%22%2C%22to%22%3A%22now%22%7D%2C%22compact%22%3Afalse%7D%7D&orgId=1';

local exploreMetrics   = navCard('Metrics Explore',   'VictoriaMetrics query', metricsExploreUrl)                   + c.pos(0,  26, 4, 3);
local exploreLogs      = navCard('Logs Explore',      'VictoriaLogs query',    logsExploreUrl)                     + c.pos(4,  26, 4, 3);
local tracesDrilldown  = navCard('Traces Drilldown',  'Traces explore app',    '/a/grafana-exploretraces-app/explore') + c.pos(8, 26, 4, 3);
local metricsDrilldown = navCard('Metrics Drilldown', 'Metrics drilldown app', '/a/grafana-metricsdrilldown-app/?var-ds=P4169E866C3094E38') + c.pos(12, 26, 4, 3);
local dashboardsNav    = navCard('Dashboards',        'All dashboard folders', '/dashboards')                                                + c.pos(16, 26, 4, 3);

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
    // Claude / MCP
    claudeRow,
    claudeProxyCard, claudeCodeCard, mcpVanguardCard, sbtcpCard,
    // Grafana Tools
    toolsRow,
    exploreMetrics, exploreLogs, tracesDrilldown, metricsDrilldown, dashboardsNav,
  ])
