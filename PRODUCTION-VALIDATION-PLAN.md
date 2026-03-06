# ✅ Production Validation & Testing Strategy

**Date:** 2026-03-04 (Iteration 38)
**Purpose:** Comprehensive testing plan before production deployment
**Status:** Blueprint for validation across all observability improvements

---

## Overview

**Goal:** Validate all work from Iterations 30-37:
- Query performance optimizations
- External links integration
- Runbook integration
- Service registry
- Dashboard navigation
- Alert integration
- Dashboard alert panels

**Scope:** 41 dashboards + alerting system + runbooks

---

## Phase 1: Documentation Validation

### Checklist: Are All Guides Complete?

- [ ] **OPTIMIZATION-GUIDELINES.md** — 6 core principles ✅
- [ ] **PATTERNS-LIBRARY.md** — Copy-paste patterns ✅
- [ ] **DEVELOPMENT-PLAYBOOK.md** — Step-by-step guide ✅
- [ ] **EXTERNAL-LINKS-REGISTRY.md** — Service links ✅
- [ ] **RUNBOOK-INTEGRATION-GUIDE.md** — 4-level integration ✅
- [ ] **SERVICE-REGISTRY.md** — Inventory system ✅
- [ ] **SERVICE-REGISTRY.yaml** — Example config ✅
- [ ] **DASHBOARD-NAVIGATION-GUIDE.md** — Catalog + breadcrumbs ✅
- [ ] **ALERT-INTEGRATION-GUIDE.md** — Alert routing ✅
- [ ] **DASHBOARD-ALERTS-IMPLEMENTATION.md** — Panel implementation ✅

**Validation:** All documentation complete and consistent ✅

---

## Phase 2: Query Performance Validation

### Objective
Verify that optimizations from P4 (Iterations 21-31) are working

### Test Suite

#### Test 2.1: Fallback Patterns (vector(0))
```
Dashboard: query-performance
Test Method:
  1. Open each dashboard with non-existent service filter
  2. Verify no "No data" errors
  3. All panels should show 0 or "No data" gracefully

Expected: 100% of fallback queries work
Status: ?
```

#### Test 2.2: Histogram Quantile Optimization
```
Dashboard: skywalking-traces, service-dependencies
Test Method:
  1. Run: histogram_quantile(0.95, sum by(le) (rate(...)))
  2. Measure query execution time
  3. Compare to unbounded version
  4. Target: <200ms p95 latency

Expected: 10-15% faster than unbounded
Status: ?
```

#### Test 2.3: topk() Filtering Optimization
```
Dashboard: skywalking-traces
Test Method:
  1. Run: topk(10, metric{env="prod"})
  2. Measure cardinality reduction
  3. Compare execution time to unfiltered
  4. Target: <250ms p95 latency

Expected: 5-10% faster with pre-filtering
Status: ?
```

#### Test 2.4: Overall Dashboard Load Time
```
Test Method:
  1. Open dashboard in Grafana
  2. Measure total load time (DevTools Network tab)
  3. Expected: <2s p95 for all dashboards

Current: ? (measure baseline)
Target: <2s p95
Status: ?
```

### Validation Script

```bash
#!/bin/bash
# tools/validate-performance.sh

echo "=== Query Performance Validation ==="

# Test 1: Check fallback patterns
echo "Test 1: Fallback patterns..."
curl -s 'http://192.168.0.4:8428/api/v1/query?query=rate(metric_that_doesnt_exist[5m]) or vector(0)' \
  | jq '.data.result[0].value' | grep -q "0" && echo "✅ Fallback working" || echo "❌ Fallback failed"

# Test 2: Histogram quantile performance
echo "Test 2: Histogram quantile optimization..."
time curl -s 'http://192.168.0.4:8428/api/v1/query?query=histogram_quantile(0.95, sum by(le) (rate(latency_bucket[5m])))' \
  | jq '.data.result | length'

# Test 3: topk filtering
echo "Test 3: topk() optimization..."
time curl -s 'http://192.168.0.4:8428/api/v1/query?query=topk(10, metric{env="prod"})' \
  | jq '.data.result | length'

echo "=== Validation Complete ==="
```

---

