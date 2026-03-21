# Claude Overview Dashboard — Design Spec

**Date:** 2026-03-21
**Status:** Approved

## Goal

Merge all active Claude dashboards into a single flat Jsonnet dashboard (`claude/overview.jsonnet`).
`heater/claude-code.jsonnet` is kept as-is; this spec covers the other dashboards only.

## Data Availability (verified against live VictoriaMetrics)

### Has data — include
- `claude_tokens_input_total`, `claude_tokens_output_total` (labels: model, project, session)
- `claude_tokens_cache_read`, `claude_tokens_cache_write`
- `claude_session_cost_usd` (labels: model, project, session)
- `claude_context_used_pct` (labels: model, project, session)
- `claude_lines_added`, `claude_lines_removed`
- `claude_prompt_count`, `claude_duration_api_seconds`
- `claude_proxy_tokens_input_total`, `claude_proxy_tokens_output_total` (labels: model)
- `claude_proxy_duration_ms` (labels: model)

### No data — drop panels
- `claude_proxy_requests_total` — 0 series → drop: Total Requests, Error Rate, Requests per Model, Errors by Status Code
- `claude_chat_*` — 0 series (entire chat subsystem not deployed) → drop all chat panels
- SkyWalking/MCP traces — 0 traces in Tempo → drop all traces panels

## Output

**File:** `dashboards-src/claude/overview.jsonnet`
**UID:** `claude-overview`
**Title:** `Claude — Overview`
**Written in:** Jsonnet (following `heater/claude-code.jsonnet` conventions)

## Layout (flat, grouped by panel type — no rows)

### 1. Stats (top, full width = 24 columns)

8 stat panels × width 3 = 24 columns. Starting positions: x = 0, 3, 6, 9, 12, 15, 18, 21. Row y = 0, height = 3.

| x  | Panel | Query | Unit |
|----|---|---|---|
| 0  | Session Cost | `sum(increase(claude_session_cost_usd[$__range]))` | currencyUSD |
| 3  | Context Used % | `avg(claude_context_used_pct)` | percent (0–100) |
| 6  | Tokens (in+out) | `sum(increase(claude_tokens_input_total[$__range])) + sum(increase(claude_tokens_output_total[$__range]))` | short |
| 9  | Cache Hit % | `sum(increase(claude_tokens_cache_read[$__range])) / clamp_min(sum(increase(claude_tokens_input_total[$__range])) + sum(increase(claude_tokens_cache_read[$__range])), 1) * 100` — matches reference formula in heater/claude-code.jsonnet | percent |
| 12 | Lines +/- | `sum(increase(claude_lines_added[$__range])) - sum(increase(claude_lines_removed[$__range]))` | short |
| 15 | API Wait avg | `sum(increase(claude_duration_api_seconds[$__range])) / clamp_min(sum(increase(claude_prompt_count[$__range])), 1)` | s |
| 18 | Proxy Tokens In | `sum(increase(claude_proxy_tokens_input_total[$__range]))` | short |
| 21 | Proxy Latency | `avg(claude_proxy_duration_ms)` | ms |

Note: "Prompts" and "Proxy Tokens Out" dropped to fit 8 × 3 = 24. Both are derivable from other panels.

### 2. Time Series (middle)

Raw counter queries are intentional — they show cumulative usage trends matching the convention in `heater/claude-code.jsonnet`. Each panel 12 wide, y starting at 3.

| Panel | Queries | Width |
|---|---|---|
| Token Usage (in vs out) | `sum(claude_tokens_input_total)`, `sum(claude_tokens_output_total)` | 12 |
| Cache Tokens (read/write) | `sum(claude_tokens_cache_read)`, `sum(claude_tokens_cache_write)` | 12 |
| Cost by Project | `sum by (project) (claude_session_cost_usd)` | 12 |
| Tokens by Project | `sum by (project) (claude_tokens_input_total + claude_tokens_output_total)` | 12 |
| API Duration over time | `sum(claude_duration_api_seconds)` | 12 |
| Context Usage % | `avg(claude_context_used_pct)` | 12 |
| Lines Added/Removed | `sum(claude_lines_added)`, `sum(claude_lines_removed)` | 12 |
| Proxy Token Usage by Model | `sum by (model) (rate(claude_proxy_tokens_input_total[5m]))`, `sum by (model) (rate(claude_proxy_tokens_output_total[5m]))` | 12 |
| Proxy Latency by Model | `avg by (model) (claude_proxy_duration_ms)` | 12 |

### 3. Charts (below time series, 8 wide each = 24)

| Panel | Type | Query | Width |
|---|---|---|---|
| Tokens by Model | piechart | `sum by (model) (last_over_time(claude_tokens_input_total[$__range]) + last_over_time(claude_tokens_output_total[$__range]))` | 8 |
| Cost by Model | barchart | `sum by (model) (last_over_time(claude_session_cost_usd[$__range]))` | 8 |
| Model Share % by Project | barchart | `sum by (project, model) (last_over_time(claude_tokens_input_total[$__range]))` | 8 |

### 4. Table (full width)

| Panel | Type | Query | Width |
|---|---|---|---|
| Token Breakdown: Project × Model | table | `sum by (project, model) (last_over_time(claude_tokens_input_total[$__range]) + last_over_time(claude_tokens_output_total[$__range]))` | 24 |

### 5. Logs (bottom, heater-only — intentional)

These logs are scoped to `host="heater"` because Claude Code runs exclusively on the heater machine. This is intentional — the dashboard is heater-scoped for Claude activity.

Queries follow `heater/claude-code.jsonnet` exactly:

| Panel | Filter | Width |
|---|---|---|
| Session Logs | `{host="heater", service="claude-code"}` via VictoriaLogs | 24 |
| Debug Logs | `{host="heater", service="claude-code"} \| json \| level="debug"` | 24 |
| HTTP Traffic | `{host="heater", service="claude-code"} \| json \| has_http=true` | 24 |

## Files Modified

### Created
- `dashboards-src/claude/overview.jsonnet`

### Deleted
- `dashboards-src/claude/metrics.json`
- `dashboards-src/claude/chat-overview.json`
- `dashboards-src/claude/chat-agent-detail.json`
- `dashboards-src/claude/chat-correlation.json`
- `dashboards-src/claude/chat-inter-agent.json`
- `dashboards_new/claude-proxy-dashboard.json`

### Modified
- `dashboards-src/overview/home.jsonnet` — `claudeProxyCard` URL updated from `/d/claude-proxy` to `/d/claude-overview`

## Conventions (from heater/claude-code.jsonnet)

- Import: grafonnet via `local g = import ...` and `local c = import 'common.libsonnet'`
- Datasource UIDs: `"victoriametrics"` for metrics, `"victorialogs"` for logs
- Dashboard variables: declare `$datasource` (VictoriaMetrics) and `$logs` (VictoriaLogs) only — do NOT declare `swDsVar` (SkyWalking), as all traces panels are dropped
- Positioning: `c.pos(x, y, w, h)` helper
- Stat panels: `g.panel.stat.new(...)` with `colorMode = "background"` for KPIs with thresholds, `colorMode = "value"` for neutral counters
- Time series: `g.panel.timeSeries.new(...)` with `legendDisplayMode = "table"`, `legendPlacement = "bottom"`
- Logs: `g.panel.logs.new(...)` with datasource uid `"victorialogs"`
