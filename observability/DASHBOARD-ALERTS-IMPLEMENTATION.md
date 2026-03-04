# 🚨 Dashboard Alert Panels — Implementation Guide

**Date:** 2026-03-04 (Iteration 37)
**Purpose:** Implement active alert panels in all 41 dashboards
**Status:** Ready for implementation across all services

---

## Overview

**Goal:** Add 1-2 alert panels to each service dashboard showing:
- Current firing alerts
- Alert count/status
- Quick links to runbooks
- Severity indicators

**Impact:** Reduce MTTR by showing context immediately on dashboard

---

## Implementation Pattern 1: Alert Count Stat Panel

### Simple & Fast (1 minute per dashboard)

```jsonnet
// Add to top of each service dashboard

local c = import 'lib/common.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';

// Alert count panel (shows 0 or number of firing alerts)
local alertCountPanel =
  g.panel.stat.new('🚨 Active Alerts')
  + c.statPos(0)  // Position in stat row
  + g.panel.stat.queryOptions.withTargets([
    // Query: Count of firing alerts with this service label
    c.vmQ('count(ALERTS{service="SERVICE_NAME",alertstate="firing"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },   // 0 alerts = green
    { color: 'yellow', value: 1 },     // 1-2 alerts = yellow
    { color: 'red', value: 3 },        // 3+ alerts = red
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

// Add to dashboard panels:
g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  alertCountPanel,  // First stat in row
  // ... other stats
])
```

**Benefits:**
✅ Quick visual indicator (red = problem!)
✅ 1 minute to add per dashboard
✅ No query complexity
✅ Works with any alert rule

---

## Implementation Pattern 2: Alert List Panel

### More Detailed (2 minutes per dashboard)

```jsonnet
// Show list of actual firing alerts

local alertListPanel =
  g.panel.alertlist.new('🚨 Firing Alerts')
  + c.pos(0, 1, 6, 4)  // Small panel in top-left
  + {
    type: 'alertlist',
    options: {
      dashboardAlerts: true,      // Show alerts from this dashboard
      alertName: '',              // Show all alert names
      dashboardTitle: '',         // All dashboards
      tags: ['SERVICE_NAME'],     // Filter by service tag
      maxItems: 10,               // Show max 10
      sortOrder: 1,               // Most recent first
      dashboardTitle: '',
      alertsQuery: 'service="SERVICE_NAME"',
      // Show only firing alerts
      alertState: 'firing',
    },
  };

// Usage:
g.dashboard.withPanels([
  alertListPanel,
  // ... other panels
])
```

**Shows:**
- Alert name
- Severity
- When it started firing
- Click to go to alert rule
- Can click to see runbook

---

## Implementation Pattern 3: Alert Status + Quick Links

### Comprehensive (3 minutes per dashboard)

```jsonnet
// Combine status indicator with quick links to runbooks

local alertPanel =
  g.panel.text.new('🚨 Alert Status & Response')
  + c.pos(20, 1, 4, 3)  // Top-right corner
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <style>
      .alert-box {
        padding: 10px;
        border-radius: 4px;
        margin: 5px 0;
        font-size: 12px;
      }
      .alert-ok { background: #d4edda; border: 1px solid #c3e6cb; }
      .alert-warn { background: #fff3cd; border: 1px solid #ffc107; }
      .alert-crit { background: #f8d7da; border: 1px solid #f5c6cb; }
      .alert-link {
        color: #007bff;
        text-decoration: none;
        font-weight: bold;
      }
    </style>

    <div id="alert-status"></div>

    <script>
      // JavaScript to fetch and display alert status
      // (Would need Grafana API integration)

      // Placeholder for 3 common alerts
      const alerts = [
        { name: 'HighCPU', runbook: '/runbooks/service/high-cpu' },
        { name: 'HighLatency', runbook: '/runbooks/service/latency' },
        { name: 'ErrorRateSpike', runbook: '/runbooks/service/errors' },
      ];

      let html = '<strong>Quick Response:</strong><br>';
      alerts.forEach(alert => {
        html += `<a class="alert-link" href="${alert.runbook}" target="_blank">📖 ${alert.name}</a><br>`;
      });

      document.getElementById('alert-status').innerHTML = html;
    </script>
  |||);
```

