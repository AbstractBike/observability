# 🚀 Observability Improvements Roadmap

**Status**: Ralph Loop Session 2 (Iterations 1-4 Complete)
**Last Updated**: 2026-03-04
**Quality Score**: 87/100 (↑ from 69)

---

## 📊 Overview

After 60 iterations of Ralph Loop optimization, the observability stack achieved **PRODUCTION READY** status with 59.1% dashboard health and 100% correlation tests passing. This roadmap outlines the **next wave of improvements** without breaking changes.

## 🎯 Priority Matrix

| Priority | Effort | Impact | Status | Category |
|----------|--------|--------|--------|----------|
| **P0** | 2h | 🔴 Critical | ✅ DONE | External Links (all 27 dashboards) |
| **P1** | 4h | 🟠 High | 🚀 In Progress | Log Organization + Metric Discovery |
| **P1** | 3h | 🟠 High | ✅ DONE | Services Health Dashboard |
| **P2** | 6h | 🟡 Medium | ⏳ Pending | Trace Correlation via Exemplars |
| **P2** | 3h | 🟡 Medium | ⏳ Pending | Dashboard Consolidation |
| **P3** | 8h | 🟢 Low | ⏳ Backlog | Cost Analysis Dashboard |

---

## ✅ Completed (Iteration 61)

### 1. External Links Panel ✅
**Implementation**: Feature added to dashboard library

```jsonnet
// New helper in common.libsonnet
externalLinksPanel(y=0, x=18):
  // Quick-access buttons to:
  // - VictoriaMetrics UI (http://192.168.0.4:8428)
  // - VictoriaLogs explorer (http://192.168.0.4:9428/vmui)
  // - SkyWalking UI (http://192.168.0.4:8080)
```

**Status**:
- ✅ Helper function created in `lib/common.libsonnet`
- ✅ Applied to `homelab-overview` dashboard
- ✅ Applied to `observability-grafana` dashboard
- ⏳ Batch script created for remaining dashboards

**Next**: Run `/scripts/add-external-links-to-dashboards.sh` to apply to all 27 dashboards

### 2. Quality Analysis Scripts ✅

**Created**:
- `scripts/analyze-dashboard-quality.js` — Quality auditor (69/100 baseline)
- `scripts/audit-dashboard-dependencies.sh` — Metric dependency checker
- `scripts/add-external-links-to-dashboards.sh` — Batch link injection

**Findings**:
- 11 dashboards missing logs panel
- 25 dashboards need external links (being systematically added)
- Query distribution: 6-10 queries per dashboard (healthy)

---

## ✅ Completed (Iterations 2-4)

### 2. All Dashboards Updated with External Links ✅
**Progress**: 27/27 dashboards (100%)

- Manually updated: 5 heater dashboards
- Automated (v2 script): 18 dashboards
- Manual fixes: 2 special-format dashboards (pin-traces, home)

**Impact**: Quality score 87%, users can now quickly navigate to VictoriaMetrics, VictoriaLogs, SkyWalking from any dashboard

### 3. Logs Panels Enhancement ✅
**Added to**: 2 critical dashboards
- overview/homelab: System logs (warn/error/critical)
- services/matrix-apm: Service logs

### 4. Metrics Discovery Dashboard ✅
**New dashboard**: observability/metrics-discovery

**Features**:
- Show all metrics in VictoriaMetrics
- Cardinality per metric
- Active jobs/exporters
- Ingestion rate tracking
- Top jobs by series count

**Use case**: Identify unused exporters, troubleshoot missing metrics, find cardinality explosions

### 5. Services Health Super-Dashboard ✅
**New dashboard**: overview/services-health

**Features**:
- Consolidated health view (all services)
- Status indicators (healthy/down/degraded)
- Error rate and latency trends
- Quick navigation links
- Error logs from all services

**Use case**: Single pane of glass for infrastructure health

### 6. Quality Analysis & Tools ✅
Created:
- `scripts/analyze-dashboard-quality.js` — Quality scoring
- `scripts/apply-external-links-v2.py` — Batch automation
- `scripts/validate-dashboards-compile.sh` — Pre-deployment validation

**Quality Score Progress**: 69% → 87% (↑ 18 points)

---

## 🔄 In Progress (Iteration 5+)

### 1. External Links Batch Application
**Objective**: Apply `externalLinksPanel()` to all remaining 25 dashboards

**Manual process** (safe, non-destructive):
```bash
# For each dashboard category:
# 1. Edit the dashboard file
# 2. Add c.externalLinksPanel(y=..., x=18) after row header
# 3. Test: jsonnet compile
# 4. Commit

# Dashboard categories to update:
# - services/* (8 dashboards)
# - heater/* (5 dashboards)
# - pipeline/* (4 dashboards)
# - slo/* (1 dashboard)
# - observability/* (3 more dashboards)
# - overview/* (1 more dashboard)
```

**Status**: Scripts ready, awaiting batch execution

---

## ⏳ Planned (Iteration 62-70)

### P1: Log Organization Enhancement (4h effort)
**Problem**: VictoriaLogs panels exist but lack filtering by service

**Solution**: Add Loki plugin support to Grafana
- Enable `grafana-loki` plugin
- Create log aggregation dashboard showing:
  - Logs grouped by service
  - Log volume by severity
  - Error rate trends
- Update all service dashboards to use Loki-powered log panels

**Impact**: Better log exploration UX, searchability

**Files to modify**:
- `hosts/homelab/modules/grafana/datasources.nix` (add Loki DS)
- `observability/dashboards-src/observability/logs.jsonnet` (enhance)
- Service dashboards: add Loki log panels

---

### P1: Metric Discovery Dashboard (3h effort)
**Problem**: No central view of available metrics

