# 🚨 Alert Integration & Incident Response Guide

**Date:** 2026-03-04 (Iteration 36)
**Purpose:** Integrate alerting with dashboards for faster incident response
**Audience:** On-call engineers, SREs, alert owners

---

## Overview

**Problem:**
- Alerts fire, but on-call engineer doesn't know which dashboard to check
- No context linking alerts → dashboards → runbooks
- Alert fatigue from unclear severity/priority
- Slow incident response due to lack of context

**Solution:** Three-level alert integration:
1. **Alert → Dashboard Links** — Alerts direct to relevant dashboard
2. **Dashboard → Active Alerts Panel** — Show current alerts on dashboard
3. **Alert → Runbook Links** — Every alert links to runbook

---

## Level 1: Alert Rules with Dashboard Links

### Pattern: Grafana Alert Rule with Dashboard Annotation

```yaml
# In Grafana Alerting (Unified Alerting):

groups:
  - name: postgresql_alerts
    interval: 1m
    rules:
      - alert: PostgreSQLHighCPU
        expr: rate(postgresql_cpu_seconds_total[5m]) > 0.8
        for: 5m
        labels:
          severity: "warning"
          service: "postgresql"
          tier: "critical"
        annotations:
          summary: "PostgreSQL high CPU usage"
          description: "CPU usage is {{ $value }}% for more than 5 minutes"
          # Key: Link to dashboard
          dashboard_url: "https://home.pin/d/postgres-db"
          dashboard_panel: "CPU Usage"
          # Link to runbook
          runbook_url: "https://wiki.pin/runbooks/postgresql/high-cpu"
          # Alert tier
          alert_tier: "P1"
          alert_impact: "Database queries may slow down"
```

### In Grafana UI:

1. **Create/Edit Alert Rule**
2. **Add Annotations:**
   ```
   dashboard_url: /d/postgres-db
   runbook_url: https://wiki.pin/runbooks/postgresql/high-cpu
   ```
3. **Set Labels:**
   ```
   severity: warning/critical
   service: postgresql
   ```
4. **Configure Notification:**
   - Use template to include dashboard link
   - Show in Slack/Email/PagerDuty

---

## Level 2: Active Alerts Panel in Dashboard

### Pattern: Show Current Alerts on Dashboard

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Panel showing current alerts for this service
local activeAlertsPanel =
  g.panel.alertlist.new('🚨 Active Alerts for PostgreSQL')
  + c.pos(0, 1, 6, 3)
  + {
    options: {
      dashboardAlerts: true,  // Show alerts from this dashboard
      alertName: '',           // Show all alerts (or filter by name)
      dashboardTitle: '',      // Show all dashboards (or filter)
      tags: ['postgresql'],    // Only alerts with this tag
      maxItems: 10,            // Show top 10 alerts
      sortOrder: 1,            // Sort by most recent
      currentAlertState: 'firing',  // Show only firing alerts
    },
    targets: [],
  };

// Alternative: Alert stats
local alertStatPanel =
  g.panel.stat.new('⚠️ Alert Count')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    // Query: Count of firing alerts for this service
    c.vmQ('count(ALERTS{service="postgresql",alertstate="firing"})'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 3 },
  ])
  + g.panel.stat.options.withColorMode('background');

// Add to dashboard:
g.dashboard.new('PostgreSQL')
+ g.dashboard.withPanels([
  g.panel.row.new('🚨 Alert Status') + c.pos(0, 0, 24, 1),
  activeAlertsPanel,
  alertStatPanel,
  // ... rest of dashboard
])
```

### Benefits

✅ **Immediate Context:** On-call sees active alerts right on dashboard
✅ **Visual Warning:** Alert count = red when critical issues present
✅ **Quick Action:** Click alert → see runbook link
✅ **Reduce MTTR:** Faster incident response

---

## Level 3: Alert Routing & Escalation

### Pattern: Alert Severity Tiers

Define clear severity levels with actions:

```
CRITICAL (P0) — Page on-call immediately
├─ Impact: Service down or degraded
├─ MTTR Target: <5 minutes
├─ Action: Incident commander called
└─ Runbook: Critical troubleshooting path

HIGH (P1) — Alert on-call, escalate if not resolved in 15min
├─ Impact: Performance or availability affected
├─ MTTR Target: <15 minutes
├─ Action: On-call investigates
└─ Runbook: Standard troubleshooting

MEDIUM (P2) — Log alert, review next morning
├─ Impact: Minor issues or warnings
├─ MTTR Target: <1 hour or next business day
├─ Action: Assigned to team
└─ Runbook: Optional

LOW (P3) — Info only
├─ Impact: No customer impact
├─ MTTR Target: None (backlog)
├─ Action: None
└─ Runbook: None
```

### Alert Configuration (Example)

```yaml
# alerts.yaml configuration for different services