## Phase 3: Dashboard Functionality Validation

### Test 3.1: External Links

```
Test: Every dashboard has external links panel

Method:
  1. Open each of 41 dashboards
  2. Check top-right corner for link buttons
  3. Click each button, verify opens correct URL
  4. Expected: 3 buttons (Metrics, Logs, Traces)

Validation Script:
  for dashboard in $(ls observability/dashboards-src/**/*.jsonnet); do
    grep -q "externalLinksPanel\|customExternalLinksPanel" "$dashboard" && \
      echo "✅ $dashboard" || echo "❌ $dashboard"
  done
```

### Test 3.2: Runbook Links

```
Test: Every service dashboard has runbook links

Method:
  1. Open service dashboard
  2. Check description for runbook links
  3. Click runbook link, verify opens
  4. Expected: Main + 2-3 issue-specific runbooks

Validation: Manual check of 10 critical dashboards
- PostgreSQL: Main + high-cpu + conn-pool + memory
- API Gateway: Main + latency + errors + circuit-breaker
- Redis: Main + memory-pressure + eviction
- (etc.)
```

### Test 3.3: Navigation Elements

```
Test: Dashboard catalog and breadcrumbs

Method:
  1. Open /d/service-catalog dashboard
  2. Verify lists all 41 services
  3. Click service link, opens correct dashboard
  4. Check breadcrumbs: Catalog → Service → Optional sub-dashboard
  5. Expected: No broken links, fast loading

Test Data:
  Services visible: 41 / 41
  Links working: 41 / 41
  Load time: ? (measure)
```

### Test 3.4: Alert Panels

```
Test: Alert count and alert list panels

Method:
  1. Compile dashboards: nix build '.#dashboards'
  2. Deploy to test Grafana instance
  3. For each critical dashboard:
     a. Check alert count panel exists
     b. Shows 0 when no alerts
     c. Fire test alert matching service
     d. Count updates to 1
     e. Alert list panel shows alert
     f. Click alert, see details
     g. Click runbook link

Expected: 100% of alert panels functional
Status: ?
```

---

## Phase 4: Service Registry Validation

### Test 4.1: Registry Completeness

```bash
#!/bin/bash
# Verify all services have registry entries

echo "=== Service Registry Validation ==="

# Count services in registry
registry_count=$(yq '.services | length' observability/SERVICE-REGISTRY.yaml)
echo "Services in registry: $registry_count"

# Verify each service has required fields
for service in $(yq '.services[].name' observability/SERVICE-REGISTRY.yaml); do
  has_dashboard=$(yq ".services[] | select(.name==\"$service\") | .dashboards" observability/SERVICE-REGISTRY.yaml)
  has_runbook=$(yq ".services[] | select(.name==\"$service\") | .runbooks" observability/SERVICE-REGISTRY.yaml)

  [[ -n "$has_dashboard" ]] && echo "✅ $service dashboard" || echo "⚠️  $service missing dashboard"
  [[ -n "$has_runbook" ]] && echo "✅ $service runbooks" || echo "⚠️  $service missing runbooks"
done
```

### Test 4.2: Service-Dashboard Mapping

```
Test: Every service in registry has corresponding dashboard

Method:
  1. For each service in SERVICE-REGISTRY.yaml:
     a. Get service.uid
     b. Look for observability/dashboards-src/*/{uid}.jsonnet
     c. Verify file exists
     d. Verify matches dashboard.withUid('{uid}')

Expected: 100% mapping (no orphaned services or dashboards)
Status: ?
```

---

## Phase 5: Alert Integration Validation

### Test 5.1: Alert Rules

```yaml
Test: Alert rules are configured correctly

Method:
  1. In Grafana, check Alerting > Alert Rules
  2. Verify each critical alert exists
  3. Check annotations:
     - dashboard_url present
     - runbook_url present
     - severity label set
     - service label set
  4. Trigger test alert:
     a. Manually fire alert in Grafana
     b. Check Slack notification has:
        - Dashboard link
        - Runbook link
        - Service name
        - Severity
        - Description

Expected: 100% of critical alerts properly configured
Status: ?
```

### Test 5.2: Notification Templates

