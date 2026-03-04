// Dashboard: Pin SI — Home
//
// Launchpad hub — grid of cards for all services and Grafana dashboards.
// Design: "Operator Terminal" — clean precision, monospace identifiers,
//   category accent borders, smooth hover transitions.
// All panels are transparent to eliminate Grafana's chrome (double titles/borders).
// Rows:
//   0  Header — Pin SI branding + live clock
//   1  Observability — Metrics · Logs · Traces · Alerts
//   2  System Apps — Temporal · Superset · Nexus · AdGuard · Redpanda · Matrix Chat
//   3  Arbitrage — Dev · Prod (dashboards)
//   4  Matrix Suite — Explorer · Vault · Generator · Technicals (Dev+Prod dashboards)
//   5  Dashboards — internal Grafana dashboard links
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Header panel (row 0) ─────────────────────────────────────────────────────

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
      width:40px; height:40px; flex-shrink:0;
      background: rgba(255,255,255,0.2);
      backdrop-filter: blur(8px);
      border-radius:10px;
      display:flex; align-items:center; justify-content:center;
      color:#fff; font-size:20px; font-weight:900; letter-spacing:-1px;
      border: 1px solid rgba(255,255,255,0.25);
    }
    #pin-header .name {
      font-size:17px; font-weight:700; color:#fff; letter-spacing:-0.025em;
    }
    #pin-header .tagline {
      font-size:10px; color:rgba(255,255,255,0.7); letter-spacing:0.12em;
      text-transform:uppercase; margin-top:2px;
      font-family: "SFMono-Regular", Consolas, monospace;
    }
    #pin-header .meta { text-align:right; }
    #pin-clock {
      font-family: "SFMono-Regular", Consolas, monospace;
      font-size:13px; font-weight:500; color:#fff;
      font-variant-numeric: tabular-nums;
      letter-spacing:0.01em;
    }
    #pin-uptime {
      font-family: "SFMono-Regular", Consolas, monospace;
      font-size:10px; color:rgba(255,255,255,0.6); margin-top:3px;
      letter-spacing:0.05em;
    }
  </style>
  <div id="pin-header">
    <div class="brand">
      <div class="logo">P</div>
      <div>
        <div class="name">Pin Soluciones Informáticas</div>
        <div class="tagline">observability.hub / production</div>
      </div>
    </div>
    <div class="meta">
      <div id="pin-clock"></div>
      <div id="pin-uptime"></div>
    </div>
  </div>
  <script>
    (function() {
      var start = Date.now();
      function pad(n) { return n < 10 ? '0' + n : n; }
      function tick() {
        var now = new Date();
        var cl = document.getElementById('pin-clock');
        if (cl) cl.textContent = now.toLocaleString('es-ES', {
          weekday:'short', year:'numeric', month:'short', day:'numeric',
          hour:'2-digit', minute:'2-digit', second:'2-digit'
        });
        var up = document.getElementById('pin-uptime');
        if (up) {
          var s = Math.floor((Date.now() - start) / 1000);
          var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
          up.textContent = 'session ' + pad(h) + ':' + pad(m) + ':' + pad(sec);
        }
      }
      tick();
      setInterval(tick, 1000);
    })();
  </script>
|||;

local headerPanel =
  g.panel.text.new('Pin SI')
  + g.panel.text.panelOptions.withDescription('')
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(headerHtml)
  + c.pos(0, 0, 24, 3);

// ── Card helper ──────────────────────────────────────────────────────────────
// accent: CSS color string for the left border stripe (category identity)
// badge:  short label shown top-right (e.g. "obs", "app", "dash")

