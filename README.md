# Observability Registry

> **Last updated:** 2026-03-04
> **Stack version:** VictoriaMetrics + VictoriaLogs + SkyWalking OAP 10.3 + Grafana

This directory is the canonical reference for the homelab observability stack.
When you don't know **where to send metrics/logs/traces** from a new service, read this file first.

---

## Quick Reference — Ingestion Endpoints

| Signal  | Protocol         | Endpoint                                  | Notes                              |
|---------|-----------------|-------------------------------------------|------------------------------------|
| Metrics | Prometheus remote_write | `http://192.168.0.4:8428/api/v1/write` | Add labels: service, host, env     |
| Metrics | PromText scrape  | Expose `/metrics` on any port → add target in `victoriametrics.nix` | VictoriaMetrics pulls every 30s |
| Logs    | NDJSON HTTP POST | `http://192.168.0.4:9428/insert/jsonline` | Fields: `_msg`, `_time`, `service`, `level`, `host`, `trace_id` |
| Traces  | gRPC (SW8)       | `192.168.0.4:11800`                        | SkyWalking OAP                     |
| Traces  | HTTP REST (SW8)  | `http://192.168.0.4:12800`                 | SkyWalking OAP REST/GraphQL        |

> Vector on `homelab` (192.168.0.4) is the aggregation hub. For a service on `heater` (192.168.0.3),
> target the homelab IP directly — it is reachable over the LAN.

---

## Decision Tree — New Service Instrumentation

```
New service needs observability?
│
├─► Already have a Vector pipeline for its host?
│       YES → Use existing Vector sources/sinks (see sinks.md)
│       NO  → Check if a new Vector source is needed, add it to modules/vector.nix
│
├─► Language with a native agent?
│       Java   → Use SkyWalking Java Agent (see agents.md)
│       Python → Use apache-skywalking Python agent
│       Go     → Use go2sky library
│       Any    → SkyWalking Rover eBPF (zero code changes, see agents.md)
│       Other  → OTLP → SkyWalking OAP at 192.168.0.4:11800
│
└─► Expose /metrics or push?
        Scrape  → Expose Prometheus format, add scrape target in modules/victoriametrics.nix
        Push    → Remote write to http://192.168.0.4:8428/api/v1/write
```

---

## Files in This Directory

| File            | Contents                                                  |
|-----------------|----------------------------------------------------------|
| `README.md`     | This file — quick reference & decision tree              |
| `sinks.md`      | All ingestion sinks: endpoints, formats, configuration   |
| `agents.md`     | Instrumentation agents per language with config examples |
| `pipeline.md`   | Vector pipeline map: sources → transforms → sinks        |
| `services.md`   | Per-service observability status registry                |

---

## Stack Overview

```
         heater (192.168.0.3)              homelab (192.168.0.4)
         ┌─────────────────────┐          ┌──────────────────────────────────┐
         │  Claude Code CLI    │          │  Vector (journald + host metrics) │
         │  Nginx MITM Proxy   │──────►   │  ───────────────────────────────  │
         │  (api.anthropic.com)│          │  VictoriaMetrics  :8428           │
         │  Vector (host)      │──────►   │  VictoriaLogs     :9428           │
         └─────────────────────┘          │  SkyWalking OAP   :11800/:12800   │
                                          │  Grafana          :3001           │
         Services (any host)              │  VMAlert          :8880           │
         ┌─────────────────────┐          │  Alertmanager     :9093           │
         │  /metrics endpoint  │──scrape► │  Exporters: pg:9187 redis:9121   │
         │  OTLP / SW8 traces  │──────►   │  elasticsearch:9114               │
         │  Structured JSON log│──────►   └──────────────────────────────────┘
         └─────────────────────┘
```

## Grafana — http://192.168.0.4:3000

Datasources available:
- **VictoriaMetrics** (default) — MetricsQL
- **VictoriaLogs** — LogsQL, UI at http://192.168.0.4:9428/vmui
- **SkyWalking** (native plugin) — traces, service topology
- **SkyWalking-PromQL** — OAP metrics via PromQL at :9090
- **ClickHouse**, **PostgreSQL**, **Elasticsearch**, **Kafka** (Redpanda)

Dashboard sources (Jsonnet): `~/git/homelab/dashboards-src/`
One dashboard per service minimum.

## Mandatory Correlation Fields

Every signal (metrics labels, log fields, trace tags) MUST include:

| Field     | Value                                 |
|-----------|---------------------------------------|
| `service` | Same name across all three signals    |
| `host`    | Hostname (`homelab` / `heater`)       |
| `trace_id`| SW8 trace ID — enables log↔trace link |
| `env`     | `prod` / `dev`                        |