```
Test: Slack/Email notifications work

Method:
  1. Configure test alert
  2. Set notification channel to test Slack
  3. Fire alert manually
  4. Check Slack message has:
     - Alert name
     - Description
     - Dashboard link
     - Runbook link
     - Severity badge

Expected: Notification format matches template
Status: ?
```

---

## Phase 6: On-Call Workflow Validation

### Test 6.1: Incident Simulation

```
Scenario: Database high CPU alert fires at 3 AM

Steps (measure time for each):
  1. Alert fires → Slack notification (expect <1 min)
  2. On-call clicks dashboard link (expect <10 sec)
  3. Dashboard loads (expect <2 sec)
  4. On-call sees alert panel red
  5. On-call clicks runbook (expect <5 sec)
  6. Runbook loads, shows steps
  7. On-call executes troubleshooting
  8. Check database metrics improve
  9. Alert resolves

MTTR Measurement:
  Alert → Notification: ? sec
  Notification → Dashboard: ? sec
  Dashboard → Runbook: ? sec
  Runbook → Resolution: ? min
  Total MTTR: ? min (target: <15 min)
```

### Test 6.2: Runbook Accuracy

```
Test: Runbooks are accurate and helpful

Method:
  1. Pick 3 random runbooks
  2. For each, verify:
     a. Steps are clear and actionable
     b. Dashboard screenshots are recent
     c. Links (to dashboards/logs/etc.) work
     d. Runbook matches current system
  3. Run through runbook steps:
     a. Follow investigation steps
     b. Can find metrics mentioned
     c. Can interpret results
     d. Remediation steps work

Expected: All runbooks accurate and helpful
Status: ?
```

---

## Phase 7: Performance Regression Testing

### Test 7.1: Dashboard Load Times

```bash
#!/bin/bash
# Measure dashboard load times

echo "=== Dashboard Load Time Validation ==="

dashboards=(
  "postgres-db"
  "api-gateway"
  "redis"
  "elasticsearch"
  "victoriametrics"
  "skywalking-oap"
)

for dash in "${dashboards[@]}"; do
  echo "Testing /d/$dash..."

  # Use curl to measure response time
  time curl -s "http://192.168.0.4:3000/api/dashboards/uid/$dash" \
    | jq '.dashboard.panels | length' > /dev/null
done

# Expected: All <2s p95
```

### Test 7.2: Query Latency Baseline

```
Baseline Metrics (measure now):
  Query latency p50: ? ms
  Query latency p95: ? ms
  Query latency p99: ? ms
  Slow query rate (>500ms): ? %

After Optimization Metrics:
  Query latency p50: ? ms (target: <150ms)
  Query latency p95: ? ms (target: <200ms)
  Query latency p99: ? ms (target: <300ms)
  Slow query rate: ? % (target: <5%)

Expected Improvement: 5-15% reduction
Status: ?
```

---

## Phase 8: Documentation Accuracy Validation

### Test 8.1: Guide Consistency

```
Cross-Reference Check:
  1. OPTIMIZATION-GUIDELINES → PATTERNS-LIBRARY
     - Same patterns documented in both?
     - Consistent naming?

  2. DEVELOPMENT-PLAYBOOK → PATTERNS-LIBRARY
     - Same patterns referenced?
     - Same examples?

  3. SERVICE-REGISTRY.md → SERVICE-REGISTRY.yaml
     - Matches template format?
     - All examples follow schema?

  4. ALERT-INTEGRATION → DASHBOARD-ALERTS-IMPL
     - Same alert config syntax?
     - Same notification templates?

Expected: 100% consistency across guides
Status: ?
```

### Test 8.2: Example Accuracy

```
For each example in documentation:
  1. Copy example code verbatim
  2. Test in actual dashboard
  3. Verify it works as documented
  4. Fix any discrepancies

Expected: 100% of examples work
Status: ?
```

---

## Validation Checklist

### Pre-Deployment (This Iteration)

- [ ] **Documentation Review**
  - [ ] All 10 guides reviewed for completeness
  - [ ] Consistency checks passed
  - [ ] Examples tested and working

- [ ] **Query Performance**
  - [ ] Fallback patterns tested
  - [ ] Histogram optimization verified
  - [ ] topk() filtering verified
  - [ ] Dashboard load times <2s

