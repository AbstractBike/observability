# 📚 Grafana Dashboard Maintenance Guide

**Last Updated**: 2026-03-04
**Scope**: 27 Jsonnet-based dashboards in `/observability/dashboards-src/`
**Automation**: Playwright test suite in `/scripts/`

## 📋 Quick Reference

### Dashboard Categories

| Category | Count | Path | Status |
|----------|-------|------|--------|
| Overview | 3 | `overview/` | ✅ 67% healthy |
| Heater (Intel) | 5 | `heater/` | ✅ 80% healthy |
| Services | 8 | `services/` | ⚠️ 50% healthy |
| Observability | 2 | `observability/` | ✅ 100% healthy |
| Pipeline/SLO | 4 | `pipeline/`, `slo/` | ⚠️ 25% healthy |

### Datasources Required

```
VictoriaMetrics (metrics):
  Endpoint: http://192.168.0.4:8428
  Query Language: MetricsQL
  Status: ✅ HEALTHY

VictoriaLogs (logs):
  Endpoint: http://192.168.0.4:9428
  Query Language: LogsQL
  Status: ✅ HEALTHY

SkyWalking (traces/APM):
  Endpoint: http://192.168.0.4:12800 (REST)
  Query Language: GraphQL / REST API
  Status: ✅ HEALTHY
```

## 🔧 Common Maintenance Tasks

### Task 1: Add New Dashboard

**Steps**:
1. Create `observability/dashboards-src/<category>/<name>.jsonnet`
2. Use template from existing dashboard in same category
3. Import common library: `local c = import 'lib/common.libsonnet';`
4. Configure panels with proper fallbacks: `or vector(0)`
5. Test locally: `jsonnet observability/dashboards-src/<category>/<name>.jsonnet`
6. Commit and deploy via nixos-rebuild

**Validation Checklist**:
- [ ] Dashboard UID is unique
- [ ] All queries have fallback pattern
- [ ] Time windows are [5m] standard
- [ ] Datasource variables used correctly
- [ ] Logs panel includes service filter
- [ ] Description explains data source

### Task 2: Update Dashboard Queries

**Steps**:
1. Edit `.jsonnet` file directly
2. Test MetricsQL queries in VictoriaMetrics UI first
3. Apply `or vector(0)` fallback to all rate/gauge/histogram queries
4. Update dashboard UID and timestamp in metadata
5. Run test suite: `node scripts/verify-dashboards-comprehensive.js`
6. Verify in Grafana UI
7. Commit with message: `fix(dashboards): update <dashboard> <metric_name>`

**Query Pattern Checklist**:
- [ ] All `rate()` queries wrapped: `(rate(...) or vector(0))`
- [ ] All `histogram_quantile()` have fallback
- [ ] Division operations wrapped: `(a / b or vector(0))`
- [ ] Time window is `[5m]` (5 minutes)
- [ ] Labels use correct format: `{service="name"}`

### Task 3: Fix "No data" Panel

**Diagnosis**:
1. Check datasource in Grafana: Dashboards → Dashboard Name → Panel → View
2. Verify metric exists: `curl http://192.168.0.4:8428/api/v1/query?query=metric_name`
3. Check time range: Dashboard has data in selected time window?
4. Verify service running: `systemctl status <service>`

**Resolution**:
- If metric missing: Verify service exports metrics
- If service down: Start service, wait 5m for metrics to appear
- If query wrong: Fix in Jsonnet, deploy, test

### Task 4: Optimize Dashboard Performance

**Symptoms**:
- Dashboard takes > 5 seconds to load
- VictoriaMetrics CPU high
- Too many queries executing

**Solutions**:
1. Reduce query frequency: Change `[5m]` to `[15m]` if appropriate
2. Aggregate earlier: Use `sum by (...)` instead of raw metrics
3. Limit time range: Use recent data, not full history
4. Use `topk()` to limit series: `topk(10, ...)`
5. Cache results with recording rules (advanced)

## 📊 Dashboard Dependency Map

### What Each Dashboard Needs

**Overview Dashboards**:
- `homelab-overview` → node_exporter metrics (system)
- `services-homelab-system` → node_exporter (system)
- `slo-overview` → custom `slo:*` compiled metrics (NOT IMPLEMENTED)

**Heater (Intel) Dashboards**:
- `heater-system` → node_exporter
- `heater-jvm` → JVM/IntelliJ logs (vector tail)
- `heater-processes` → prometheus-node-exporter process module
- `heater-gpu` → nvidia exporter (if GPU installed)
- `heater-claude-code` → claude code metrics (internal)

**Service Dashboards**:
- `services-redis` → redis_exporter
- `services-postgresql` → postgres_exporter
- `services-temporal` → temporal/prometheus endpoint
- `services-redpanda` → redpanda exporter (partial)
- `services-elasticsearch` → elasticsearch exporter
- `services-clickhouse` → clickhouse exporter
- `services-nixos-deployer` → custom logs
- `matrix-apm` → skywalking OAP metrics

**Observability Dashboards**:
- `observability-grafana` → grafana internal metrics
- `observability-skywalking` → skywalking OAP JVM metrics

