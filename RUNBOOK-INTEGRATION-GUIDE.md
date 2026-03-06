# 📖 Runbook Integration & On-Call Guide

**Date:** 2026-03-04 (Iteration 33)
**Purpose:** Integrate operational runbooks into dashboards for faster incident response
**Audience:** On-call engineers, SREs, incident commanders

---

## Overview

**Problem:** When an alert fires, on-call engineers need runbooks quickly
- Current: Open Slack/wiki separately, search for runbook
- Desired: Runbooks embedded in dashboard or quick-linked from alert

**Solution:** Multi-level integration:
1. **Dashboard-level runbooks** — In dashboard description/panels
2. **Panel-level runbooks** — In panel titles or descriptions
3. **Alert-linked runbooks** — From Grafana alerts to runbook URLs
4. **Quick-access runbooks** — In dashboard corner buttons

---

## Level 1: Dashboard-Level Runbooks

### Pattern: Dashboard Description with Runbook

In your dashboard Jsonnet:

```jsonnet
g.dashboard.new('PostgreSQL Database')
+ g.dashboard.withUid('postgres-db')
+ g.dashboard.withDescription(|||
  PostgreSQL monitoring and performance dashboard.

  **Quick Links:**
  - [🔧 Troubleshooting Runbook](https://wiki.pin/runbooks/postgresql/troubleshooting)
  - [🚨 High CPU Investigation](https://wiki.pin/runbooks/postgresql/high-cpu)
  - [🔴 Connection Exhaustion](https://wiki.pin/runbooks/postgresql/conn-pool)
  - [📊 Query Optimization](https://wiki.pin/runbooks/postgresql/query-tuning)

  **On-Call Procedure:**
  1. Check Overall Health section (top left)
  2. If red, check Slow Queries table for blocking queries
  3. See runbooks above for specific issues
  4. Escalate to DBA if needed
|||)
+ g.dashboard.withTags(['postgresql', 'database', 'critical'])
+ c.dashboardDefaults
```

**Benefits:**
- ✅ Visible to all dashboard users
- ✅ Searchable (appears in Grafana search)
- ✅ Accessible from dashboard home page
- ✅ No code changes to update

---

## Level 2: Panel-Level Runbooks

### Pattern: Runbook Links in Panel Title

```jsonnet
local highConnectivityPanel =
  g.panel.stat.new('Active Connections')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(pg_stat_activity) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 80 },
    { color: 'red', value: 100 },
  ])
  + g.panel.stat.options.withColorMode('background');
```

Add runbook context to panel description:

```jsonnet
// In Grafana UI: Edit panel → Panel options → Description
// Add: "If red, check [Connection Exhaustion Runbook](https://wiki.pin/runbooks/postgresql/conn-pool)"

// Or via Jsonnet (if grafonnet supports panel descriptions):
// (Unfortunately grafonnet doesn't expose panel descriptions easily)
```

### Pattern: Markdown Panel with Runbooks

For complex dashboards, add a "Troubleshooting" panel:

```jsonnet
local troubleshootingPanel =
  g.panel.text.new('🔧 Troubleshooting Guide')
  + c.pos(0, 20, 24, 5)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ## Common Issues & Solutions

    **Issue: High CPU Usage**
    - Check Slow Queries panel (top right)
    - If query is long-running, consider terminating or optimizing
    - → [Full Runbook](https://wiki.pin/runbooks/postgresql/high-cpu)

    **Issue: Connection Pool Exhausted**
    - Check Active Connections stat (yellow or red)
    - Check Client Connections by App table for misbehaving app
    - → [Connection Pool Runbook](https://wiki.pin/runbooks/postgresql/conn-pool)

    **Issue: Memory Usage High**
    - Check table sizes in System Metrics panel
    - Consider vacuuming large tables
    - → [Memory Management Runbook](https://wiki.pin/runbooks/postgresql/memory)

    **Issue: Replication Lag**
    - Check Replication Status panel (second row)
    - If >60s, check replica logs for errors
    - → [Replication Runbook](https://wiki.pin/runbooks/postgresql/replication)
  |||);
```

**Benefits:**
- ✅ Multiple runbooks visible in one place
- ✅ Can include symptoms and diagnosis steps
- ✅ Easy to update (edit markdown)
- ✅ Space for longer explanations

---

## Level 3: Alert-Linked Runbooks

### Pattern: Alert with Runbook URL

In Grafana Alerting (Unified Alerting):

1. **Create Alert Rule:**
   - Query: `count(pg_stat_activity) > 100`
   - Annotations → Add custom annotation

2. **Add Runbook Annotation:**
   ```
   runbook_url = "https://wiki.pin/runbooks/postgresql/conn-pool"
   ```

3. **In Alertmanager:**
   - Configure notification to include `{{ .Annotations.runbook_url }}`
   - Example Slack template:
   ```
   {{ if .Annotations.runbook_url }}
   [📖 Runbook]({{ .Annotations.runbook_url }})
   {{ end }}
   ```

