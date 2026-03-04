# 🧭 Dashboard Navigation & Service Catalog Guide

**Date:** 2026-03-04 (Iteration 35)
**Purpose:** Improve dashboard discoverability and navigation
**Status:** Implementation guide ready

---

## Overview

**Problem:**
- 41 dashboards: how do users find what they need?
- Relationships between dashboards aren't clear
- No central service catalog
- No breadcrumb navigation

**Solution:** Multi-level navigation system:
1. **Service Catalog Dashboard** — Index of all services
2. **Breadcrumb Navigation** — Show current location and related dashboards
3. **Dashboard Linking** — Direct links between related dashboards
4. **Search & Tags** — Grafana tagging strategy

---

## Level 1: Service Catalog Dashboard

### Structure

```
┌─────────────────────────────────────────────────────────────┐
│                   📚 Service Catalog                         │
│            Quick Access to All Monitored Services            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🔴 CRITICAL SERVICES (Tier 1)                               │
├─────────────────────────────────────────────────────────────┤
│ PostgreSQL  │ API Gateway  │ Payment Service │ Redis (Tier2)│
│ /d/postgres │ /d/api-gw    │ /d/payment      │ /d/redis     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🟡 HIGH PRIORITY SERVICES (Tier 2)                          │
├─────────────────────────────────────────────────────────────┤
│ Elasticsearch │ SkyWalking OAP │ VictoriaMetrics │ Vector    │
│ /d/elastic    │ /d/skywalking  │ /d/vm           │ /d/vector │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🟢 SYSTEM & UTILITIES (Tier 3)                              │
├─────────────────────────────────────────────────────────────┤
│ System Health │ NixOS Deploy │ Host Metrics │ Network       │
│ /d/system     │ /d/deploy    │ /d/host      │ /d/network    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 📊 OBSERVABILITY STACK                                      │
├─────────────────────────────────────────────────────────────┤
│ Metrics   │ Logs        │ Traces              │ Alerts      │
│ Insights  │ Explorer    │ Distributed Tracing │ Overview    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🔗 CROSS-CUTTING VIEWS                                      │
├─────────────────────────────────────────────────────────────┤
│ Service Dependencies │ SLO Overview │ Performance Analysis  │
│ /d/dependencies      │ /d/slo       │ /d/performance      │
└─────────────────────────────────────────────────────────────┘
```

### Implementation: Dynamic Catalog Dashboard

```jsonnet
// dashboards-src/overview/service-catalog.jsonnet

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Parse SERVICE-REGISTRY.yaml (would need external tool or hardcode)
local services = [
  { name: 'PostgreSQL', uid: 'postgres-db', tier: 'critical', desc: 'Primary database' },
  { name: 'API Gateway', uid: 'api-gateway', tier: 'critical', desc: 'Request entry point' },
  { name: 'Redis', uid: 'redis', tier: 'high', desc: 'Cache layer' },
  { name: 'Elasticsearch', uid: 'elasticsearch', tier: 'high', desc: 'Search & analytics' },
  // ... more services
];

// Helper: Create service tile
local serviceTile(service) =
  g.panel.stat.new(service.name)
  + c.pos(0, 0, 6, 3)  // Small tile
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.standardOptions.withUnit('short')
  + {
    options: {
      orientation: 'auto',
    },
    fieldConfig: {
      defaults: {
        custom: {
          align: 'center',
        },
      },
    },
    links: [{
      title: 'Open Dashboard',
      url: '/d/' + service.uid,
      targetBlank: false,
      asDropdown: false,
    }],
  };

// Catalog sections
local criticalServicesMarkdown = |||
  ## 🔴 Critical Services (Tier 1)

  | Service | Dashboard | Description |
  |---------|-----------|-------------|
  | PostgreSQL | [Link](/d/postgres-db) | Primary relational database |
  | API Gateway | [Link](/d/api-gateway) | Request routing & rate limiting |
  | Payment Service | [Link](/d/payment-service) | Payment processing |
  | Auth Service | [Link](/d/auth-service) | User authentication |
|||;

local highPriorityMarkdown = |||
  ## 🟡 High Priority Services (Tier 2)

  | Service | Dashboard | Description |
  |---------|-----------|-------------|
  | Redis | [Link](/d/redis) | Cache & session store |
  | Elasticsearch | [Link](/d/elasticsearch) | Full-text search |
  | SkyWalking OAP | [Link](/d/skywalking-oap) | Distributed tracing |
  | VictoriaMetrics | [Link](/d/victoriametrics) | Metrics database |
|||;

local systemServicesMarkdown = |||
  ## 🟢 System & Infrastructure

  | Service | Dashboard | Description |
  |---------|-----------|-------------|
  | System Health | [Link](/d/system-health) | Host CPU, Memory, Disk |
  | Network | [Link](/d/network-topology) | Network health & topology |
  | NixOS Deployer | [Link](/d/services-nixos-deployer) | GitOps deployments |
|||;

// Build dashboard
g.dashboard.new('📚 Service Catalog')
+ g.dashboard.withUid('service-catalog')
+ g.dashboard.withDescription(|||
  Central index of all monitored services with quick links to dashboards.

  **Quick Navigation:**
  - Use sections below to find services by criticality
  - Click service name or link to open dashboard
  - Use browser search (Ctrl+F) to find specific service
  - All dashboards are tagged by service type for easy filtering
|||)
+ g.dashboard.withTags(['catalog', 'index', 'navigation', 'services'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('🔴 Critical Services') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 4)
    + g.panel.text.options.withMode('markdown')
    + g.panel.text.options.withContent(criticalServicesMarkdown),

  g.panel.row.new('🟡 High Priority Services') + c.pos(0, 5, 24, 1),
  g.panel.text.new('') + c.pos(0, 6, 24, 4)
    + g.panel.text.options.withMode('markdown')
    + g.panel.text.options.withContent(highPriorityMarkdown),

  g.panel.row.new('🟢 System & Infrastructure') + c.pos(0, 10, 24, 1),
  g.panel.text.new('') + c.pos(0, 11, 24, 4)
    + g.panel.text.options.withMode('markdown')
    + g.panel.text.options.withContent(systemServicesMarkdown),

  g.panel.row.new('📊 Cross-Cutting Views') + c.pos(0, 15, 24, 1),
  g.panel.text.new('') + c.pos(0, 16, 24, 3)
    + g.panel.text.options.withMode('markdown')
    + g.panel.text.options.withContent(|||
      | Dashboard | Purpose |
      |-----------|---------|
      | [Service Dependencies](/d/service-dependencies) | See how services call each other |
      | [SLO Overview](/d/slo-overview) | Track SLO compliance across services |
      | [Distributed Tracing](/d/skywalking-traces) | Trace requests across services |
      | [Query Performance](/d/query-performance) | Monitor database query performance |
    |||),
])
```