local cardHtml(icon, title, subtitle, url, accent='#7c3aed', badge='', external=false) =
  local target = if external then '_blank' else '_self';
  local extMark = if external then ' ↗' else '';
  |||
    <a href="%(url)s" target="%(target)s"
      style="
        display:flex; align-items:center; gap:14px;
        padding:16px 18px; height:100%%; width:100%%;
        background:#ffffff;
        border:1px solid #e4e4eb;
        border-left:4px solid %(accent)s;
        border-radius:8px;
        text-decoration:none; color:inherit;
        font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        cursor:pointer; box-sizing:border-box;
        transition: box-shadow 0.18s ease, border-color 0.18s ease, transform 0.18s ease;
        overflow:hidden;
      "
      onmouseover="this.style.boxShadow='0 4px 16px rgba(0,0,0,0.08)';this.style.transform='translateY(-1px)';"
      onmouseout="this.style.boxShadow='none';this.style.transform='translateY(0)';"
    >
      <div style="
        width:40px; height:40px; flex-shrink:0;
        background:%(accent)s10;
        border-radius:10px;
        display:flex; align-items:center; justify-content:center;
        font-size:20px; line-height:1;
      ">%(icon)s</div>
      <div style="flex:1; min-width:0;">
        <div style="display:flex; align-items:baseline; justify-content:space-between;">
          <div style="font-size:14px; font-weight:700; color:#111827; letter-spacing:-0.01em;">%(title)s</div>
          <span style="
            font-family:'SFMono-Regular',Consolas,monospace;
            font-size:9px; font-weight:600; letter-spacing:0.1em;
            color:%(accent)s; text-transform:uppercase; opacity:0.6;
          ">%(badge)s%(extMark)s</span>
        </div>
        <div style="
          font-family:'SFMono-Regular',Consolas,monospace;
          font-size:10px; color:#9ca3af; margin-top:2px; letter-spacing:0.02em;
          white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
        ">%(subtitle)s</div>
      </div>
    </a>
  ||| % {
    url: url, target: target, icon: icon, title: title,
    subtitle: subtitle, accent: accent, badge: badge, extMark: extMark,
  };

// Helper: create a transparent text panel with card HTML.
local card(name, icon, title, subtitle, url, accent, badge, pos, external=false) =
  g.panel.text.new(name)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(cardHtml(icon, title, subtitle, url, accent, badge, external))
  + pos;

// ── Alert panel & troubleshooting guide ────────────────────────────────────

local alertPanel = c.alertCountPanel('home', col=0);

local troubleGuide = c.serviceTroubleshootingGuide('home', [
  { symptom: 'Service Unavailable', runbook: 'general/service-recovery', check: 'Check Infrastructure row for service status indicators' },
  { symptom: 'Observability Down', runbook: 'general/obs-recovery', check: 'Verify Metrics, Logs, and Traces links accessible from Observability row' },
  { symptom: 'Dashboard Not Found', runbook: 'general/dashboard-search', check: 'Use Dashboards row or search for specific service dashboard' },
  { symptom: 'External Tool Unreachable', runbook: 'general/connectivity', check: 'Check System Apps row (Temporal, Superset, etc.) and network status' },
], y=1);

// ── Color palette ────────────────────────────────────────────────────────────
local obsColor  = '#7c3aed';  // violet — observability
local appColor  = '#2563eb';  // blue   — system apps
local arbColor  = '#059669';  // emerald — arbitrage
local mtxColor  = '#d946ef';  // fuchsia — matrix suite
local dashColor  = '#475569';  // slate  — dashboards
local infraColor = '#0891b2';  // cyan   — infrastructure
local svcColor   = '#d97706';  // amber  — services
local pipeColor  = '#be185d';  // rose   — pipeline & APM

// ── Observability row (y=4) ──────────────────────────────────────────────────

local metricsCard = card('Metrics',  '📊', 'Metrics',    'vmui · explore',   'http://victoria.pin/vmui', obsColor, 'obs', c.pos(0,  4, 6, 4), true);
local logsCard    = card('Logs',     '📋', 'Logs',       'live tail',        'http://logs.pin/select/vmui', obsColor, 'obs', c.pos(6,  4, 6, 4), true);
local tracesCard  = card('Traces',   '🔍', 'Pin Traces', 'apm · skywalking',  'http://traces.pin',           obsColor, 'obs', c.pos(12, 4, 6, 4), true);
local alertsCard  = card('Alerts',   '🔔', 'Alerts',     'rules · history',  '/alerting/list',              obsColor, 'obs', c.pos(18, 4, 6, 4));

