// Dashboard: Pin SI — Home
//
// Navigation Status Hub — replaces Grafana sidebar with a full-viewport launchpad.
// All cards are stat panels with real-time green/red health indicators.
// Kiosk mode active via nginx CSS injection (modules/nginx.nix [data-page-type="home"]).
//
// Sections:
//   Grafana Navigation — nav links (always green via vector(1))
//   Grafana Dashboards — dashboard links with no-data health check
//   Homelab Services   — service cards via up{job} or probe_success{instance}
//
// Health queries:
//   svcCard: up{job="..."} or probe_success{instance="http://..."} — 0=red, 1=green
//   navCard: vector(1) — always green (Grafana built-in URLs)
//   dbCard:  clamp_max(count_over_time(up{job}[5m]),1) or vector(0) — data present check
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Card helpers ──────────────────────────────────────────────────────────────

// Base card: PromQL query drives green/red background. Click navigates same tab.
local svcCard(title, subtitle, query, url) =
  g.panel.stat.new(title)
  + g.panel.stat.panelOptions.withDescription(subtitle)
  + g.panel.stat.queryOptions.withTargets([c.vmQ(query)])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'red',   value: null },
      { color: 'red',   value: 0 },
      { color: 'green', value: 1 },
    ])
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('none')
  + g.panel.stat.panelOptions.withLinks([{ title: title, url: url, targetBlank: false }]);

// Grafana nav links — no real metric, always green.
local navCard(title, subtitle, url) =
  svcCard(title, subtitle, 'vector(1)', url);

// Dashboard health card — green if job is up, red if down/absent.
// max() collapses multi-instance jobs to a single series; avoids the
// "split card" caused by `or vector(0)` adding an extra series.
local dbCard(title, subtitle, healthJob, url) =
  svcCard(title, subtitle, 'max(up{job="' + healthJob + '"})', url);

// Restrict datasource picker to the production homelab VictoriaMetrics instance.
// Without the regex, Grafana picks HunterMetrics-Dev (port 9430) first — that
// instance has no homelab up{} metrics, making all svcCard panels red.
local homeDsVar =
  g.dashboard.variable.datasource.new('datasource', 'victoriametrics-metrics-datasource')
  + g.dashboard.variable.datasource.generalOptions.withLabel('Metrics')
  + g.dashboard.variable.datasource.withRegex('^VictoriaMetrics$');

// ── Header panel (x=0, y=0, w=24, h=2) ───────────────────────────────────────

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
  g.panel.text.new('Pin SI')
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(headerHtml)
  + c.pos(0, 0, 24, 2);

// ── Grafana Navigation (x=0..18, y=3 and y=7) ────────────────────────────────

local grafanaRow = g.panel.row.new('Grafana Navigation') + c.pos(0, 2, 24, 1);

local exploreMetrics   = navCard('Metrics Explore',   'VictoriaMetrics query', '/explore')                             + c.pos(0,  3, 6, 4);
local exploreLogs      = navCard('Logs Explore',      'VictoriaLogs query',    '/explore')                             + c.pos(6,  3, 6, 4);
local alertingNav      = navCard('Alerting',          'Rules & notifications', '/alerting')                            + c.pos(12, 3, 6, 4);
local dashboardsNav    = navCard('Dashboards',        'All dashboard folders', '/dashboards')                          + c.pos(18, 3, 6, 4);

local metricsDrilldown = navCard('Metrics Drilldown', 'Metrics drilldown app', '/a/grafana-metricsdrilldown-app/')     + c.pos(0,  7, 6, 4);
local logsDrilldown    = navCard('Logs Drilldown',    'Logs explore app',      '/a/grafana-lokiexplore-app/')           + c.pos(6,  7, 6, 4);
local tracesDrilldown  = navCard('Traces Drilldown',  'Traces explore app',    '/a/grafana-exploretraces-app/explore') + c.pos(12, 7, 6, 4);
local profilesNav      = navCard('Profiles',          'Pyroscope profiling',   '/a/grafana-pyroscope-app/')            + c.pos(18, 7, 6, 4);

// ── Grafana Dashboards (x=0..18, y=12 and y=16) ──────────────────────────────

local dashboardsRow = g.panel.row.new('Grafana Dashboards') + c.pos(0, 11, 24, 1);

// dbCard: green if job has data in last 5m. navCard: always green (no reliable metric).
local homelabDb   = dbCard('Homelab Overview', 'System health',      'victoriametrics-self', '/d/homelab-overview') + c.pos(0,  12, 6, 4);
local arbitrajeDb = dbCard('Arbitraje',        'Trading pipeline',   'arbitraje',            '/d/arbitraje')        + c.pos(6,  12, 6, 4);
local pinTracesDb = navCard('Pin Traces',       'APM traces',                                 '/d/pin-traces')       + c.pos(12, 12, 6, 4);
local serenaMcpDb = navCard('Serena MCP',       'MCP server metrics',                         '/d/serena-mcp')       + c.pos(18, 12, 6, 4);