- [ ] **Dashboard Functionality**
  - [ ] External links all working
  - [ ] Runbook links all working
  - [ ] Navigation elements functional
  - [ ] Alert panels compiled and tested

- [ ] **Service Registry**
  - [ ] All 40+ services documented
  - [ ] Service-dashboard mapping 100%
  - [ ] Fields consistent across entries

- [ ] **Alert Integration**
  - [ ] Alert rules configured
  - [ ] Notifications formatted correctly
  - [ ] Dashboard links work
  - [ ] Runbook links work

- [ ] **On-Call Testing**
  - [ ] Incident simulation completed
  - [ ] MTTR measured
  - [ ] Runbooks accurate
  - [ ] Team trained

- [ ] **Performance Regression**
  - [ ] Load times established
  - [ ] No >10% regression in any metric
  - [ ] Alert panel performance acceptable

- [ ] **Documentation Accuracy**
  - [ ] All guides consistent
  - [ ] All examples working
  - [ ] No broken links

### Go/No-Go Decision

- ✅ **GO** if 95%+ of checks pass
- ⏸️ **HOLD** if <95%, document blockers
- ❌ **NO-GO** if critical failures

---

## Iteration 38 Tasks

### Task 1: Review All Documentation (2 hours)
- [ ] Read all 10 guides
- [ ] Check for completeness
- [ ] Verify consistency
- [ ] Create "Documentation Review Report"

### Task 2: Query Performance Testing (1 hour)
- [ ] Test fallback patterns (vector(0))
- [ ] Measure histogram_quantile performance
- [ ] Measure topk() filtering performance
- [ ] Create "Query Performance Report"

### Task 3: Dashboard Testing (2 hours)
- [ ] Test external links on 10 dashboards
- [ ] Test runbook links on 5 dashboards
- [ ] Test navigation elements
- [ ] Create "Dashboard Testing Report"

### Task 4: Alert Integration Testing (1 hour)
- [ ] Verify alert rules configured
- [ ] Test notification templates
- [ ] Fire test alert, verify flow
- [ ] Create "Alert Integration Report"

### Task 5: On-Call Workflow Simulation (1 hour)
- [ ] Run incident simulation
- [ ] Measure MTTR
- [ ] Verify runbook accuracy
- [ ] Create "On-Call Readiness Report"

### Task 6: Create Validation Summary (30 min)
- [ ] Consolidate all reports
- [ ] Go/No-Go decision
- [ ] Document any blockers
- [ ] Create deployment readiness assessment

---

## Success Criteria

| Area | Metric | Target | Status |
|------|--------|--------|--------|
| **Documentation** | % Complete | 100% | ? |
| **Query Performance** | Latency p95 | <200ms | ? |
| **Dashboard Load** | Time p95 | <2s | ? |
| **External Links** | % Working | 100% | ? |
| **Alert Panels** | % Functional | 100% | ? |
| **Runbook Links** | % Correct | 100% | ? |
| **MTTR** | Response Time | <15 min | ? |
| **Regression** | Perf Degradation | <10% | ? |

---

## Deployment Readiness

**Deploy to Production When:**
- ✅ All documentation complete & consistent
- ✅ Query performance validated
- ✅ Dashboard functionality 100%
- ✅ Alert integration tested
- ✅ On-call workflow simulated
- ✅ No critical blockers

**If Not Ready:**
- Document specific blockers
- Create follow-up tasks for Iteration 39+
- Identify root causes
- Plan fixes

---

## Post-Deployment Monitoring (Iteration 39)

After deployment, monitor:

```promql
# Query latency (should see improvement)
histogram_quantile(0.95, rate(vm_request_duration_seconds_bucket[5m]))

# Alert notification latency
histogram_quantile(0.95, rate(alertmanager_notification_latency_bucket[5m]))

# Dashboard load metrics
histogram_quantile(0.95, rate(grafana_dashboard_load_duration_seconds_bucket[5m]))

# On-call incident response time
rate(incidents_resolved_total[24h])
```

---

**Version:** 1.0
**Last Updated:** 2026-03-04 (Iteration 38)
**Status:** Validation framework ready