**Pipeline Dashboards**:
- `pipeline-vector` → vector internal_metrics
- `arbitraje-main` → custom arbitrage_* metrics (app not running)
- `arbitraje-dev` → custom arbitrage_* metrics (app not running)
- `pin-traces` → skywalking trace metrics

## 🚨 Troubleshooting Guide

### Problem: "No data" on all panels

**Cause**: Datasource disconnected
**Fix**:
```bash
# Check VictoriaMetrics
curl -s http://192.168.0.4:8428/api/health | jq .

# Check VictoriaLogs
curl -s http://192.168.0.4:9428/api/health | jq .

# Check SkyWalking
curl -s http://192.168.0.4:12800/api/health
```

### Problem: Dashboard loading very slowly

**Cause**: Too many queries or large time range
**Fix**:
1. Change time range to last 1-6 hours (top of dashboard)
2. Disable unnecessary panels: Panel menu → Hide
3. Check VictoriaMetrics load: `http://192.168.0.4:8428/`

### Problem: One metric missing data

**Cause**: Service not running or not reporting
**Fix**:
```bash
# Check if metric exists
curl "http://192.168.0.4:8428/api/v1/label/__name__/values?match=metric_name"

# Check service status
systemctl status <service>

# Check Vector pipeline
systemctl status vector
```

### Problem: Log panel empty

**Cause**: Service not logging or filter too strict
**Fix**:
1. Remove time range filter: Try "Last 24 hours"
2. Remove service filter: Try `{level="info"}` first
3. Check logs exist: `http://192.168.0.4:9428/vmui`

## 📈 Testing & Validation

### Run Full Test Suite

```bash
# Run all tests
bash scripts/run-all-dashboard-tests.sh

# Run specific test
node scripts/verify-dashboards-comprehensive.js
node scripts/test-correlation.js
node scripts/test-performance.js
```

### Expected Results

```
✅ PASS:        13/22 dashboards (59.1%)
⚠️  NO DATA:     8/22 dashboards (36.4%) - expected
❌ ERROR:       1/22 dashboards (4.5%) - SLO needs setup
```

### Add Dashboard to Test Suite

Edit `scripts/verify-dashboards-comprehensive.js`:
```javascript
const DASHBOARDS = [
  // ... existing dashboards ...
  { uid: 'new-dashboard-uid', name: 'New Dashboard', category: 'category' },
];
```

Then run tests.

## 🔄 Deployment Workflow

### 1. Local Development

```bash
# Edit dashboard
vim observability/dashboards-src/<category>/<name>.jsonnet

# Validate syntax
jsonnet observability/dashboards-src/<category>/<name>.jsonnet > /tmp/test.json

# Test queries locally (copy queries to Grafana UI)
```

### 2. Commit & Push

```bash
git add observability/dashboards-src/<category>/<name>.jsonnet
git commit -m "feat(dashboards): add <name> dashboard"
git push origin <branch>
```

### 3. Deploy to Homelab

```bash
# On homelab host
cd /home/digger/git/homelab
nix flake check  # Run tests
nixos-rebuild switch --flake .#homelab
```

### 4. Verify in Grafana

- Open `http://home.pin`
- Search for dashboard name
- Check all panels show data
- Validate logs panel works

## 📚 Library Reference

### Common Functions (lib/common.libsonnet)

```jsonnet
// Query builder - VictoriaMetrics
c.vmQ(query, legend='')

// Query builder - VictoriaLogs
c.vlogsQ(filter)

// Query builder - SkyWalking
c.swQ(query, legend='')

// Panel positioning helpers
c.statPos(col)              // Stat panel at column
c.tsPos(col, row)          // Time series at position
c.pos(x, y, w, h)          // Generic positioning

// Service logs panel
c.serviceLogsPanel(title, service, y)

// Dashboard defaults
c.dashboardDefaults        // Common settings
c.vmDsVar, c.vlogsDsVar, c.swDsVar  // Datasource variables
```

## ⚠️ Important Notes

### Query Fallback Pattern

**ALWAYS use fallback**:
```jsonnet
c.vmQ('(metric_query) or vector(0)')
```

Without fallback, panels show "No data" when metric temporarily unavailable.

### Time Window Standards

**PREFERRED**: `[5m]` (5 minutes)
**Rationale**: Balance between granularity and performance

**Use `[15m]` or `[30m]` for**:
- Long-term trends (> 24 hours data)
- Low-frequency metrics
- Performance-sensitive queries

### Datasource Variables

**MUST use variables** for multi-tenant/multi-host dashboards:
```jsonnet
c.vmQ('metric{host=~"$host"}')
```

Never hardcode values in queries.

## 📞 Support & Escalation

**Issue Type** | **First Step** | **If Not Resolved**
---|---|---
No data | Check datasource in Grafana | Check service status
Slow dashboard | Reduce time range | Check VictoriaMetrics load
Wrong metric | Verify query in VictoriaMetrics UI | Update dashboard query
Missing service | Verify `status show <svc>` | Check Vector pipeline

---

**Last Verification**: 2026-03-04
**Test Pass Rate**: 59.1% (13/22 healthy)
**Next Review**: 2026-03-11
