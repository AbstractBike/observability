# Claude Overview Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge all active Claude dashboards (metrics.json + claude-proxy + dropped no-data chat dashboards) into a single flat Jsonnet dashboard at `dashboards-src/claude/overview.jsonnet`.

**Architecture:** New Jsonnet file following `heater/claude-code.jsonnet` conventions — stats row, time series, charts, table, collapsed log rows. Old JSON files deleted. Home nav card updated.

**Tech Stack:** Jsonnet (grafonnet v11.4), VictoriaMetrics (MetricsQL), VictoriaLogs (LogsQL), validate.sh for syntax check.

**Spec:** `docs/superpowers/specs/2026-03-21-claude-overview-dashboard-design.md`

---

## File Map

| Action | File |
|---|---|
| **Modify** | `nix/dashboards.nix` (add claude Jsonnet compile loop) |
| **Create** | `dashboards-src/claude/overview.jsonnet` |
| **Delete** | `dashboards-src/claude/metrics.json` |
| **Delete** | `dashboards-src/claude/chat-overview.json` |
| **Delete** | `dashboards-src/claude/chat-agent-detail.json` |
| **Delete** | `dashboards-src/claude/chat-correlation.json` |
| **Delete** | `dashboards-src/claude/chat-inter-agent.json` |
| **Delete** | `dashboards_new/claude-proxy-dashboard.json` |
| **Modify** | `dashboards-src/overview/home.jsonnet` (1 line: claudeProxyCard URL) |

---

## Task 0: Add `claude/*.jsonnet` compilation loop to `nix/dashboards.nix`

**File:** Modify `nix/dashboards.nix`

Currently `nix/dashboards.nix` only copies `.json` files from `claude/` (line 109). Without a compile loop, `overview.jsonnet` will be silently skipped during `nix build`.

- [ ] **Step 1: Add the compile loop after line 109**

In `nix/dashboards.nix`, find:
```nix
  mkdir -p $out/claude
  cp ${observabilityDashboardsPath}/claude/*.json "$out/claude/" 2>/dev/null || true
```

Replace with:
```nix
  mkdir -p $out/claude

  for f in ${observabilityDashboardsPath}/claude/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling claude/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/claude/$name.json"
  done

  cp ${observabilityDashboardsPath}/claude/*.json "$out/claude/" 2>/dev/null || true
```

- [ ] **Step 2: Commit**

```bash
cd /arch/repos/observability
git add nix/dashboards.nix
git commit -m "fix(dashboards): add claude/*.jsonnet compile loop to dashboards.nix"
```

---

## Task 1: Create `dashboards-src/claude/overview.jsonnet`

**File:** Create `dashboards-src/claude/overview.jsonnet`

The dashboard has 5 sections (flat, no rows except collapsed log rows at the bottom):
1. Stats — 8 panels × width 3 = 24 columns at y=0
2. Time series — 9 panels × width 12, pairs, starting at y=3
3. Charts — 3 panels × width 8 = 24 at y=43
4. Table — 1 panel width 24 at y=51
5. Collapsed log rows at y=59, 60, 61

**Conventions from `heater/claude-code.jsonnet`:**
- `c.vmQ(expr, legend='')` — VictoriaMetrics query with datasource var
- `c.vlogsQ(expr)` — VictoriaLogs query
- `c.pos(x, y, w, h)` — panel position
- `c.vmDsVar`, `c.vlogsDsVar` — datasource variables (do NOT add `c.swDsVar`)
- `c.percentThresholds`, `c.latencyThresholds` — reusable threshold sets
- `c.dashboardDefaults` — refresh, timezone, time range defaults
- `c.serviceLogsPanel(title, service, y, host)` — logs panel helper

- [ ] **Step 1: Write `overview.jsonnet`**

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Claude — Overview
// Merged from: claude/metrics.json, dashboards_new/claude-proxy-dashboard.json
// Dropped (0 series): claude/chat-*.json (claude_chat_* not deployed), SkyWalking traces
// Logs: heater-scoped — Claude Code runs exclusively on the heater machine

local projectVar =
  g.dashboard.variable.query.new('project')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'project', 'claude_session_cost_usd'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Project')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*');