postgresql_alerts:
  HighCPU:
    severity: "P1"  # High but not critical
    message: "PostgreSQL CPU > 80%"
    dashboard: /d/postgres-db
    runbook: postgresql/high-cpu
    escalation: "page on-call if >30min"

  ConnectionPoolExhausted:
    severity: "P0"  # Critical - connections needed immediately
    message: "PostgreSQL connection pool exhausted"
    dashboard: /d/postgres-db
    runbook: postgresql/conn-pool
    escalation: "page immediately"

  ReplicationLag:
    severity: "P1"  # High priority but not immediate
    message: "PostgreSQL replication lag > 60s"
    dashboard: /d/postgres-replication
    runbook: postgresql/replication
    escalation: "page if >5min lag"

api_gateway_alerts:
  HighLatency:
    severity: "P0"  # Critical - directly impacts customers
    message: "API Gateway latency > 500ms"
    dashboard: /d/api-gateway
    runbook: api-gateway/latency
    escalation: "page immediately"

  ErrorRateSpike:
    severity: "P0"  # Critical - customers affected
    message: "API error rate > 5%"
    dashboard: /d/api-gateway
    runbook: api-gateway/errors
    escalation: "page immediately"

redis_alerts:
  HighMemoryUsage:
    severity: "P1"  # High but usually fixable
    message: "Redis memory > 85%"
    dashboard: /d/redis
    runbook: redis/memory-pressure
    escalation: "escalate after 10min"

  EvictionRate:
    severity: "P2"  # Medium - monitor but not urgent
    message: "Redis eviction rate high"
    dashboard: /d/redis
    runbook: redis/eviction
    escalation: "review next morning"
```

---

## Alert Notification Template

### Slack Alert Template

```
{{ if eq .Status "firing" }}
🚨 **ALERT: {{ .Alerts.Firing | len }} Active**
{{ else }}
✅ **RESOLVED:** {{ .Alerts.Resolved | len }} Alerts Resolved
{{ end }}

{{ range .Alerts.Firing }}
**Alert:** {{ .Labels.alertname }}
**Severity:** {{ .Labels.severity }}
**Service:** {{ .Labels.service }}
**Message:** {{ .Annotations.description }}

🎯 **Response Steps:**
1. [📊 Dashboard]({{ .Annotations.dashboard_url }}) — View context
2. [📖 Runbook]({{ .Annotations.runbook_url }}) — Follow troubleshooting
3. [📝 Logs](/explore?query=service:"{{ .Labels.service }}"&datasource=VictoriaLogs) — Check logs
4. [🔗 Dependencies](/d/service-dependencies) — See dependent services

{{ end }}
```

### Email Alert Template

```
Subject: 🚨 {{ .GroupLabels.service }} Alert — {{ .Alerts.Firing | len }} Active

---

{{ range .Alerts.Firing }}
{{ .Labels.alertname }} ({{ .Labels.severity }})
{{ .Annotations.description }}

Dashboard: {{ .Annotations.dashboard_url }}
Runbook: {{ .Annotations.runbook_url }}
Time: {{ .StartsAt }}

---
{{ end }}

On-Call: See dashboard link above to begin incident response.
```

---

## Incident Response Workflow

### Step 1: Alert Fires
```
🚨 Alert in Slack/Email
  ↓
User sees dashboard link in notification
User sees runbook link in notification
User sees severity level
```

### Step 2: Open Dashboard
```
📊 Click dashboard link
  ↓
See active alerts panel (red!)
See related metrics for the issue
See breadcrumb to related dashboards
```

### Step 3: Follow Runbook
```
📖 Click runbook link
  ↓
Read symptoms (confirms this is the issue)
Follow investigation steps (with dashboard screenshots)
Click links to specific dashboard panels
Execute remediation steps
```

### Step 4: Monitor Resolution
```
✅ Keep dashboard open
  ↓
