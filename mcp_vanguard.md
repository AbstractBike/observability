# mcp_vanguard — Observability Reference

## Service Overview

MCP stdio server that routes prompts to Claude Haiku via the Anthropic Messages API.
Exposes a single `fast_model` tool for lightweight sub-tasks (summarization, classification, Q&A).

## Endpoints

| Signal | Endpoint | Format |
|--------|----------|--------|
| Metrics | `http://<host>:9196/metrics` | Prometheus |
| Traces | SkyWalking OAP `192.168.0.4:11800` | gRPC (SW8) |
| Logs | stderr → Vector → VictoriaLogs | JSON |

Configure tracing: `SW_OAP_SERVER=192.168.0.4:11800`

## Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `mcp_vanguard_requests_total` | counter | `tool`, `status` | Total tool calls (status: `ok` or `error`) |
| `mcp_vanguard_request_duration_seconds` | histogram | `tool` | End-to-end duration per call |
| `mcp_vanguard_anthropic_tokens_total` | counter | `type`, `model` | Tokens consumed (`type`: `input`/`output`) |

## Logs

Structured JSON to stderr (forwarded by Vector).

Required fields: `service=mcp_vanguard`, `level`, `host`.

Key log events:
- `mcp_vanguard starting` — service startup
- `fast_model call succeeded` — includes `model`, `input_tokens`, `output_tokens`, `duration_s`
- `fast_model call failed` — includes `error`, `duration_s`
- `SkyWalking OAP unreachable` — tracing graceful degradation
- `metrics port unavailable` — metrics graceful degradation

## Traces

SkyWalking native gRPC (`skywalking 0.10`). Entry span per tool call:
- Span name: `tools/call/fast_model`
- Tags: `mcp.tool`, `mcp.protocol`, `mcp.status`, `mcp.error` (on failure)

Graceful degradation: if OAP unreachable at startup, all span calls are no-ops.

## Dashboard

`dashboards-src/services/mcp-vanguard.jsonnet`

Panels:
- Requests (1h), Success Rate (15m), Tokens Consumed (1h)
- Request Rate by Status (time series)
- Latency p50/p95/p99 (time series)
- Anthropic Tokens/min by type+model (time series)
- Error Rate % (time series)
- Logs panel
- Troubleshooting guide

## Configuration

```toml
[anthropic]
api_key_file = "~/.config/anthropic/api_key"
model = "claude-haiku-4-5-20251001"
max_tokens = 4096
timeout_seconds = 30
system_prompt = ""

[observability]
metrics_port = 9196
log_level = "warn"
```

Environment:
- `MCP_VANGUARD_CONFIG` — path to config file
- `ANTHROPIC_API_KEY` — API key fallback
- `SW_OAP_SERVER` — SkyWalking OAP endpoint (e.g. `192.168.0.4:11800`)
- `RUST_LOG` — log level override