// ── System Apps row (y=9) ────────────────────────────────────────────────────

local temporalCard = card('Temporal', '⏱',  'Temporal',    'workflow-engine', 'http://temporal.pin', appColor, 'app', c.pos(0,  9, 4, 4), true);
local supersetCard = card('Superset', '📊', 'Superset',   'data-analytics',  'http://superset.pin', appColor, 'app', c.pos(4,  9, 4, 4), true);
local nexusCard    = card('Nexus',    '📦', 'Nexus',      'artifact-registry','http://nexus.pin',    appColor, 'app', c.pos(8,  9, 4, 4), true);
local adguardCard  = card('AdGuard',  '🛡',  'AdGuard',    'dns-filtering',   'http://adguard.pin',  appColor, 'app', c.pos(12, 9, 4, 4), true);
local redpandaCard = card('Redpanda', '🗄',  'Redpanda',   'kafka-console',   'http://redpanda.pin', appColor, 'app', c.pos(16, 9, 4, 4), true);
local matrixChat   = card('Matrix',   '💬', 'Matrix Chat', 'element-web',     'https://matrix.abstract.bike', appColor, 'app', c.pos(20, 9, 4, 4), true);

// ── Arbitrage row (y=14) — dashboards ────────────────────────────────────────

local arbDevCard  = card('Arb Dev',  '📈', 'Arbitrage Dev',  '/d/arbitraje-dev',  '/d/arbitraje-dev',  arbColor, 'dev',  c.pos(0,  14, 12, 4));
local arbProdCard = card('Arb Prod', '📈', 'Arbitrage Prod', '/d/arbitraje-main', '/d/arbitraje-main', arbColor, 'prod', c.pos(12, 14, 12, 4));

// ── Matrix Suite row (y=19) — dashboards ─────────────────────────────────────

local mxExplorerDev  = card('Explorer Dev',    '🔎', 'Explorer Dev',    '/d/matrix-explorer-dev',    '/d/matrix-explorer-dev',    mtxColor, 'dev',  c.pos(0,  19, 6, 4));
local mxExplorerProd = card('Explorer Prod',   '🔎', 'Explorer Prod',   '/d/matrix-explorer',        '/d/matrix-explorer',        mtxColor, 'prod', c.pos(6,  19, 6, 4));
local mxVaultDev     = card('Vault Dev',       '🔐', 'Vault Dev',       '/d/matrix-vault-dev',       '/d/matrix-vault-dev',       mtxColor, 'dev',  c.pos(12, 19, 6, 4));
local mxVaultProd    = card('Vault Prod',      '🔐', 'Vault Prod',      '/d/matrix-vault',           '/d/matrix-vault',           mtxColor, 'prod', c.pos(18, 19, 6, 4));
local mxGeneratorDev = card('Generator Dev',   '⚙',  'Generator Dev',   '/d/matrix-generator-dev',   '/d/matrix-generator-dev',   mtxColor, 'dev',  c.pos(0,  23, 6, 4));
local mxGeneratorProd= card('Generator Prod',  '⚙',  'Generator Prod',  '/d/matrix-generator',       '/d/matrix-generator',       mtxColor, 'prod', c.pos(6,  23, 6, 4));
local mxTechDev      = card('Technicals Dev',  '📐', 'Technicals Dev',  '/d/matrix-technicals-dev',  '/d/matrix-technicals-dev',  mtxColor, 'dev',  c.pos(12, 23, 6, 4));
local mxTechProd     = card('Technicals Prod', '📐', 'Technicals Prod', '/d/matrix-technicals',      '/d/matrix-technicals',      mtxColor, 'prod', c.pos(18, 23, 6, 4));

// ── Dashboards row (y=28) — verified UIDs from Grafana API ──────────────────

local dbCard(icon, title, uid, pos) =
  card(title, icon, title, '/d/' + uid, '/d/' + uid, dashColor, 'dash', pos);

// Colored dashboard card — same as dbCard but with an explicit accent color and subtitle.
local cdbCard(icon, title, sub, uid, color, pos) =
  card(title, icon, title, sub, '/d/' + uid, color, 'dash', pos);