Watch alert status panel change from red to green
Watch key metrics return to normal
See alert resolved notification
```

### Step 5: Post-Incident
```
📝 Update runbook if new learnings
📝 Create incident report
📝 Update SERVICE-REGISTRY.yaml with findings
📝 Adjust alert thresholds if needed
```

---

## Alert Management Best Practices

### For Alert Owners

1. **Clear Naming:** `ServiceName_MetricType_Condition`
   - ✅ `PostgreSQL_HighCPU`
   - ✅ `APIGateway_HighLatency`
   - ❌ `high_cpu` (unclear which service)

2. **Meaningful Thresholds:** Test before deploying
   - Too low: Alert fatigue
   - Too high: Incidents before alert fires

3. **Always Link Runbook:** Every alert needs troubleshooting guide

4. **Always Link Dashboard:** Context matters in incident response

5. **Set Appropriate `for:` Duration:**
   - Critical (P0): `for: 1m` (immediate)
   - High (P1): `for: 5m` (allow transient issues to pass)
   - Medium (P2): `for: 15m` (lower noise)

### For On-Call Engineers

1. **Check Dashboard First:** Before opening Slack, check dashboard
2. **Follow Runbook:** Don't improvise; follow documented steps
3. **Communicate:** Update Slack as you investigate
4. **Escalate Early:** If unsure after 5 min, call expert
5. **Document:** Add findings to runbook post-incident

### For Teams

1. **Review Alerts Quarterly:** Tune thresholds based on false positives
2. **Run Drills:** Simulate incidents to test runbooks
3. **Update Runbooks:** After every real incident
4. **Track MTTR:** Measure time from alert to resolution
5. **Celebrate:** Recognize fast incident response

---

## Alert Best Practices Summary

| Practice | Benefit | Cost |
|----------|---------|------|
| **Link dashboard** | Context immediately available | +1 field per alert |
| **Link runbook** | Know what to do | Need runbook written |
| **Set severity** | Proper escalation | Requires thought |
| **Group alerts** | Reduce noise | More config |
| **Set `for:` duration** | Avoid flaps | Slower detection |
| **Test before deploy** | Tune thresholds | Extra effort |

---

## Implementation Checklist

### Phase 1: Alert Rule Updates (This Iteration)
- [ ] Identify all critical alerts (P0)
- [ ] Add dashboard_url annotation to each
- [ ] Add runbook_url annotation to each
- [ ] Set severity labels (P0, P1, P2, P3)
- [ ] Set service labels (postgresql, redis, api-gateway, etc.)

### Phase 2: Dashboard Integration (Iteration 37)
- [ ] Add active alerts panel to each service dashboard
- [ ] Add alert count stat panels
- [ ] Link to incident response guide

### Phase 3: Notification Templates (Iteration 37)
- [ ] Create Slack notification templates
- [ ] Create email notification templates
- [ ] Configure routing by severity + service

### Phase 4: Testing & Tuning (Iteration 38)
- [ ] Test each alert (trigger manually)
- [ ] Verify dashboard link works
- [ ] Verify runbook link works
- [ ] Run incident response drill

---

## Example: Complete Alert Configuration

```yaml
# Full alert rule with all annotations

groups:
  - name: observability_alerts
    interval: 1m
    rules:

      # Critical: PostgreSQL connection pool exhaustion
      - alert: PostgreSQLConnectionPoolExhausted
        expr: pg_stat_activity_count > 95
        for: 1m  # Page immediately
        labels:
          severity: "P0"
          service: "postgresql"
          tier: "critical"
          team: "platform"
        annotations:
          summary: "PostgreSQL connection pool exhausted"
          description: |
            PostgreSQL connection pool at {{ $value }}/100 connections.
            New connections will be refused. Immediate action required.
          dashboard_url: "https://home.pin/d/postgres-db"
          dashboard_panel: "Active Connections"
          runbook_url: "https://wiki.pin/runbooks/postgresql/conn-pool"
          runbook_section: "Emergency: Connection Pool Exhausted"
          alert_impact: "Applications cannot connect to database"
          escalation_path: "on-call → DBA → platform-team lead"
          tags: "critical,database,production"

      # High: API Gateway latency spike
      - alert: APIGatewayHighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
        for: 5m  # Allow brief spikes to pass
        labels:
          severity: "P0"
          service: "api-gateway"
          tier: "critical"
          team: "backend"
        annotations:
          summary: "API Gateway latency spike ({{ $value }}ms)"
          description: |
            API Gateway p95 latency is {{ $value }}ms (target: <500ms).
            Request processing is slow. Investigate downstream services.
          dashboard_url: "https://home.pin/d/api-gateway"
          dashboard_panel: "Latency Percentiles"
          runbook_url: "https://wiki.pin/runbooks/api-gateway/latency"
          related_dashboards: |
            - [Service Dependencies](/d/service-dependencies)
            - [Database Performance](/d/postgres-perf)
            - [Cache Performance](/d/redis)
          escalation_path: "on-call → backend-team → incident-commander"
          tags: "critical,api,customer-facing"

      # Medium: Redis memory pressure (not immediate)
      - alert: RedisMemoryPressure
        expr: redis_memory_used_bytes / redis_memory_max_bytes > 0.85
        for: 15m  # Give time to investigate naturally
        labels:
          severity: "P2"
          service: "redis"
          tier: "high"
          team: "platform"
        annotations:
          summary: "Redis memory usage high ({{ $value | humanizePercentage }})"
          description: |
            Redis memory at {{ $value | humanizePercentage }} of max.
            Monitor for eviction rate. Plan capacity soon.
          dashboard_url: "https://home.pin/d/redis"
          dashboard_panel: "Memory Usage"
          runbook_url: "https://wiki.pin/runbooks/redis/memory-pressure"
          escalation_path: "log only, review during business hours"
          tags: "cache,infrastructure"
```

---

## Status

✅ **Alert Configuration Pattern:** Documented
✅ **Notification Templates:** Provided (Slack, Email)
✅ **Best Practices:** Defined
✅ **Implementation Checklist:** Ready
⏳ **Dashboard Integration:** Next iteration
⏳ **Testing & Validation:** Iteration 38

---

**Version:** 1.0
**Last Updated:** 2026-03-04 (Iteration 36)
**Owner:** Observability & On-Call Teams
**Status:** Implementation guide ready
