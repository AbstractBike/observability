# nixos-deployer Observability

## Overview

**Service:** `nixos-deployer` (NixOS GitOps automation)
**Type:** Temporal workflow worker + Prometheus metrics
**Language:** Python 3.12
**Port:** `:9110` (Prometheus `/metrics`)

## Metrics

All metrics prefixed with `nixos_`:

### Counters

| Metric | Description | Labels |
|--------|-------------|--------|
| `nixos_deploy_total` | Total deployments | `status` = `success`, `dry_run_failed`, `merge_failed`, `apply_failed` |
| `nixos_session_input_tokens_total` | Claude Code input tokens from deployer activity (via Vector/Claude session logs) | `model`, `project` |
| `nixos_session_output_tokens_total` | Claude Code output tokens | `model`, `project` |
| `nixos_session_cost_usd_total` | Claude API cost (USD) | `model`, `project` |

### Gauges

| Metric | Description | Labels |
|--------|-------------|--------|
| `nixos_staging_lag_commits` | Commits in `staging` branch not yet merged to `main` | none |
| `nixos_generations_total` | Count of retained NixOS system generations | none |

### Histograms

| Metric | Description | Labels |
|--------|-------------|--------|
| `nixos_deploy_duration_seconds_bucket` | Deploy stage duration | `stage` = `dry_run`, `merge`, `apply` |

## Logs

**Source:** `nixos-deployer` systemd unit
**Transport:** Vector (`journald` → VictoriaLogs)
**Format:** Structured JSON

### Log Fields

Each log entry includes:
- `service` = `"nixos-deployer"`
- `stage` = workflow stage (`dry_run`, `merge`, `apply`, `poll`, `gc`, `record_deploy`)
- `status` = outcome (`started`, `success`, `failed`, `no_changes`)
- `workflow` = workflow type (`deploy`, `poller`, `gc`)
- Optional: `error`, `stderr` (first 500 chars), `commit`, `sha`, `ahead_by`

### Example Logs

```json
{"service":"nixos-deployer","stage":"poll","staging_sha":"65c0ebe...","main_sha":"4b788a4...","ahead_by":1}
{"service":"nixos-deployer","workflow":"deploy","commit":"65c0ebe...","status":"started"}
{"service":"nixos-deployer","stage":"dry_run","status":"success","commit":"65c0ebe..."}
{"service":"nixos-deployer","stage":"merge","status":"success","sha":"ab1234cd..."}
{"service":"nixos-deployer","stage":"apply","status":"success"}
{"service":"nixos-deployer","stage":"record_deploy","status":"success"}
```

## Dashboard

**UID:** `services-nixos-deployer`
**Title:** "Services — NixOS Deployer"
**Location:** Grafana → Dashboards → Search "nixos-deployer"

### Panels

1. **Status Row**
   - Deploy Success Rate (stat, reqps)
   - Staging Lag (stat, commits, yellow@3, red@6)
   - NixOS Generations (stat, count)

2. **Deploy Activity Row**
   - Deploys by Status (time series, 10m windows)
   - Deploy Duration p95 (time series, by stage)

3. **Logs Row**
   - nixos-deployer Logs (VictoriaLogs panel, `service:"nixos-deployer"`)

## Traces

**Not implemented yet.** Python deployer uses no tracing instrumentation.

Consider adding if:
- Deploy workflow duration > 5 minutes (need visibility into activity timing)
- GitHub API flakiness (need correlation between API calls and outcome)
- Cross-service deploy chains (deployer → NixOS rebuild → other services)

## Architecture

```
nixos-deployer (Python + Temporal)
    ├─ :9110/metrics (Prometheus format)
    │  └─ Vector `prometheus_scrape` @ 60s
    │     └─ VictoriaMetrics (remote_write)
    │        └─ Grafana queries via MetricsQL
    │
    └─ Logs (journald)
       └─ Vector `journald` source
          └─ VictoriaLogs (NDJSON ingestion)
             └─ Grafana queries via LogsQL
```

## Alert Rules

**Critical alerts** (fire immediately):
- `nixos_deploy_failures_total` rate > 0/min (any deploy failure in 1m window)

**Warning alerts** (fire after 5 min):
- `nixos_staging_lag_commits` > 10 (staging more than 10 commits ahead)

*Alert definitions:* `~/git/homelab/modules/alerts/nixos-deployer.yaml`

## Runbook Links

- **Deploy failed:** Check logs for `stage="dry_run"|"merge"|"apply" status="failed"`, examine stderr
- **Staging lag too high:** Check `nixos-staging-poller` workflow for errors, verify GitHub access
- **Metrics missing:** Verify Vector is forwarding to VictoriaMetrics (check `victoriametrics` sink in `modules/vector.nix`)

## Configuration

See `modules/nixos-deployer.nix` for service setup and `services/nixos-deployer/` for source.

Key environment variables:
- `GITHUB_REPO` = `AbstractBike/nixos`
- `STAGING_BRANCH` = `staging`
- `MAIN_BRANCH` = `main`
- `GITHUB_TOKEN` (loaded from SOPS secrets)

---

**Last updated:** 2026-03-04
**Status:** ✅ Metrics + Logs deployed, Grafana dashboard provisioned
