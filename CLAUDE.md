# observability

Grafana dashboards, alerts, and observability config for homelab — 40+ dashboards in Jsonnet (grafonnet).

## Stack

- Dashboard DSL: Jsonnet (grafonnet 11.4.0)
- Compiler: go-jsonnet (via Nix)
- Backend: VictoriaMetrics (metrics), VictoriaLogs (logs), Tempo (traces)
- Query languages: MetricsQL, LogsQL, PromQL
- UI: Grafana v11+

## Commands

- Validate syntax: `./validate.sh` (~2s)
- Build all dashboards: `nix build .#dashboards`
- Full test: `nix build .#checks.x86_64-linux.grafana`
- Dev shell: `nix develop` (provides go-jsonnet, jq, yq-go)

## Structure

- `dashboards-src/` — Jsonnet source files by category:
  - `home/` — overview, `heater/` — host, `services/` — per-service
  - `pipeline/` — Vector, `observability/` — meta, `slo/` — SLOs
  - `apm/` — tracing, `claude/` — Claude monitoring
  - `lib/common.libsonnet` — shared helpers
- `dashboards_new/` — drop zone for pre-compiled JSON dashboards
- `nix/dashboards.nix` — Nix build recipe

## Conventions

- Panel naming: `{MetricType} — {Service} — {Context}`
- Dashboard UID = basename of jsonnet file (no extension)
- New dashboards: create `.jsonnet` in `dashboards-src/<category>/`
- Quick uploads: drop JSON in `dashboards_new/` (auto-provisioned)

## Rules

- ALWAYS run `./validate.sh` before committing
- Mandatory labels on all queries: `service`, `host`, `env`
- Deploy: auto via `nixos-rebuild switch --flake` on homelab