---

## Level 2: Breadcrumb Navigation

### Pattern: Dashboard Header with Breadcrumbs

Add a text panel at the top of each dashboard showing the path:

```jsonnet
local breadcrumbPanel =
  g.panel.text.new('Navigation Breadcrumbs')
  + c.pos(0, 0, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    [📚 Service Catalog](/d/service-catalog) >
    [PostgreSQL](/d/postgres-db) >
    **Replication**

    [← Back to Main](/d/postgres-db) | [Health Dashboard](/d/postgres-health)
  |||);
```

### Benefits
- Users always know where they are
- Easy navigation to parent/sibling dashboards
- Reduce "dashboard clicking fatigue"
- Quick access to related views

---

## Level 3: Related Dashboards Panel

### Pattern: Links to Related Dashboards

In each dashboard, add a panel linking to related dashboards:

```jsonnet
// For PostgreSQL Dashboard:
local relatedDashboardsPanel =
  g.panel.text.new('📚 Related Dashboards')
  + c.pos(20, 1, 4, 3)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### 🔗 Related Views

    **On This Service:**
    - [Replication](/d/postgres-replication)
    - [Query Performance](/d/postgres-performance)

    **Connected Services:**
    - [API Gateway](/d/api-gateway) (uses this DB)
    - [Auth Service](/d/auth-service) (uses this DB)

    **Observability:**
    - [Service Dependencies](/d/service-dependencies)
    - [SkyWalking Traces](/d/skywalking-traces)
  |||);
```

---

## Level 4: Grafana Tagging Strategy

### Tag Hierarchy

```
# Service Type
service:database          → PostgreSQL, MySQL, Redis
service:api              → API Gateway, microservices
service:observability    → VictoriaMetrics, SkyWalking
service:infrastructure   → System, Network, Storage

# Criticality
tier:critical            → P0 services (99.95% SLO)
tier:high                → P1 services (99.5% SLO)
tier:medium              → P2 services (99% SLO)

# Functionality
category:metrics         → Metrics-focused dashboards
category:traces          → Tracing/APM dashboards
category:logs            → Log analysis dashboards
category:health          → Health/availability dashboards
category:performance     → Performance & optimization dashboards

# Team/Ownership
team:backend             → Backend team dashboards
team:platform            → Platform/infrastructure team
team:observability       → Observability team

# Environment
env:production           → Production dashboards
env:staging              → Staging/testing dashboards
env:development          → Development dashboards
```

### Dashboard Tags (Examples)

```jsonnet
// PostgreSQL Dashboard
+ g.dashboard.withTags([
  'service:database',
  'tier:critical',
  'category:health',
  'category:performance',
  'team:platform',
  'env:production',
])

// API Gateway Dashboard
+ g.dashboard.withTags([
  'service:api',
  'tier:critical',
  'category:traces',
  'category:performance',
  'team:backend',
  'env:production',
])
```