### Pattern: Common Runbook URL Scheme

Standardize runbook URLs for consistency:

```
https://wiki.pin/runbooks/{service}/{specific-issue}

Examples:
https://wiki.pin/runbooks/postgresql/high-cpu
https://wiki.pin/runbooks/redis/memory-pressure
https://wiki.pin/runbooks/elasticsearch/disk-full
https://wiki.pin/runbooks/api-gateway/latency-spike
```

---

## Level 4: Quick-Access Runbook Buttons

### Pattern: Runbook Panel in Dashboard Corner

```jsonnet
// Add to dashboard alongside external links panel
local runbookPanel =
  g.panel.text.new('')
  + c.pos(20, 1, 2, 1)  // Left of external links (pos 22)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <style>
      .runbook-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 24px;
        height: 24px;
        background: #7c2d12;  /* Orange-brown */
        color: white;
        text-decoration: none;
        border-radius: 4px;
        font-size: 12px;
        font-weight: bold;
        cursor: pointer;
        margin: 2px;
        transition: all 0.2s;
        border: 1px solid #5a1e0a;
      }
      .runbook-btn:hover {
        background: #9a3a15;
        transform: scale(1.1);
        box-shadow: 0 2px 6px rgba(220, 38, 38, 0.4);
      }
      .runbook-container { display: flex; gap: 4px; }
    </style>
    <div class="runbook-container">
      <a class="runbook-btn" href="https://wiki.pin/runbooks/postgresql/troubleshooting" target="_blank" title="Main Runbook">📖</a>
      <a class="runbook-btn" href="https://wiki.pin/runbooks/postgresql/high-cpu" target="_blank" title="High CPU Runbook">⚡</a>
      <a class="runbook-btn" href="https://wiki.pin/runbooks/postgresql/conn-pool" target="_blank" title="Connection Pool Runbook">🔴</a>
    </div>
  |||);

// Use in dashboard:
g.dashboard.new('PostgreSQL').withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  runbookPanel,  // Left corner (pos 20)
  c.externalLinksPanel(),  // Right corner (pos 22)
  // ... other panels
])
```

**Advantages:**
- ✅ Always visible in top-right corner
- ✅ Multiple runbooks quickly accessible
- ✅ Consistent with external links design
- ✅ Color-coded (orange) to distinguish from metrics links

---

## Runbook Structure & Content

### Recommended Runbook Template

```markdown
# [Service Name] — [Issue]

**Last Updated:** 2026-03-04
**Severity:** Critical/High/Medium
**Estimated Time:** 15-30 minutes

## Symptoms

What does this issue look like?
- Symptom 1: ...
- Symptom 2: ...

## Root Cause

Why does this happen?
- Cause explanation
- Common triggers

## Investigation Steps

1. Check metric X in [dashboard link]
   - Expected value: Y
   - If actual > Z: proceed to step 2

2. Check logs
   ```bash
   # Query logs for errors:
   grep "ERROR" /var/log/service.log
   ```

3. Check system resources
   - CPU usage (acceptable < 80%)
   - Memory usage (acceptable < 85%)
   - Disk space (acceptable > 10% free)

## Remediation

### Quick Fix (temporary)
- Option 1: ...
- Option 2: ...

### Permanent Fix
- Long-term solution
- Configuration changes needed
- Deployment steps

## Escalation

If issue persists after 10 minutes:
1. Page: [Team Slack channel] or [PagerDuty]
2. Prepare:
   - Screenshots of metrics
   - Relevant log excerpts
   - Timeline of when issue started

## Related Dashboards

- [Database Health](/d/postgres-health)
- [Performance Analysis](/d/postgres-performance)
- [Replication Status](/d/postgres-replication)

## Historical Context

- Previous incidents: [link to incident report]
- Known issues: [link to tracking issue]

## References

- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [Connection Pool Guide](https://wiki.pin/guides/connection-pooling)
```

---

## Integration Examples

### Example 1: PostgreSQL Database Dashboard

```jsonnet
local c = import 'lib/common.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';

// Runbook quick-access
local runbookPanel = c.customExternalLinksPanel([
  { icon: '📖', title: 'Main', url: 'https://wiki.pin/runbooks/postgresql/troubleshooting' },
  { icon: '⚡', title: 'CPU', url: 'https://wiki.pin/runbooks/postgresql/high-cpu' },
  { icon: '🔴', title: 'Conn', url: 'https://wiki.pin/runbooks/postgresql/conn-pool' },
], y=1, x=20);  // Position: left of external links

g.dashboard.new('PostgreSQL')
+ g.dashboard.withUid('postgres-db')
+ g.dashboard.withDescription(|||
  PostgreSQL monitoring dashboard.

  **On-Call Quick Start:**
  1. Check Overall Health (top row)
  2. If red, click runbook button (📖) in top-left corner
  3. Follow steps for your issue
  4. Check Slow Queries table (left side)

  **Key Runbooks:**
  - [Main Troubleshooting](https://wiki.pin/runbooks/postgresql/troubleshooting)
  - [High CPU](https://wiki.pin/runbooks/postgresql/high-cpu)
  - [Connection Issues](https://wiki.pin/runbooks/postgresql/conn-pool)
|||)
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  runbookPanel,
  c.externalLinksPanel(),
  // ... stats panels
]);
```