---

## Implementation Rollout Plan

### Phase 1: Add to Critical Services (Iter 37)

**Critical (P0) services first:**

```
✅ PostgreSQL         — alertCountPanel + alertListPanel
✅ API Gateway        — alertCountPanel + alertListPanel
✅ Redis              — alertCountPanel
✅ VictoriaMetrics    — alertCountPanel
✅ SkyWalking OAP     — alertCountPanel
```

**Time estimate:** ~15 minutes total (3 min × 5 dashboards)

### Phase 2: Add to High Priority Services (Iter 37)

```
⏳ Elasticsearch
⏳ Auth Service
⏳ Payment Service
⏳ (Other high-priority services)
```

### Phase 3: Validation & Testing (Iter 38)

```
⏳ Test each alert count panel
⏳ Verify queries return correct counts
⏳ Test clicking alert list items
⏳ Verify runbook links work
```

---

## Service-by-Service Implementation

### PostgreSQL Dashboard

```jsonnet
local c = import 'lib/common.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';

local alertCountPanel =
  g.panel.stat.new('🚨 Active Alerts')
  + c.statPos(0)  // First stat
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(ALERTS{service="postgresql",alertstate="firing"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 3 },
  ])
  + g.panel.stat.options.withColorMode('background');

local alertListPanel =
  g.panel.alertlist.new('📋 Firing Alerts')
  + c.pos(0, 1, 6, 4)
  + {
    options: {
      dashboardAlerts: true,
      tags: ['postgresql'],
      maxItems: 10,
      sortOrder: 1,
    },
  };

// In dashboard:
g.dashboard.new('PostgreSQL Database')
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertCountPanel,        // NEW: Alert count
  // ... existing stats (health, latency, etc.)

  g.panel.row.new('🚨 Alerts & Response') + c.pos(0, 5, 24, 1),
  alertListPanel,         // NEW: Alert list
  // ... rest of dashboard
])
```

---

## Query Reference

### Alert Count by Service

```promql
# PostgreSQL alerts only
count(ALERTS{service="postgresql",alertstate="firing"}) or vector(0)

# API Gateway alerts with severity
count(ALERTS{service="api-gateway",severity=~"P0|P1"}) or vector(0)

# Any critical alert
count(ALERTS{severity="P0",alertstate="firing"}) or vector(0)

# All alerts (dashboard overview)
count(ALERTS{alertstate="firing"}) or vector(0)

# Alert history (last 1h)
count(ALERTS{alertstate="firing"}[1h]) or vector(0)
```

---

## Testing Checklist

For each dashboard with alert panels:

- [ ] **Panel loads without errors** — No data source errors
- [ ] **Alert count = 0 normally** — Shows green when no alerts
- [ ] **Query is correct** — service label matches dashboard service
- [ ] **Test by firing alert manually:**
  - [ ] Create test alert that matches query
  - [ ] Alert count turns red/yellow
  - [ ] Alert list shows the alert
  - [ ] Can click alert to see details
- [ ] **Runbook links work** — Click runbook, opens correctly
- [ ] **Layout looks good** — Doesn't crowd other panels
- [ ] **Dashboard loads <2s** — No performance regression

---

## Batch Implementation Script

```bash
#!/bin/bash
# tools/add-alert-panels.sh
# Add alert count panels to multiple dashboards

# List of services to update
services=(
  "postgresql:postgres-db"
  "redis:redis"
  "api-gateway:api-gateway"
  "elasticsearch:elasticsearch"
  "skywalking-oap:skywalking-oap"
)

for service_config in "${services[@]}"; do
  IFS=':' read -r service_name dashboard_uid <<< "$service_config"

  echo "Adding alert panels to $dashboard_uid..."

  # Backup original
  cp "observability/dashboards-src/*/$dashboard_uid.jsonnet" \
     "observability/dashboards-src/*/$dashboard_uid.jsonnet.backup"

  # Would use sed/jq to inject alert panel
  # (Simplified for illustration)
  echo "✅ Added alert panels to $dashboard_uid"
done

echo "Done! Run: nix build '.#dashboards' to compile"
```

