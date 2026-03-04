# Services Observability Registry

Status of observability instrumentation for every service in the homelab.

Legend: ✅ Done | ⚠️ Partial | ❌ Missing | N/A Not applicable

---

## Infrastructure Services (homelab VM — 192.168.0.4)

| Service | Metrics | Logs | Traces | Dashboard | Alerts |
|---------|---------|------|--------|-----------|--------|
| VictoriaMetrics | ✅ self-scrape :8428 | ✅ journald | N/A | ✅ overview/victoriametrics | ✅ VictoriaMetricsDown |
| VictoriaLogs | ✅ :9428 | ✅ journald | N/A | ✅ observability/logs | ⚠️ no alert |
| Grafana | ✅ :3001 | ✅ journald | N/A | N/A (is the dashboard) | ✅ GrafanaDown |
| VMAlert | ✅ :8880 | ✅ journald | N/A | ✅ observability/vmalert | N/A |
| Alertmanager | ✅ :9093 | ✅ journald | N/A | ✅ observability/alertmanager | ✅ AlertmanagerDown |
| Vector | ✅ internal_metrics | ✅ journald | N/A | ✅ pipeline/vector | ✅ VectorDown, VectorErrorRate |
| SkyWalking OAP | ✅ :1234 | ✅ journald | N/A (is the backend) | ✅ observability/skywalking | ⚠️ no alert |
| SkyWalking UI | N/A | ✅ journald | N/A | N/A | N/A |
| SkyWalking Rover | ❌ disabled | ✅ journald | ⚠️ disabled | N/A | N/A |

## Data Services

| Service | Metrics | Logs | Traces | Dashboard | Alerts |
|---------|---------|------|--------|-----------|--------|
| PostgreSQL | ✅ :9187 (exporter) | ✅ journald | ⚠️ no agent | ✅ services/postgresql | ✅ PostgreSQLDown, TooManyConnections, SLO |
| Redis | ✅ :9121 (exporter) | ✅ journald | N/A | ✅ services/redis | ✅ RedisDown, SLO |
| Elasticsearch | ✅ :9114 (exporter) | ✅ journald | N/A | ✅ services/elasticsearch | ✅ ElasticsearchDown |
| ClickHouse | ✅ :9363 (built-in) | ✅ journald | N/A | ✅ services/clickhouse | ✅ ClickHouseDown |
| Redpanda | ✅ :9644 (built-in) | ✅ journald | N/A | ✅ services/redpanda | ✅ RedpandaBrokerDown |
| Temporal | ✅ :8000 (built-in) | ✅ journald | ⚠️ no agent | ✅ services/temporal | ✅ TemporalDown |

## Application Services

| Service | Metrics | Logs | Traces | Dashboard | Alerts |
|---------|---------|------|--------|-----------|--------|
| arbitraje (Spring Boot) | ✅ :8081/actuator/prometheus | ✅ journald | ⚠️ SW agent disabled (JDK11 SIGSEGV) | ✅ pipeline/arbitraje | N/A |
| Serena MCP | ✅ :24226→:24227 (socat) | ✅ journald | N/A | ✅ overview/serena-mcp | N/A |
| nixos-deployer | ✅ :9110/metrics (Vector prometheus_scrape) | ✅ journald | N/A | ✅ services/nixos-deployer | ✅ NixosDeployFailed, NixosStagingLagHigh, NixosDeployerDown |

## Developer Host (heater — 192.168.0.3)

| Service | Metrics | Logs | Traces | Dashboard | Alerts |
|---------|---------|------|--------|-----------|--------|
| Claude Code CLI | ✅ session tokens (Vector JSONL) | ✅ Vector tails JSONL | N/A | ✅ claude/metrics | N/A |
| Claude API calls | ✅ SSE tap via Nginx (pin-si-hub) | N/A | N/A | ✅ claude-chat/* | N/A |
| Host (CPU/mem/disk) | ✅ host_metrics (Vector) | ✅ journald | N/A | ✅ heater/system | ✅ HostCPU, HostMemory, HostDisk, HostLoad |

---

## Adding a New Service

1. Pick instrumentation method from `agents.md`
2. Add metrics scrape target to `modules/victoriametrics.nix` (or configure push)
3. Logs ship automatically via Vector journald source (if systemd service)
4. Add trace agent pointing to `192.168.0.4:11800`
5. Create dashboard `dashboards-src/<folder>/<service>.jsonnet`
6. Add alerts in `modules/alerts/<domain>.yaml`
7. Add row to this table with current status
