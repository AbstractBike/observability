# Job Hunter — Observability

## Signals

| Signal  | Destination     | Transport           |
|---------|-----------------|---------------------|
| Metrics | VictoriaMetrics | Vector local HTTP   |
| Logs    | VictoriaLogs    | Vector local HTTP   |
| Traces  | SkyWalking OAP  | gRPC (future)       |

## Key Metrics

- `hunter_jobs_found{slug,mode,tier}` — offers found per run
- `hunter_search_duration_seconds{slug,mode}` — total search time
- `hunter_email_sent{slug,status}` — email delivery status
- `hunter_sources_searched{slug}` — unique sources queried
- `hunter_errors_total{slug,phase}` — errors by phase

## Alerts

See `alerts.yml` in this directory.

## Dashboard

See `dashboard.jsonnet` in this directory.

Panels:
1. Offers found per day (stacked by slug, colored by tier)
2. Average score per week (market trend)
3. Average estimated salary per week
4. Top sources by hit rate
5. Latency per phase (search, email, total)
6. Active alerts
7. Table: latest Tier 1 offers (from VictoriaLogs)