**Solution**: Create `observability/dashboards-src/observability/metrics-discovery.jsonnet`

**Dashboard contents**:
- All available metrics (fetched from VictoriaMetrics `/api/v1/label/__name__/values`)
- Metrics by job (postgres-exporter, redis-exporter, etc.)
- Metric cardinality stats
- Recently active metrics (last 5 mins)
- Metrics without dashboards (orphaned metrics)

**Query example**:
```promql
# Show all metrics with their series count
topk(50, sum by(__name__) (count({__name__=~".*"})))
```

**Impact**: Easier metric discovery, identify unused exporters

---

### P2: Trace Correlation via Exemplars (6h effort)
**Problem**: No direct trace ↔ metric correlation in histograms

**Solution**: Add exemplar support to histogram panels

**Implementation**:
1. Modify histogram queries to include exemplars
2. Configure SkyWalking OAP to expose trace IDs in exemplars
3. Update Grafana histogram panels to display exemplar markers
4. Enable click-to-trace integration

**Example panel config**:
```jsonnet
g.panel.timeSeries.new('Request Latency')
+ g.panel.timeSeries.queryOptions.withTargets([
  c.vmQ(
    'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))',
    'p95'
  ),
])
+ {
  // Enable exemplars (requires Grafana 7.0+)
  fieldConfig: {
    defaults: {
      custom: {
        hideFrom: { tooltip: false, viz: false, legend: false },
      },
    },
  },
}
```

**Files to modify**:
- `observability/dashboards-src/services/**/*.jsonnet` (all service dashboards)
- `observability/dashboards-src/observability/skywalking.jsonnet`

---

### P2: Dashboard Cleanup & Consolidation (3h effort)
**Problem**: Some dashboards are overly simple or redundant

**Analysis findings**:
- `slo/overview` has only 2 queries (minimal, could merge)
- `observability/logs` has only 2 queries (minimal, could expand)
- Some service dashboards have low query counts (opportunity to add panels)

**Action items**:
- [ ] Merge `slo/overview` data into `homelab-overview` dashboard
- [ ] Expand `observability/logs` with service-specific log panels
- [ ] Add cost analysis panel to `observability-grafana` dashboard
- [ ] Create `overview/services-health` super-dashboard (status + alerts)

---

### P3: Cost Analysis Dashboard (8h effort)
**Objective**: Track infrastructure costs (cardinality, storage, ingestion)

**Dashboard**: `observability/dashboards-src/observability/costs.jsonnet`

**Metrics to track**:
- VictoriaMetrics cardinality (time series count)
- VictoriaMetrics storage used (MB/GB)
- Log ingestion rate (logs/sec)
- Trace sampling rate (%)
- Cost estimate (based on volume)

**Queries**:
```promql
# VictoriaMetrics cardinality
vm_hourly_series_limit_rows

# Storage usage
vm_data_size_bytes

# Query latency (cost proxy)
rate(vm_http_request_duration_seconds_sum[5m])
```

**Impact**: Cost visibility, optimization opportunities

---

## 🐛 Known Limitations (Not Blocking)

| Item | Impact | Timeline |
|------|--------|----------|
| Some service dashboards need exporter setup | MEDIUM | On-demand |
| SkyWalking UI not embedded in Grafana | LOW | Post-Grafana 11 |
| Loki plugin not yet installed | MEDIUM | Next phase |
| Cost tracking not implemented | LOW | Q2 2026 |

---

## 📈 Quality Metrics Progress

| Metric | Baseline | Target | Status |
|--------|----------|--------|--------|
| Dashboard quality score | 69% | 85% | 🔄 In progress |
| Dashboards with external links | 2/27 (7%) | 27/27 (100%) | 🔄 In progress |
| Dashboards with logs panels | 16/27 (59%) | 24/27 (89%) | ⏳ Pending |
| Dashboards with descriptions | 25/27 (93%) | 27/27 (100%) | ⏳ Pending |
| Dashboards with tags | 25/27 (93%) | 27/27 (100%) | ⏳ Pending |

---

## 🛠️ How to Contribute

### To apply external links to remaining dashboards:

1. **Pick a dashboard file**:
   ```bash
   vim observability/dashboards-src/services/redis.jsonnet
   ```

2. **Add the panel** (after first row definition):
   ```jsonnet
   g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
   c.externalLinksPanel(y=1, x=18),  // ← ADD THIS
   statPanel1, statPanel2, ...
   ```

3. **Validate**:
   ```bash
   nix flake check
   ```

4. **Test in Grafana**:
   - Rebuild: `nixos-rebuild switch --flake .#homelab`
   - Open: `http://home.pin`
   - Look for 🔗 External Links panel

### To add a new improvement:

1. Add to this roadmap
2. Create a branch: `git checkout -b improve/your-feature`
3. Implement changes
4. Run tests: `bash scripts/run-all-dashboard-tests.sh`
5. Create PR with: `git push origin improve/your-feature`

---

## 📚 Related Documentation

- [DASHBOARD-MAINTENANCE.md](./DASHBOARD-MAINTENANCE.md) — How to modify dashboards
- [DASHBOARD-DEPENDENCIES.md](./DASHBOARD-DEPENDENCIES.md) — What metrics each dashboard needs
- [DASHBOARD-RUNBOOK.md](./DASHBOARD-RUNBOOK.md) — Operational procedures
- [VALIDATION-CHECKLIST.md](./VALIDATION-CHECKLIST.md) — What was validated

---

## 🎯 Next Review

**Date**: 2026-03-11
**Focus**:
- External links applied to all 27 dashboards (95%+ score)
- Metric discovery dashboard deployed
- Trace correlation exemplars working

---

**Authored**: Claude Code Agent
**Phase**: Post-Ralph-Loop Continuous Improvement
**Version**: 0.1.0
