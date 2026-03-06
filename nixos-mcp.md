# nixos-mcp Observability

Service: `nixos-mcp` — Rust MCP server exposing NixOS tools over HTTP/SSE at port 9120.

## Endpoints

| Signal   | Endpoint                        | Format     |
|----------|---------------------------------|------------|
| Metrics  | `http://192.168.0.4:9122/metrics` | Prometheus |
| Logs     | journald → VictoriaLogs          | JSON       |
| Traces   | Not instrumented (no SkyWalking) | —          |

## Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `nixos_mcp_tool_calls_total` | Counter | `tool`, `status` | Tool call count by outcome (`success`/`failed`/`timeout`) |
| `nixos_mcp_tool_duration_seconds` | Histogram | `tool` | Per-tool execution duration |

**Labels on all metrics:** `service=nixos-mcp`

## Logs

Structured JSON via `tracing-subscriber` → journald → VictoriaLogs.

Required fields:
- `service` = `nixos-mcp`
- `level` = `INFO`/`WARN`/`ERROR`
- `timestamp` (RFC3339)

Key log events:
- `status=starting` — service boot
- `MCP server listening` — ready on port 9120
- `metrics server listening` — ready on port 9122
- `create new session` — MCP client connected

## Alerts

File: `modules/alerts/nixos-mcp.yaml`

| Alert | Severity | Condition |
|-------|----------|-----------|
| `NixosMcpDown` | warning | No `nixos_mcp_tool_calls_total` for 5m |
| `NixosMcpDeployFailing` | warning | Any `nixos_deploy` failures in 30m |
| `NixosMcpHighErrorRate` | critical | Error rate > 50% for 5m |

## Dashboard

Grafana UID: `services-nixos-mcp`
Source: `observability/dashboards-src/services/nixos-mcp.jsonnet`

Panels:
- Tool Calls (1h) — stat
- Success Rate (15m) — stat with thresholds (green >99%, yellow >90%)
- Active Connections — stat
- Tool Calls by Tool and Status — timeseries
- Tool Duration p95 — timeseries
- Logs — VictoriaLogs tail
- Troubleshooting guide

## Vector Pipeline

Logs are collected by Vector from journald (`_SYSTEMD_UNIT=nixos-mcp.service`) and forwarded to VictoriaLogs with `service=nixos-mcp` tag.

Metrics from `:9122/metrics` are scraped by VictoriaMetrics via the `prometheus_scrape` source in `modules/victoriametrics.nix`.