local modelVar =
  g.dashboard.variable.query.new('model')
  + g.dashboard.variable.query.queryTypes.withLabelValues(
      'model', 'claude_tokens_input_total'
    )
  + g.dashboard.variable.query.generalOptions.withLabel('Model')
  + g.dashboard.variable.query.selectionOptions.withMulti(true)
  + g.dashboard.variable.query.selectionOptions.withIncludeAll(true, '.*');

// ── Stats (8 × width 3 = 24 columns, y=0, h=3) ──────────────────────────────

local sessionCostStat =
  g.panel.stat.new('Session Cost')
  + c.pos(0, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_session_cost_usd{project=~"$project",model=~"$model"}) or vector(0)'),
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

local contextUsedStat =
  g.panel.stat.new('Context Used %')
  + c.pos(3, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(claude_context_used_pct{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local totalTokensStat =
  g.panel.stat.new('Tokens (in+out)')
  + c.pos(6, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + sum(claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local cacheHitStat =
  g.panel.stat.new('Cache Hit %')
  + c.pos(9, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_tokens_cache_read{project=~"$project",model=~"$model"}) / (sum(claude_tokens_cache_read{project=~"$project",model=~"$model"}) + sum(claude_tokens_input_total{project=~"$project",model=~"$model"}) + 1) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 30 },
    { color: 'green', value: 60 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local linesNetStat =
  g.panel.stat.new('Lines +/-')
  + c.pos(12, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', 'added'),
    c.vmQ('sum(claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', 'removed'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local apiWaitStat =
  g.panel.stat.new('API Wait (avg)')
  + c.pos(15, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(claude_duration_api_seconds{project=~"$project",model=~"$model"}) / sum(claude_prompt_count{project=~"$project",model=~"$model"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 10 },
    { color: 'red', value: 30 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local proxyTokensInStat =
  g.panel.stat.new('Proxy Tokens In')
  + c.pos(18, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(increase(claude_proxy_tokens_input_total[$__range])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local proxyLatencyStat =
  g.panel.stat.new('Proxy Latency')
  + c.pos(21, 0, 3, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('avg(claude_proxy_duration_ms) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + c.latencyThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

// ── Time series (pairs of 12, starting y=3) ──────────────────────────────────
// Raw counters are intentional — shows cumulative usage trends (same as heater/claude-code.jsonnet)

local tokensTs =
  g.panel.timeSeries.new('Token Usage (Input vs Output)')
  + c.pos(0, 3, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_input_total{project=~"$project",model=~"$model"}) or vector(0)', 'input {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', 'output {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cacheTs =
  g.panel.timeSeries.new('Cache Tokens (Read vs Write)')
  + c.pos(12, 3, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_cache_read{project=~"$project",model=~"$model"}) or vector(0)', 'read {{project}}'),
    c.vmQ('sum by (project) (claude_tokens_cache_write{project=~"$project",model=~"$model"}) or vector(0)', 'write {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local costByProjectTs =
  g.panel.timeSeries.new('Cost by Project')
  + c.pos(0, 11, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_session_cost_usd{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tokensByProjectTs =
  g.panel.timeSeries.new('Tokens by Project')
  + c.pos(12, 11, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_tokens_input_total{project=~"$project",model=~"$model"} + claude_tokens_output_total{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local apiDurationTs =
  g.panel.timeSeries.new('API Duration over Time')
  + c.pos(0, 19, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_duration_api_seconds{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local contextTs =
  g.panel.timeSeries.new('Context Window Usage')
  + c.pos(12, 19, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('max by (project) (claude_context_used_pct{project=~"$project",model=~"$model"}) or vector(0)', '{{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + c.percentThresholds
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local linesTs =
  g.panel.timeSeries.new('Lines Added / Removed')
  + c.pos(0, 27, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (project) (claude_lines_added{project=~"$project",model=~"$model"}) or vector(0)', '+added {{project}}'),
    c.vmQ('-sum by (project) (claude_lines_removed{project=~"$project",model=~"$model"}) or vector(0)', '-removed {{project}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local proxyTokensTs =
  g.panel.timeSeries.new('Proxy Token Usage by Model')
  + c.pos(12, 27, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (model) (rate(claude_proxy_tokens_input_total[5m])) or vector(0)', 'in {{model}}'),
    c.vmQ('sum by (model) (rate(claude_proxy_tokens_output_total[5m])) or vector(0)', 'out {{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local proxyLatencyTs =
  g.panel.timeSeries.new('Proxy Latency by Model')
  + c.pos(0, 35, 24, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('avg by (model) (claude_proxy_duration_ms) or vector(0)', '{{model}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Charts (3 × width 8 = 24, y=43) ─────────────────────────────────────────

local tokensByModelPie =
  g.panel.pieChart.new('Tokens by Model')
  + c.pos(0, 43, 8, 8)
  + g.panel.pieChart.queryOptions.withTargets([
    c.vmQ('sum by (model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range]) + last_over_time(claude_tokens_output_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{model}}'),
  ])
  + g.panel.pieChart.options.withPieType('donut')
  + g.panel.pieChart.options.withDisplayLabels(['name', 'percent']);

local costByModelBar =
  g.panel.barChart.new('Cost by Model')
  + c.pos(8, 43, 8, 8)
  + g.panel.barChart.queryOptions.withTargets([
    c.vmQ('sum by (model) (last_over_time(claude_session_cost_usd{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{model}}'),
  ])
  + g.panel.barChart.standardOptions.withUnit('currencyUSD');

local modelShareBar =
  g.panel.barChart.new('Model Share % by Project')
  + c.pos(16, 43, 8, 8)
  + g.panel.barChart.queryOptions.withTargets([
    c.vmQ('sum by (project, model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{project}} / {{model}}'),
  ])
  + g.panel.barChart.standardOptions.withUnit('short');

// ── Table (full width, y=51) ─────────────────────────────────────────────────

local tokenBreakdownTable =
  g.panel.table.new('Token Breakdown: Project × Model')
  + c.pos(0, 51, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('sum by (project, model) (last_over_time(claude_tokens_input_total{project=~"$project",model=~"$model"}[$__range]) + last_over_time(claude_tokens_output_total{project=~"$project",model=~"$model"}[$__range])) or vector(0)', '{{project}} / {{model}}'),
  ])
  + g.panel.table.standardOptions.withUnit('short');

// ── Logs (heater-scoped, collapsed) ─────────────────────────────────────────

local sessionLogsPanel =
  c.serviceLogsPanel('Session Logs (claude-code)', 'claude-code', host='heater', y=0);

local debugLogsPanel =
  g.panel.logs.new('Debug Logs (claude-code-debug)')
  + c.pos(0, 10, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="claude-code-debug"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local trafficLogsPanel =
  g.panel.logs.new('HTTP Traffic (mitmproxy)')
  + c.pos(0, 20, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="heater",service="mitmproxy-claude"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard ────────────────────────────────────────────────────────────────

g.dashboard.new('Claude — Overview')
+ g.dashboard.withUid('claude-overview')
+ g.dashboard.withDescription('Merged Claude observability: tokens, cost, cache, context, lines, proxy metrics, heater-scoped logs. Absorbed from metrics.json + claude-proxy-dashboard.')
+ g.dashboard.withTags(['claude', 'ai', 'overview'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, projectVar, modelVar])
+ g.dashboard.withPanels([
  // Stats
  sessionCostStat, contextUsedStat, totalTokensStat, cacheHitStat,
  linesNetStat, apiWaitStat, proxyTokensInStat, proxyLatencyStat,
  // Time series
  tokensTs, cacheTs,
  costByProjectTs, tokensByProjectTs,
  apiDurationTs, contextTs,
  linesTs, proxyTokensTs,
  proxyLatencyTs,
  // Charts
  tokensByModelPie, costByModelBar, modelShareBar,
  // Table
  tokenBreakdownTable,
  // Collapsed log rows (y=59, 60, 61)
  (g.panel.row.new('Session Logs') + c.pos(0, 59, 24, 1) + { collapsed: true, panels: [sessionLogsPanel] }),
  (g.panel.row.new('Debug Logs')   + c.pos(0, 60, 24, 1) + { collapsed: true, panels: [debugLogsPanel] }),
  (g.panel.row.new('HTTP Traffic') + c.pos(0, 61, 24, 1) + { collapsed: true, panels: [trafficLogsPanel] }),
])
```

- [ ] **Step 2: Validate syntax**

```bash
cd /arch/repos/observability
./validate.sh dashboards-src/claude/overview.jsonnet
```

Expected output:
```
  ✓ dashboards-src/claude/overview.jsonnet
Results: 1 OK, 0 FAILED
```

If it fails, read the error message carefully — it will point to the exact line. Common issues: mismatched braces, missing `+`, wrong function name.

- [ ] **Step 3: Commit**

```bash
cd /arch/repos/observability
git add dashboards-src/claude/overview.jsonnet
git commit -m "feat(claude): add overview.jsonnet — merged metrics + proxy into single flat dashboard"
```

---

## Task 2: Delete old dashboard files

**Files:** Delete `dashboards-src/claude/metrics.json`, `chat-*.json`, and `dashboards_new/claude-proxy-dashboard.json`

- [ ] **Step 1: Delete the files**

```bash
cd /arch/repos/observability
rm dashboards-src/claude/metrics.json
rm dashboards-src/claude/chat-overview.json
rm dashboards-src/claude/chat-agent-detail.json
rm dashboards-src/claude/chat-correlation.json
rm dashboards-src/claude/chat-inter-agent.json
rm dashboards_new/claude-proxy-dashboard.json
```

- [ ] **Step 2: Verify no other dashboard references the deleted UIDs**

```bash
grep -r "claude-metrics-v1\|claude-chat-overview\|claude-chat-agent-detail\|claude-chat-correlation\|claude-chat-inter-agent\|claude-proxy" \
  /arch/repos/observability/dashboards-src/ 2>/dev/null
```

Expected output: no matches (the home.jsonnet reference to `/d/claude-proxy` will be fixed in Task 3).

- [ ] **Step 3: Run full validation to confirm no other jsonnet broke**

```bash
cd /arch/repos/observability
./validate.sh
```

Expected: `Results: N OK, 0 FAILED`

- [ ] **Step 4: Commit**

```bash
cd /arch/repos/observability
git add -A dashboards-src/claude/ dashboards_new/claude-proxy-dashboard.json
git commit -m "chore(claude): delete merged/no-data dashboards — metrics.json, chat-*.json, claude-proxy-dashboard.json"
```

---

## Task 3: Update home.jsonnet nav card

**File:** Modify `dashboards-src/overview/home.jsonnet` — change `claudeProxyCard` URL from `/d/claude-proxy` to `/d/claude-overview`.

- [ ] **Step 1: Find and update the line**

In `dashboards-src/overview/home.jsonnet`, find:
```jsonnet
local claudeProxyCard  = navCard('Claude Proxy', 'API proxy metrics', '/d/claude-proxy')       + c.pos(0,  22, 12, 3);
```

Replace with:
```jsonnet
local claudeProxyCard  = navCard('Claude Overview', 'Tokens, cost, cache, proxy', '/d/claude-overview') + c.pos(0,  22, 12, 3);
```

- [ ] **Step 2: Validate**

```bash
cd /arch/repos/observability
./validate.sh dashboards-src/overview/home.jsonnet
```

Expected: `Results: 1 OK, 0 FAILED`

- [ ] **Step 3: Commit**

```bash
cd /arch/repos/observability
git add dashboards-src/overview/home.jsonnet
git commit -m "fix(home): update Claude nav card to point to new overview dashboard"
```

---

## Task 4: Push and deploy

- [ ] **Step 1: Push to main and staging**

```bash
cd /arch/repos/observability
git push origin main
git push origin main:staging
```

- [ ] **Step 2: Update flake.lock in home-nixos-1**

```bash
cd /arch/machines/home-nixos-1
nix flake update observability
```

- [ ] **Step 3: Deploy**

```bash
fish -c "deploy apply hn1"
```

Expected: `[deploy] Deploy completed.`

If it fails with exit code 4 (scalable-explorer pre-existing failure), the deploy still succeeded — push origin/main manually:
```bash
cd /arch/machines/home-nixos-1
git add flake.lock
git commit -m "chore: bump observability — claude-overview merged dashboard"
git push origin main
```

- [ ] **Step 4: Verify in Grafana**

Open `https://abstract.bike/d/claude-overview` and confirm:
- 8 stat panels visible across top
- Time series panels show data (not empty)
- Collapsed log rows visible at bottom
- Home nav card "Claude Overview" links correctly
