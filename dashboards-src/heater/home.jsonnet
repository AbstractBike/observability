// Dashboard: Heater — Home
//
// Landing page for the heater developer workstation.
// Shows health summary from all subsystems (CPU, memory, GPU, JVM, Claude Code)
// with navigation cards to each detailed dashboard.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Color palette ────────────────────────────────────────────────────────────
local sysColor   = '#0891b2';  // cyan   — system
local gpuColor   = '#7c3aed';  // violet — gpu
local jvmColor   = '#059669';  // emerald — jvm
local aiColor    = '#d946ef';  // fuchsia — claude
local procColor  = '#d97706';  // amber — processes

// ── Header ───────────────────────────────────────────────────────────────────

local headerHtml = |||
  <style>
    #heater-header {
      display:flex; align-items:center; justify-content:space-between;
      padding: 12px 20px;
      background: linear-gradient(135deg, #0891b2 0%, #0e7490 100%);
      border-radius: 10px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      box-sizing: border-box; height: 100%%; color: #fff;
    }
    #heater-header .brand { display:flex; align-items:center; gap:12px; }
    #heater-header .logo {
      width:36px; height:36px; flex-shrink:0;
      background: rgba(255,255,255,0.2); backdrop-filter: blur(8px);
      border-radius:8px; display:flex; align-items:center; justify-content:center;
      font-size:18px; border: 1px solid rgba(255,255,255,0.25);
    }
    #heater-header .name { font-size:16px; font-weight:700; letter-spacing:-0.025em; }
    #heater-header .tagline {
      font-size:10px; color:rgba(255,255,255,0.7); letter-spacing:0.12em;
      text-transform:uppercase; margin-top:1px;
      font-family: "SFMono-Regular", Consolas, monospace;
    }
  </style>
  <div id="heater-header">
    <div class="brand">
      <div class="logo">H</div>
      <div>
        <div class="name">Heater — Developer Workstation</div>
        <div class="tagline">system / gpu / jvm / claude code / processes</div>
      </div>
    </div>
  </div>
|||;

local headerPanel =
  g.panel.text.new('Heater')
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(headerHtml)
  + c.pos(0, 0, 24, 2);

// ── Health Stats — one key metric per subsystem ──────────────────────────────

local cpuStat =
  g.panel.stat.new('CPU')
  + c.pos(0, 2, 5, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(100 - avg(rate(node_cpu_seconds_total{mode="idle",host="heater"}[5m])) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local memStat =
  g.panel.stat.new('Memory')
  + c.pos(5, 2, 5, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((1 - node_memory_MemAvailable_bytes{host="heater"} / node_memory_MemTotal_bytes{host="heater"}) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local gpuStat =
  g.panel.stat.new('GPU')
  + c.pos(10, 2, 5, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(nvidia_smi_utilization_gpu_ratio{host="heater"} * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local heapStat =
  g.panel.stat.new('JVM Heap')
  + c.pos(15, 2, 4, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(jvm_memory_used_bytes{host="heater",area="heap"}) / sum(jvm_memory_max_bytes{host="heater",area="heap"}) * 100) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local claudeCostStat =
  g.panel.stat.new('Claude $')
  + c.pos(19, 2, 5, 4)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_prompt_session_cost_usd{host="heater"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 5 },
    { color: 'red', value: 20 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

// ── Navigation cards ─────────────────────────────────────────────────────────

local cardHtml(icon, title, subtitle, url, accent) =
  |||
    <a href="%(url)s" target="_self"
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
        transition: box-shadow 0.18s ease, transform 0.18s ease;
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
        <div style="font-size:14px; font-weight:700; color:#111827; letter-spacing:-0.01em;">%(title)s</div>
        <div style="
          font-family:'SFMono-Regular',Consolas,monospace;
          font-size:10px; color:#9ca3af; margin-top:2px; letter-spacing:0.02em;
        ">%(subtitle)s</div>
      </div>
    </a>
  ||| % { url: url, icon: icon, title: title, subtitle: subtitle, accent: accent };

local navCard(name, icon, title, subtitle, uid, accent, pos) =
  g.panel.text.new(name)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(cardHtml(icon, title, subtitle, '/d/' + uid, accent))
  + pos;

local systemCard  = navCard('System',    '🖥',  'System',     'cpu / memory / disk / network', 'heater-system',    sysColor,  c.pos(0,  7, 8, 4));
local gpuCard     = navCard('GPU',       '🎮',  'GPU',        'utilization / vram / temp',     'heater-gpu',       gpuColor,  c.pos(8,  7, 8, 4));
local jvmCard     = navCard('JVM',       '☕',  'JVM',        'heap / gc / threads',           'heater-jvm',       jvmColor,  c.pos(16, 7, 8, 4));
local claudeCard  = navCard('Claude',    '🤖', 'Claude Code', 'tokens / cost / mcp traces',   'heater-claude-code', aiColor, c.pos(0,  11, 12, 4));
local processCard = navCard('Processes', '⚙',   'Processes',  'top cpu / top mem / threads',   'heater-processes', procColor, c.pos(12, 11, 12, 4));

// ── Dashboard ────────────────────────────────────────────────────────────────

g.dashboard.new('Heater — Home')
+ g.dashboard.withUid('heater-home')
+ g.dashboard.withDescription('Heater developer workstation — health summary and navigation to System, GPU, JVM, Claude Code, and Processes dashboards.')
+ g.dashboard.withTags(['heater', 'home', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  headerPanel,
  c.externalLinksPanel(y=0, x=22),

  // Health stats row — one KPI per subsystem
  g.panel.row.new('Health') + c.pos(0, 2, 24, 0),
  cpuStat, memStat, gpuStat, heapStat, claudeCostStat,

  // Navigation cards
  g.panel.row.new('Dashboards') + c.pos(0, 6, 24, 1),
  systemCard, gpuCard, jvmCard, claudeCard, processCard,
])