local homelabCard  = dbCard('🖥',  'Homelab',         'homelab-overview',         c.pos(0,  28, 4, 4));
local claudeCard   = dbCard('🤖', 'Claude Metrics',  'claude-metrics-v1',        c.pos(4,  28, 4, 4));
local tracesDbCard = dbCard('🔍', 'Pin Traces',      'pin-traces',               c.pos(8,  28, 4, 4));
local serenaCard   = dbCard('🧠', 'Serena MCP',      'serena-mcp-observability', c.pos(12, 28, 4, 4));
local vmCard       = dbCard('📈', 'VictoriaMetrics', 'vm-overview',              c.pos(16, 28, 4, 4));
local swCard       = dbCard('🌐', 'SkyWalking',     'observability-skywalking',           c.pos(20, 28, 4, 4));

// ── Heater Infrastructure row (y=33) ─────────────────────────────────────────

local homelabSysCard      = cdbCard('🖥',  'Homelab',      'cpu · mem · network', 'services-homelab-system', infraColor, c.pos(0,  33, 4, 4));
local heaterSystemCard    = cdbCard('🖥',  'Heater Sys',   'cpu · mem · disk',    'heater-system',           infraColor, c.pos(4,  33, 4, 4));
local heaterJvmCard       = cdbCard('☕',  'JVM',          'heap · gc · threads', 'heater-jvm',              infraColor, c.pos(8,  33, 4, 4));
local heaterGpuCard       = cdbCard('🎮',  'GPU',          'vram · utilization',  'heater-gpu',              infraColor, c.pos(12, 33, 4, 4));
local heaterProcCard      = cdbCard('⚙',   'Processes',    'top · cpu · mem',     'heater-processes',        infraColor, c.pos(16, 33, 4, 4));
local heaterClaudeCard    = cdbCard('🤖',  'Claude Code',  'tokens · cost · ctx', 'heater-claude-code',      infraColor, c.pos(20, 33, 4, 4));

// ── Services row (y=38) ───────────────────────────────────────────────────────

local temporalDbCard   = cdbCard('⏱',  'Temporal',      'workflows · queues', 'services-temporal',       svcColor, c.pos(0,  38, 4, 4));
local postgresDbCard   = cdbCard('🐘',  'PostgreSQL',    'queries · pool',     'services-postgresql',     svcColor, c.pos(4,  38, 4, 4));
local redisDbCard      = cdbCard('🔴',  'Redis',         'cache · memory',     'services-redis',          svcColor, c.pos(8,  38, 4, 4));
local clickhouseDbCard = cdbCard('⚡',  'ClickHouse',    'insert · select',    'services-clickhouse',     svcColor, c.pos(12, 38, 4, 4));
local elasticDbCard    = cdbCard('🔍',  'Elasticsearch', 'index · search',     'services-elasticsearch',  svcColor, c.pos(16, 38, 4, 4));
local redpandaDbCard   = cdbCard('📡',  'Redpanda',      'kafka · topics',     'services-redpanda',       svcColor, c.pos(20, 38, 4, 4));

// ── Pipeline & APM row (y=43) ─────────────────────────────────────────────────

local vectorDbCard     = cdbCard('🚀', 'Vector',          'pipeline · ingest', 'pipeline-vector',            pipeColor, c.pos(0,  43, 4, 4));
local alertmgrDbCard   = cdbCard('🔔', 'Alertmanager',    'rules · silences',  'observability-alertmanager', pipeColor, c.pos(4,  43, 4, 4));
local vmalertDbCard    = cdbCard('📢', 'VM Alert',        'eval · firing',     'observability-vmalert',      pipeColor, c.pos(8,  43, 4, 4));
local sloDbCard        = cdbCard('📊', 'SLO Overview',    'error budgets',     'slo-overview',               pipeColor, c.pos(12, 43, 4, 4));
local serenaBackDbCard = cdbCard('🧠', 'Serena Backends', 'lsp · indexing',    'overview-serena-backends',   pipeColor, c.pos(16, 43, 4, 4));
local logsDbCard       = cdbCard('📋', 'Logs',            'all-services · levels', 'observability-logs',        pipeColor, c.pos(20, 43, 4, 4));
local matrixApmDbCard     = cdbCard('💬', 'Matrix APM',       'requests · spans',   'matrix-apm-skywalking',    pipeColor, c.pos(0,  47, 4, 4));
local nixosDeployerDbCard = cdbCard('🚀', 'NixOS Deployer',   'gitops · deploys',   'services-nixos-deployer',  pipeColor, c.pos(4,  47, 4, 4));
local grafanaSelfDbCard   = cdbCard('📊', 'Grafana',          'http · alerts · ds', 'observability-grafana',    pipeColor, c.pos(8,  47, 4, 4));