### Using Tags for Navigation

In Grafana:
1. **Browse by Service Type:** `service:database` → all database dashboards
2. **Browse by Tier:** `tier:critical` → all critical services
3. **Browse by Team:** `team:backend` → all backend dashboards
4. **Browse by Function:** `category:health` → all health dashboards

---

## Auto-Generation Script

```bash
#!/bin/bash
# tools/generate-service-catalog.sh

# Parse SERVICE-REGISTRY.yaml and generate catalog dashboard

echo "Generating Service Catalog Dashboard..."

# Count services by tier
critical=$(yq '.services[] | select(.tier=="critical") | .name' observability/SERVICE-REGISTRY.yaml | wc -l)
high=$(yq '.services[] | select(.tier=="high") | .name' observability/SERVICE-REGISTRY.yaml | wc -l)
medium=$(yq '.services[] | select(.tier=="medium") | .name' observability/SERVICE-REGISTRY.yaml | wc -l)

echo "Critical services: $critical"
echo "High priority: $high"
echo "Medium priority: $medium"

# Generate markdown with service links
cat > /tmp/catalog.md << EOF
# Service Catalog ($((critical + high + medium)) services)

## 🔴 Critical Services ($critical)
$(yq '.services[] | select(.tier=="critical") | "- [\(.name)](/d/\(.uid)) - \(.description)"' observability/SERVICE-REGISTRY.yaml)

## 🟡 High Priority ($high)
$(yq '.services[] | select(.tier=="high") | "- [\(.name)](/d/\(.uid)) - \(.description)"' observability/SERVICE-REGISTRY.yaml)

## 🟢 Medium Priority ($medium)
$(yq '.services[] | select(.tier=="medium") | "- [\(.name)](/d/\(.uid)) - \(.description)"' observability/SERVICE-REGISTRY.yaml)
EOF

# Output for dashboard markdown panel
cat /tmp/catalog.md
```

---

## Navigation Best Practices

### For Dashboard Developers

1. **Add Breadcrumbs** — Every dashboard needs parent/sibling links
2. **Link Related Dashboards** — Show dependent and dependency services
3. **Use Consistent Tags** — Follow tagging strategy
4. **Include Service Catalog Link** — Help users discover other services
5. **Update SERVICE-REGISTRY.yaml** — Keep registry in sync with dashboards

### For Users

1. **Start at Service Catalog** — Find what you need quickly
2. **Use Breadcrumbs to Navigate** — Don't get lost in 41 dashboards
3. **Follow Related Dashboards** — Understand service dependencies
4. **Use Tags in Search** — `tier:critical` finds all P0 dashboards
5. **Bookmark Frequently-Used Dashboards** — Save clicks

---

## Implementation Checklist

- [ ] Create Service Catalog dashboard (service-catalog.jsonnet)
- [ ] Add breadcrumb panels to all 41 dashboards
- [ ] Add "Related Dashboards" panels where applicable
- [ ] Apply consistent tags to all dashboards
- [ ] Create navigation guide for team
- [ ] Add catalog link to Grafana home page
- [ ] Teach team the tag system
- [ ] Set up tag favorites in Grafana

---

## Example: PostgreSQL Dashboard Navigation

```
┌─────────────────────────────────────────┐
│ [📚 Catalog](/d/service-catalog)       │
│ > [PostgreSQL](/d/postgres-db)          │
│ > **Replication Details**               │
└─────────────────────────────────────────┘

┌─────────────────────────────────────┐
│   PostgreSQL Replication Metrics     │
│   (Main dashboard content)           │
└─────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ 📚 Related Dashboards (Sidebar)            │
├────────────────────────────────────────────┤
│ On PostgreSQL:                             │
│  • [Main DB Dashboard](/d/postgres-db)    │
│  • [Query Performance](/d/postgres-perf)   │
│                                            │
│ Dependent Services:                        │
│  • [API Gateway](/d/api-gateway)          │
│  • [Auth Service](/d/auth-service)        │
│                                            │
│ Observability:                             │
│  • [Service Dependencies](/d/deps)        │
│  • [SLO Overview](/d/slo)                 │
└────────────────────────────────────────────┘
```

---

## Status

✅ **Navigation Strategy:** Defined (this doc)
✅ **Tagging System:** Documented with examples
✅ **Script Templates:** Ready for implementation
⏳ **Catalog Dashboard:** Ready to implement (next iteration)
⏳ **Breadcrumbs:** Ready to add to all 41 dashboards

---

**Version:** 1.0
**Last Updated:** 2026-03-04 (Iteration 35)
**Status:** Implementation guide complete — ready for teams to build
