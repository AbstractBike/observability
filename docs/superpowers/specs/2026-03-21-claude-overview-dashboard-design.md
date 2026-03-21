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
- SkyWalking/MCP traces — 0 traces in Tempo → drop MCP P95 and all traces panels

## Output

**File:** `dashboards-src/claude/overview.jsonnet`
**UID:** `claude-overview`
**Title:** `Claude — Overview`
**Written in:** Jsonnet (following `heater/claude-code.jsonnet` conventions)

## Layout (flat, grouped by panel type — no rows)

### 1. Stats (top, full width)
10 stat panels across:

| Panel | Query | Width |
|---|---|---|
| Session Cost | `sum(increase(claude_session_cost_usd[$__range]))` | 2 |
| Context Used % | `avg(claude_context_used_pct)` | 2 |
| Tokens (in+out) | `sum(increase(claude_tokens_input_total[$__range] + claude_tokens_output_total[$__range]))` | 2 |
| Cache Hit % | `sum(increase(claude_tokens_cache_read[$__range])) / clamp_min(sum(...cache_read+cache_write...),1) * 100` | 2 |
| Lines +/- | `sum(increase(claude_lines_added[$__range])) - sum(increase(claude_lines_removed[$__range]))` | 2 |
| API Wait avg | `sum(increase(claude_duration_api_seconds[$__range])) / clamp_min(sum(increase(claude_prompt_count[$__range])),1)` | 2 |
| Prompts | `sum(increase(claude_prompt_count[$__range]))` | 2 |
| Proxy Tokens In | `sum(increase(claude_proxy_tokens_input_total[$__range]))` | 2 |
| Proxy Tokens Out | `sum(increase(claude_proxy_tokens_output_total[$__range]))` | 2 |
| Proxy Latency | `avg(claude_proxy_duration_ms)` in ms | 2 |

Total width: 10 × 2 = 20 columns (uses standard 24-column grid, centered or padded)

### 2. Time Series (middle)
In order, each 12 wide except where noted:

| Panel | Query | Width |
|---|---|---|
| Token Usage (in vs out) | `sum(claude_tokens_input_total)` + `sum(claude_tokens_output_total)` | 12 |
| Cache Tokens (read/write) | `sum(claude_tokens_cache_read)` + `sum(claude_tokens_cache_write)` | 12 |
| Cost by Project | `sum by (project) (claude_session_cost_usd)` | 12 |
| Tokens by Project | `sum by (project) (claude_tokens_input_total + claude_tokens_output_total)` | 12 |
| API Duration over time | `sum(claude_duration_api_seconds)` | 12 |
| Context Usage % | `avg(claude_context_used_pct)` | 12 |
| Lines Added/Removed | `sum(claude_lines_added)` + `sum(claude_lines_removed)` | 12 |
| Proxy Token Usage by Model | `sum by (model) (rate(claude_proxy_tokens_input_total[5m]))` + output | 12 |
| Proxy Latency by Model | `avg by (model) (claude_proxy_duration_ms)` | 12 |

### 3. Charts (below time series)

| Panel | Type | Query | Width |
|---|---|---|---|
| Tokens by Model | piechart | `sum by (model) (last_over_time(claude_tokens_input_total[$__range]) + last_over_time(claude_tokens_output_total[$__range]))` | 8 |
| Cost by Model | barchart | `sum by (model) (last_over_time(claude_session_cost_usd[$__range]))` | 8 |
| Model Share % by Project | barchart | `sum by (project, model) (last_over_time(claude_tokens_input_total[$__range]))` | 8 |

### 4. Table

| Panel | Type | Query | Width |
|---|---|---|---|
| Token Breakdown: Project × Model | table | `sum by (project, model) (last_over_time(claude_tokens_input_total[$__range] + last_over_time(claude_tokens_output_total[$__range])))` | 24 |

### 5. Logs (bottom)
Reused from `heater/claude-code.jsonnet` (same queries, same datasource):

| Panel | Width |
|---|---|
| Session Logs | 24 |
| Debug Logs | 24 |
| HTTP Traffic | 24 |

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

- Import: `grafonnet-lib` via `import 'grafonnet/grafana.libsonnet'` pattern
- Datasource variable: `$datasource` for VictoriaMetrics, `$logs` for VictoriaLogs
- Positioning: `c.pos(x, y, w, h)` from local helper
- Stat panels: `g.panel.stat.new(...)` with background color mode for KPIs
- Time series: `g.panel.timeSeries.new(...)` with legend bottom
- Logs: `g.panel.logs.new(...)` with VictoriaLogs datasource UID `victorialogs`