// ── New Dashboards row (y=51) ─────────────────────────────────────────────
local newRow  = g.panel.row.new('✨ New Dashboards') + c.pos(0, 51, 24, 1);
local newCard = card('New Dashboards', '📂', 'New Dashboards',
                     'dashboards_new/ · auto-provisioned',
                     '/dashboards', dashColor, 'new', c.pos(0, 52, 6, 4));

// ── Row separators ───────────────────────────────────────────────────────────

local observabilityRow = g.panel.row.new('📊 Observability')        + c.pos(0, 3,  24, 1);
local appsRow          = g.panel.row.new('🔧 System Apps')          + c.pos(0, 8,  24, 1);
local arbitrageRow     = g.panel.row.new('📈 Arbitrage')            + c.pos(0, 13, 24, 1);
local matrixRow        = g.panel.row.new('💬 Matrix Suite')         + c.pos(0, 18, 24, 1);
local dashboardsRow    = g.panel.row.new('📋 Dashboards')           + c.pos(0, 27, 24, 1);
local heaterRow        = g.panel.row.new('🏗️ Infrastructure')       + c.pos(0, 32, 24, 1);
local servicesRow      = g.panel.row.new('⚡ Services')             + c.pos(0, 37, 24, 1);
local pipelineRow      = g.panel.row.new('🔄 Pipeline & APM')       + c.pos(0, 42, 24, 1);

// ── Dashboard assembly ───────────────────────────────────────────────────────

g.dashboard.new('Pin SI — Home')
+ g.dashboard.withUid('pin-si-home')
+ g.dashboard.withDescription('Pin Soluciones Informáticas — Central Operations & Observability Hub. Navigation dashboard providing quick access to all observability dashboards (metrics, logs, traces, alerts), infrastructure services (databases, cache, message brokers), and external tools (Temporal, Superset, Matrix Chat, Redpanda Console).')
+ g.dashboard.withTags(['home', 'pin-si', 'critical'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withEditable(false)
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([c.vmDsVar, c.swDsVar])
+ g.dashboard.withPanels([
    c.externalLinksPanel(y=0, x=18),
    alertPanel,
    headerPanel,
    troubleGuide,
    observabilityRow,
    metricsCard, logsCard, tracesCard, alertsCard,
    appsRow,
    temporalCard, supersetCard, nexusCard, adguardCard, redpandaCard, matrixChat,
    arbitrageRow,
    arbDevCard, arbProdCard,
    matrixRow,
    mxExplorerDev, mxExplorerProd, mxVaultDev, mxVaultProd,
    mxGeneratorDev, mxGeneratorProd, mxTechDev, mxTechProd,
    dashboardsRow,
    homelabCard, claudeCard, tracesDbCard, serenaCard, vmCard, swCard,
    heaterRow,
    homelabSysCard, heaterSystemCard, heaterJvmCard, heaterGpuCard, heaterProcCard, heaterClaudeCard,
    servicesRow,
    temporalDbCard, postgresDbCard, redisDbCard, clickhouseDbCard, elasticDbCard, redpandaDbCard,
    pipelineRow,
    vectorDbCard, alertmgrDbCard, vmalertDbCard, sloDbCard, serenaBackDbCard, logsDbCard, matrixApmDbCard, nixosDeployerDbCard, grafanaSelfDbCard,
    newRow, newCard,
  ])
