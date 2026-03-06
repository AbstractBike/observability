# Ralph Loop Prompts — Saved

Prompts recovered from `~/.claude/paste-cache/` before they were lost.

---

## Prompt 1 — SkyWalking + SigNoz Observability Audit

Source: `paste-cache/104f5aad02393312.txt`

```
/ralph-loop Audit and fix SkyWalking and SigNoz observability stacks.
  For each platform: (1) verify the UI is accessible and healthy, (2) verify
  services/traces/metrics are being ingested (not empty), (3) identify and fix any broken
  datasource connections, missing data, or misconfigured scrapers, (4) verify Grafana
  dashboards using SkyWalking or SigNoz datasources show actual data (not "No data"),
  (5) use Playwright for visual verification of all panels. Work GitOps-only via main
  branch on AbstractBike/heater-observability. URLs: http://skywalking.pin,
  http://signoz.pin, http://grafana.pin. Save audit results to ./observability-audit/report.md
  --completion-promise 'SkyWalking UI is accessible and receiving traces/metrics from at
  least one service, SigNoz UI is accessible and receiving telemetry data, All Grafana
  panels using SkyWalking or SigNoz datasources show actual data (not No data), Report
  saved to ./observability-audit/report.md'
  --max-iterations 50
```

---

## Prompt 2 — VictoriaMetrics + Grafana Dashboard Coverage Audit

Source: `paste-cache/7d1adad48a5f6d7d.txt`

```
Verify that all VictoriaMetrics metrics are covered in at least one Grafana dashboard
panel, and that every panel with a VictoriaMetrics datasource actually shows data. Use
Playwright for visual verification.

## Context
- Kubernetes homelab with FluxCD GitOps
- Grafana runs in namespace `observability` on cluster `heater-observability`
- VictoriaMetrics runs in namespace `monitoring`, service
  `vm-victoria-metrics-single-server`, port 8428
- Grafana datasource uid for VictoriaMetrics: `victoriametrics`
- Grafana has anonymous viewer access enabled
- kubeconfig path: ~/.kube/heater-observability

## Phase 1: Expose services locally

Start port-forwards in the background:
```bash
kubectl --kubeconfig ~/.kube/heater-observability port-forward svc/grafana -n observability 3000:80 &
kubectl --kubeconfig ~/.kube/heater-observability port-forward svc/vm-victoria-metrics-single-server -n monitoring 8428:8428 &
sleep 5  # wait for tunnels to establish
```

Verify access:
- Grafana: http://localhost:3000 (anonymous viewer)
- VictoriaMetrics: http://localhost:8428

## Phase 2: Enumerate all active VictoriaMetrics metrics

Fetch all metric names via the Prometheus labels API:
  GET http://localhost:8428/api/v1/label/__name__/values

Parse the JSON response and collect the full list of metric names. Store as vm_metrics: Set<string>.

Also fetch a sample value for each metric to confirm it is actively receiving data:
  GET http://localhost:8428/api/v1/query?query={__name__="<metric_name>"}
Mark metrics with empty result data as stale.

## Phase 3: Enumerate all Grafana dashboards and extract metric usage

Use the Grafana HTTP API (no auth needed):

1. List all dashboards:
   GET http://localhost:3000/api/search?type=dash-db&limit=5000
2. For each dashboard, fetch full JSON:
   GET http://localhost:3000/api/dashboards/uid/<uid>
3. Parse dashboard.panels[] recursively (panels can be nested inside rows):
   - For each panel, look at targets[].expr (PromQL expressions)
   - Extract metric names from PromQL using regex
   - Use regex: /\b([a-z_][a-z0-9_:]*)\s*(?:\{|\[|$)/g on each expression
   - Also check targets[].datasource.uid — only count panels where datasource uid is
     `victoriametrics` or `signoz` (both Prometheus-compatible)
   - Build a map: dashboard_metrics: Map<panelId, Set<metricName>>
4. Compute covered_metrics = union of all metric names found across all panels.
5. Compute uncovered_metrics = vm_metrics minus covered_metrics.

## Phase 4: Playwright visual verification — panels with data

For each dashboard with at least one VictoriaMetrics/Prometheus datasource panel:

1. Navigate to: http://localhost:3000/d/<uid>?from=now-1h&to=now&kiosk
2. Wait for the dashboard to fully load
3. For each panel:
   a. Check if it displays "No data" text
   b. Check if it displays an error state ([data-testid="panel-status-error"])
   c. Capture a screenshot if either condition is true
   d. Record: { dashboardTitle, panelTitle, panelId, status: 'NO_DATA' | 'ERROR' | 'OK' }

Note: Skip panels of type text, news, dashlist, alertlist.

## Phase 5: Generate report

Produce a structured report with:

### Summary
- Total VM metrics scraped: N
- Metrics covered in dashboards: N (%)
- Metrics NOT in any dashboard: N
- Total panels checked: N
- Panels with data: N
- Panels with NO DATA: N
- Panels with ERROR: N

### Uncovered Metrics
List each metric name, grouped by prefix (node_*, kube_*, container_*, istio_*, etc.)

### Panels with NO DATA or ERROR
For each: Dashboard, Panel, Status, URL

### Screenshots
Save to ./grafana-audit/screenshots/<dashboard>-<panel>.png

## Success Criteria
- All VictoriaMetrics metrics have at least one Grafana panel referencing them
- All dashboard panels with VictoriaMetrics datasource show actual data
- Report saved to ./grafana-audit/report.md

Completion condition: DONE when the full report is generated at ./grafana-audit/report.md
```