### Example 2: API Gateway Dashboard

```jsonnet
// Runbooks for latency, errors, circuit breaker
local runbookLinks = c.customExternalLinksPanel([
  { icon: '📖', title: 'Troubleshooting', url: 'https://wiki.pin/runbooks/api-gateway/main' },
  { icon: '🐌', title: 'Latency', url: 'https://wiki.pin/runbooks/api-gateway/latency' },
  { icon: '❌', title: 'Errors', url: 'https://wiki.pin/runbooks/api-gateway/errors' },
  { icon: '🛑', title: 'Circuit', url: 'https://wiki.pin/runbooks/api-gateway/circuit-breaker' },
], y=1, x=20);

// Troubleshooting guide panel
local troubleshootingPanel =
  g.panel.text.new('🔧 When to Use Which Runbook')
  + c.pos(0, 20, 24, 4)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Symptom | Runbook | Check |
    |---------|---------|-------|
    | **High latency (>500ms)** | [Latency](https://wiki.pin/runbooks/api-gateway/latency) | Downstream service health |
    | **Errors spiking** | [Errors](https://wiki.pin/runbooks/api-gateway/errors) | Error type in logs |
    | **Circuit breaker open** | [Circuit](https://wiki.pin/runbooks/api-gateway/circuit-breaker) | Dependent service status |
    | **Requests timing out** | [Latency](https://wiki.pin/runbooks/api-gateway/latency) | Database query performance |
  |||);

// Use in dashboard:
g.dashboard.withPanels([
  runbookLinks,
  troubleshootingPanel,
  // ... other panels
])
```

---

## Best Practices

### For Dashboard Developers

1. **Always include runbooks** in dashboard description
2. **Link to multiple runbooks** (main + specific issues)
3. **Test links** — verify they resolve and are current
4. **Update quarterly** — sync runbook URLs with wiki structure
5. **Use consistent naming** — `https://wiki.pin/runbooks/{service}/{issue}`

### For On-Call Engineers

1. **Favorite key dashboards** — bookmark in Grafana
2. **Skim runbooks** — 2 minutes to understand issue
3. **Follow investigation steps** — check metrics mentioned in runbooks
4. **Escalate early** — if unsure after 5 minutes, page expert
5. **Document** — add to runbook "Previous Incidents" section

### For Runbook Writers

1. **Keep it actionable** — steps that can be taken immediately
2. **Include timeframes** — how long should each step take?
3. **Add dashboards links** — direct to relevant Grafana dashboards
4. **Update after incidents** — add new findings to runbook
5. **Remove solved issues** — if a problem is fixed, update/remove

---

## Implementation Checklist

For each critical service:

- [ ] **Main Runbook Created** — Troubleshooting guide exists at wiki
- [ ] **Issue-Specific Runbooks** — 2-3 runbooks for common issues
- [ ] **Dashboard Linked** — Dashboard description has runbook links
- [ ] **Quick-Access Buttons** — Runbook panel in dashboard corner
- [ ] **Alerts Configured** — Alert rules include runbook_url annotation
- [ ] **Team Trained** — On-call team knows where to find runbooks
- [ ] **Tested in Incident** — Runbook was useful in actual incident
- [ ] **Reviewed Quarterly** — Content is still accurate

---

## Tools & Resources

### Runbook Storage Options
1. **Wiki.pin** (Recommended) — Centralized, searchable, versionable
2. **GitHub** — Markdown files, version history, review process
3. **Notion** — Rich formatting, team collaboration, databases

### Runbook Search Integration
```promql
# Future: Create Grafana plugin to search runbooks from dashboard
# Current: Manual links in dashboard descriptions
```

### Alert Integration
```yaml
# Alertmanager example configuration
templates:
  - alert: HighCPU
    annotations:
      runbook_url: "https://wiki.pin/runbooks/system/high-cpu"
      # Grafana uses this in notifications
```

---

## Status

✅ **Concept & Integration Patterns:** Defined
✅ **Dashboard Examples:** Multiple examples provided
✅ **Runbook Templates:** Structure documented
⏳ **Wiki Integration:** (Teams configure locally)
⏳ **Runbook Library:** (Teams create per service)

---

**Version:** 1.0
**Last Updated:** 2026-03-04 (Iteration 33)
**Owner:** Observability & On-Call Teams
**Status:** Ready for implementation
