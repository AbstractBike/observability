# Observability Sinks Reference

All active ingestion endpoints in the homelab stack.

---

## Metrics Sinks

### VictoriaMetrics — Primary Metrics Store

**Endpoint:** `http://192.168.0.4:8428`

| Method | URL | Format | Use When |
|--------|-----|--------|----------|
| Push | `/api/v1/write` | Prometheus remote_write (protobuf) | Service pushes metrics |
| Push | `/api/v1/import/prometheus` | Prometheus text | Simple curl-based push |
| Scrape | Via `victoriametrics.nix` scrape config | Prometheus text at `/metrics` | Service exposes /metrics |

**Required labels on every metric:**
```
service="<app-name>"
host="homelab|heater"
env="prod|dev"
```

**Current scrape targets** (add new ones in `modules/victoriametrics.nix`):

| Target | Address | Scrape Interval |
|--------|---------|----------------|
| serena-mcp | 192.168.0.3:24227 | 30s |
| arbitraje | 192.168.0.3:8081/actuator/prometheus | 15s |
| postgres-exporter | 127.0.0.1:9187 | 30s |
| redis-exporter | 127.0.0.1:9121 | 30s |
| elasticsearch-exporter | 127.0.0.1:9114 | 30s |
| clickhouse | 127.0.0.1:9363 | 30s |
| redpanda | 127.0.0.1:9644 | 30s |
| temporal | 127.0.0.1:8000 | 30s |
| skywalking-oap | 127.0.0.1:1234 | 30s |
| victoriametrics-self | 127.0.0.1:8428 | 30s |
| alertmanager | 127.0.0.1:9093 | 30s |
| vmalert | 127.0.0.1:8880 | 30s |
| grafana | 127.0.0.1:3001 | 30s |
| victorialogs | 127.0.0.1:9428 | 30s |

**Adding a new scrape target:**
```nix
# modules/victoriametrics.nix — in scrapeConfigs
{
  job_name = "my-service";
  static_configs = [{ targets = ["127.0.0.1:PORT"]; }];
  # Optional: scrape_interval = "15s";
}
```

---

## Log Sinks

### VictoriaLogs — Primary Log Store

**Endpoint:** `http://192.168.0.4:9428`
**UI:** `http://192.168.0.4:9428/vmui`

| Method | URL | Format |
|--------|-----|--------|
| Push | `/insert/jsonline` | NDJSON (one JSON object per line) |

**Required fields in every log entry:**
```json
{
  "_msg": "Log message text",
  "_time": "2026-03-04T12:00:00Z",
  "service": "my-service",
  "level": "info|warn|error|debug",
  "host": "homelab|heater",
  "trace_id": "abc123...",
  "env": "prod"
}
```

**Via Vector (recommended):**
Add a new source in `modules/vector.nix`:
```toml
[sources.my_service_logs]
type = "file"
include = ["/var/log/my-service/*.log"]

[sinks.my_service_to_vlogs]
type = "http"
inputs = ["my_service_logs"]
uri = "http://127.0.0.1:9428/insert/jsonline"
encoding.codec = "ndjson"
```

**Direct HTTP push example (curl):**
```bash
curl -X POST http://192.168.0.4:9428/insert/jsonline \
  -H 'Content-Type: application/stream+json' \
  --data-raw '{"_msg":"service started","_time":"2026-03-04T12:00:00Z","service":"my-service","level":"info","host":"homelab","trace_id":""}'
```

**Querying (LogsQL):**
```
service:"my-service" AND level:"error"
service:"my-service" AND trace_id:"abc123"
```

---

## Trace Sinks

### SkyWalking OAP — Primary Tracing Backend

**gRPC (agent instrumentation):** `192.168.0.4:11800`
**HTTP/REST/GraphQL (Grafana, queries):** `http://192.168.0.4:12800`
**PromQL (Grafana SkyWalking-PromQL datasource):** `http://127.0.0.1:9090` (localhost only)

**Storage:** BanyanDB (at 127.0.0.1:17912)
**UI:** `http://192.168.0.4:8079` (service topology + trace detail)
**Data TTL:** 7 days

**OTLP → SkyWalking:**
SkyWalking OAP accepts OTLP over gRPC at port 11800.
Send OTLP traces pointing to `grpc://192.168.0.4:11800`.

---

## Vector HTTP Sources (Claude Analytics)

These ports are Vector HTTP server sources used by the Claude MITM proxy.
Do not use these for general-purpose ingestion.

| Port | Purpose | Source |
|------|---------|--------|
| :9192 | Claude Code event log | Nginx /api/event_logging/batch |
| :9193 | Segment.io events | Nginx /v1/batch |
| :9194 | Datadog log batches | Nginx /api/v2/logs |
| :9195 | Claude /v1/messages SSE | Nginx body_filter Lua tap |

---

## Alerting

### VMAlert — Rule Evaluation
**Endpoint:** `http://192.168.0.4:8880`
**Rule files:** `modules/alerts/*.yaml`
**Evaluation interval:** 30s

### Alertmanager — Notification Routing
**Endpoint:** `http://192.168.0.4:9093`
**Default receiver:** Telegram
**Inhibition:** critical suppresses matching warnings