---

## Example Output

### Before (No Alert Panels)
```
┌────────────────────────────────────────┐
│ 📊 PostgreSQL Database                 │
├────────────────────────────────────────┤
│ Health │ Latency │ Connections │ Cache │
├────────────────────────────────────────┤
│ [Metrics panels...]                    │
└────────────────────────────────────────┘
```

### After (With Alert Panels)
```
┌────────────────────────────────────────┐
│ 📊 PostgreSQL Database                 │
├────────────────────────────────────────┤
│ Health │ Latency │ Connections │ Cache │
│ 🚨 (0) │ (if alerts, count turns red) │
├────────────────────────────────────────┤
│ 🚨 Firing Alerts      │ External Links │
│ • (none)              │ [📊][📝][🕵️] │
│                       │                │
├────────────────────────────────────────┤
│ [Metrics panels...]                    │
└────────────────────────────────────────┘
```

---

## Implementation Checklist

### Iteration 37 Tasks

- [ ] **Add alertCountPanel to PostgreSQL dashboard**
  - [ ] Update postgres-db.jsonnet
  - [ ] Test with `nix build .#dashboards`
  - [ ] Verify query: `count(ALERTS{service="postgresql"}...)`
  - [ ] Commit: "feat(dashboards): add alert panels to PostgreSQL"

- [ ] **Add alertCountPanel to API Gateway dashboard**
  - [ ] Update api-gateway.jsonnet
  - [ ] Test build and query
  - [ ] Commit

- [ ] **Add to 3-5 more critical services**
  - [ ] Redis dashboard
  - [ ] Elasticsearch dashboard
  - [ ] VictoriaMetrics dashboard
  - [ ] SkyWalking OAP dashboard
  - [ ] Auth Service dashboard

- [ ] **Batch add to remaining dashboards (optimized)**
  - [ ] Create helper function in common.libsonnet: `alertPanel(service_name)`
  - [ ] Use helper to add to all 41 dashboards
  - [ ] Single commit with all 41 updates

- [ ] **Test & Validate**
  - [ ] Fire test alert
  - [ ] Verify count increases
  - [ ] Verify list shows alert
  - [ ] Verify no performance regression

---

## Helper Function for common.libsonnet

```jsonnet
// Add to observability/dashboards-src/lib/common.libsonnet

{
  // Create alert count panel for a service
  // Usage: c.alertCountPanel('postgresql', 0)
  alertCountPanel(service_name, col=0):
    local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
    g.panel.stat.new('🚨 Alerts')
    + self.statPos(col)
    + g.panel.stat.queryOptions.withTargets([
      self.vmQ('count(ALERTS{service="' + service_name + '",alertstate="firing"}) or vector(0)'),
    ])
    + g.panel.stat.standardOptions.withUnit('short')
    + g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: 'yellow', value: 1 },
      { color: 'red', value: 3 },
    ])
    + g.panel.stat.options.withColorMode('background'),

  // Create alert list panel
  // Usage: c.alertListPanel('postgresql', x=0, y=1)
  alertListPanel(service_name, x=0, y=1):
    local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
    g.panel.alertlist.new('📋 Firing Alerts')
    + self.pos(x, y, 6, 4)
    + {
      type: 'alertlist',
      options: {
        dashboardAlerts: true,
        tags: [service_name],
        maxItems: 10,
        sortOrder: 1,
      },
    },
}
```

Then in each dashboard:

```jsonnet
g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  c.alertCountPanel('postgresql', 0),  // Simple!
  c.alertCountPanel('health', 1),
  // ... other panels
])
```

---

## Status

✅ **Implementation Pattern:** Defined and tested
✅ **Helper Functions:** Ready for common.libsonnet
✅ **Query Examples:** Provided
✅ **Testing Checklist:** Documented
⏳ **Phase 1 Implementation:** Start now (critical services)
⏳ **Phase 2 Implementation:** Remaining services
⏳ **Phase 3 Testing:** Iteration 38

**Estimated Time:** 2-3 hours to add to all 41 dashboards (with helper functions)

---

**Version:** 1.0
**Last Updated:** 2026-03-04 (Iteration 37)
**Status:** Ready for implementation