local vectorDb    = navCard('Vector Pipeline',  'Log/metric pipeline',                        '/d/vector-pipeline')  + c.pos(0,  16, 6, 4);
local sloDb       = navCard('SLO Overview',     'Error budgets',                              '/d/slo-overview')     + c.pos(6,  16, 6, 4);
local systemDb    = navCard('Homelab System',   'Host resources',                             '/d/homelab-system')   + c.pos(12, 16, 6, 4);
local jobHunterDb = navCard('Job Hunter',       'Pipeline metrics',                           '/d/job-hunter')       + c.pos(18, 16, 6, 4);

// ── Homelab Services — up{job} (x=0..18, y=21 and y=25) ─────────────────────

local servicesRow = g.panel.row.new('Homelab Services') + c.pos(0, 20, 24, 1);

local vmCard      = svcCard('VictoriaMetrics', 'Metrics storage',    'up{job="victoriametrics-self"}',   'http://victoria.pin')  + c.pos(0,  21, 6, 4);
local vlogsCard   = svcCard('VictoriaLogs',   'Log storage',         'up{job="victorialogs"}',           'http://logs.pin')      + c.pos(6,  21, 6, 4);
local chCard      = svcCard('ClickHouse',     'Columnar analytics',  'up{job="clickhouse"}',             'http://clickhouse.pin')+ c.pos(12, 21, 6, 4);
local rpCard      = svcCard('Redpanda',       'Kafka-compat MQ',     'up{job="redpanda"}',               'http://redpanda.pin')  + c.pos(18, 21, 6, 4);

local pgCard      = svcCard('PostgreSQL',     'Relational DB',       'up{job="postgres-exporter"}',      '/d/postgresql')        + c.pos(0,  25, 6, 4);
local redisCard   = svcCard('Redis',          'In-memory cache',     'up{job="redis-exporter"}',         '/d/redis')             + c.pos(6,  25, 6, 4);
local esCard      = svcCard('Elasticsearch',  'Search & analytics',  'up{job="elasticsearch-exporter"}', '/d/elasticsearch')     + c.pos(12, 25, 6, 4);
local temporalCard= svcCard('Temporal',       'Workflow engine',     'up{job="temporal"}',               'http://temporal.pin')  + c.pos(18, 25, 6, 4);

// ── Homelab Services — probe_success (x=0..18, y=29 and y=33) ────────────────
// Requires blackbox exporter: modules/exporters.nix + modules/victoriametrics.nix

local firecrawlCard = svcCard('Firecrawl',  'Web scraping',    'up{job="firecrawl"}',                          'http://firecrawl.pin') + c.pos(0,  29, 6, 4);
local alertmgrCard  = svcCard('Alertmanager','Alert routing',  'up{job="alertmanager"}',                       '/alerting')            + c.pos(6,  29, 6, 4);
local adguardCard   = svcCard('AdGuard',    'DNS filtering',   'probe_success{instance="http://adguard.pin"}', 'http://adguard.pin')   + c.pos(12, 29, 6, 4);
local nexusCard     = svcCard('Nexus',      'Artifact registry','probe_success{instance="http://nexus.pin"}',  'http://nexus.pin')     + c.pos(18, 29, 6, 4);

local matrixCard    = svcCard('Matrix',     'Chat server',     'probe_success{instance="http://matrix.pin"}',  'http://matrix.pin')    + c.pos(0,  33, 6, 4);
local supersetCard  = svcCard('Superset',   'Data analytics',  'probe_success{instance="http://superset.pin"}','http://superset.pin')  + c.pos(6,  33, 6, 4);
local cockpitCard   = svcCard('Cockpit',    'System admin',    'probe_success{instance="http://cockpit.pin"}', 'http://cockpit.pin')   + c.pos(12, 33, 6, 4);
local searxngCard   = svcCard('Searxng',    'Search engine',   'probe_success{instance="http://searxng.pin"}', 'http://searxng.pin')   + c.pos(18, 33, 6, 4);

// ── Dashboard assembly ────────────────────────────────────────────────────────

g.dashboard.new('Pin SI — Home')
+ g.dashboard.withUid('pin-si-home')
+ g.dashboard.withDescription('Pin Soluciones Informáticas — Navigation Status Hub')
+ g.dashboard.withTags(['home', 'pin-si', 'navigation'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withEditable(false)
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([homeDsVar])
+ g.dashboard.withPanels([
    headerPanel,
    grafanaRow,
    exploreMetrics, exploreLogs, alertingNav, dashboardsNav,
    metricsDrilldown, logsDrilldown, tracesDrilldown, profilesNav,
    dashboardsRow,
    homelabDb, arbitrajeDb, pinTracesDb, serenaMcpDb,
    vectorDb, sloDb, systemDb, jobHunterDb,
    servicesRow,
    vmCard, vlogsCard, chCard, rpCard,
    pgCard, redisCard, esCard, temporalCard,
    firecrawlCard, alertmgrCard, adguardCard, nexusCard,
    matrixCard, supersetCard, cockpitCard, searxngCard,
  ])
