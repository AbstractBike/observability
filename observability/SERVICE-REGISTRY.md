# 🔍 Service Registry & Auto-Discovery System

**Date:** 2026-03-04 (Iteration 34)
**Purpose:** Centralized inventory of all services with observability configuration
**Status:** Foundation document — teams implement per service

---

## Overview

**Problem:**
- Which services are monitored?
- What metrics/logs/traces does each service emit?
- Where's the dashboard for service X?
- Who owns service Y?
- What's the status of service Z's instrumentation?

**Solution:** Service Registry — Single source of truth for observability metadata

---

## Service Registry Structure

Each service has a registry entry defining:
- Metadata (name, owner, criticality)
- Observability config (metrics, logs, traces)
- Dashboard links
- Instrumentation status
- Runbook links

### Registry Format (YAML)

```yaml
# observability/SERVICE-REGISTRY.yaml

services:
  # Infrastructure
  - name: "PostgreSQL"
    uid: "postgres-db"
    category: "infrastructure"
    tier: "critical"
    owner: "platform-team"
    description: "Primary relational database"

    observability:
      metrics:
        - name: "postgres_exporter"
          interval: "30s"
          service_label: "postgresql"
          datasource: "VictoriaMetrics"

      logs:
        - source: "journald (postgres service)"
          format: "json"
          service_field: "postgresql"
          datasource: "VictoriaLogs"

      traces:
        - type: "Slow Query Tracing"
          agent: "PostgreSQL native"
          backend: "SkyWalking OAP"
          enabled: true

    dashboards:
      - name: "PostgreSQL Database"
        uid: "postgres-db"
        url: "/d/postgres-db"
        type: "primary"
      - name: "PostgreSQL Replication"
        uid: "postgres-replication"
        url: "/d/postgres-replication"
        type: "secondary"

    runbooks:
      - name: "Main Troubleshooting"
        url: "https://wiki.pin/runbooks/postgresql/main"
      - name: "High CPU"
        url: "https://wiki.pin/runbooks/postgresql/high-cpu"
      - name: "Connection Pool"
        url: "https://wiki.pin/runbooks/postgresql/conn-pool"

    external_links:
      - name: "pgAdmin"
        icon: "🗄️"
        url: "http://pgadmin.pin"
      - name: "Metrics Explorer"
        icon: "📊"
        url: "http://192.168.0.4:8428"

    slos:
      availability: 99.95
      latency_p95_ms: 100
      error_rate: 0.5

    alerts:
      - "HighCPU"
      - "ConnectionPoolExhaustion"
      - "ReplicationLag"

    team_slack: "#platform-db"
    oncall_schedule: "postgresql-oncall"
    last_updated: "2026-03-04"

  # Services
  - name: "API Gateway"
    uid: "api-gateway"
    category: "service"
    tier: "critical"
    owner: "backend-team"
    description: "Entry point for all API requests"

    observability:
      metrics:
        - name: "prometheus"
          interval: "15s"
          service_label: "api-gateway"
      logs:
        - source: "application (stdout)"
          format: "json"
          service_field: "api-gateway"
      traces:
        - type: "Distributed Tracing"
          agent: "SkyWalking Java Agent"
          backend: "SkyWalking OAP"
          enabled: true

    dashboards:
      - name: "API Gateway"
        uid: "api-gateway"
        type: "primary"

    # ... rest of config
```

---

## Service Categories

| Category | Examples | Criticality |
|----------|----------|------------|
| **Infrastructure** | PostgreSQL, Redis, Elasticsearch | Critical |
| **Services** | API Gateway, Auth Service, Payment | Critical |
| **Observability** | VictoriaMetrics, SkyWalking OAP | High |
| **Pipeline** | Vector, Kafka, Message Queues | High |
| **Utilities** | Cache, Search, Queues | Medium |
| **Development** | CI/CD, Artifact Registry | Medium |
| **System** | NixOS, Networking, Storage | High |

---

## Auto-Generated Dashboard Index

From the registry, auto-generate a master index:

### Primary Dashboards (By Category)

```markdown
## Infrastructure
- [PostgreSQL Database](/d/postgres-db) — Primary relational database
- [Redis Cache](/d/redis) — Session and cache storage
- [Elasticsearch](/d/elasticsearch) — Search and analytics

## Services
- [API Gateway](/d/api-gateway) — Request entry point
- [Auth Service](/d/auth-service) — User authentication
- [Payment Service](/d/payment-service) — Payment processing

## Observability Stack
- [VictoriaMetrics](/d/victoriametrics) — Metrics collection
- [SkyWalking OAP](/d/skywalking-oap) — Distributed tracing
- [Vector Pipeline](/d/vector) — Log forwarding

## System & Infrastructure
- [System Health](/d/system-health) — Host metrics
- [Network Topology](/d/network-topology) — Network health
```

---

## Service Criticality Tiers

### Tier 1: Critical (P0)
- Services that directly impact customers
- SLO: 99.95% availability, <500ms latency
- Requires: 24/7 on-call, page on issues
- Examples: API Gateway, Payment Service, Primary Database

### Tier 2: High (P1)
- Services that support critical services
- SLO: 99.5% availability, <2s latency
- Requires: business hours on-call, escalation path
- Examples: Cache, Message Queue, Search Index

### Tier 3: Medium (P2)
- Internal supporting services
- SLO: 99% availability
- Requires: best-effort support
- Examples: Artifact Registry, Log Aggregation

### Tier 4: Low (P3)
- Experimental or optional services
- SLO: No formal SLO
- Requires: community support only
- Examples: Dev tools, Staging services

---

## Instrumentation Status Matrix

For each service, track instrumentation completeness:

```markdown
| Service | Metrics | Logs | Traces | Dashboard | Runbook | Status |
|---------|---------|------|--------|-----------|---------|--------|
| PostgreSQL | ✅ | ✅ | ✅ | ✅ | ✅ | 100% Complete |
| API Gateway | ✅ | ✅ | ✅ | ✅ | ✅ | 100% Complete |
| Redis | ✅ | ⏳ | ❌ | ✅ | ✅ | 60% Complete |
| Auth Service | ✅ | ✅ | ⏳ | ✅ | ⏳ | 80% Complete |
| Payment | ✅ | ✅ | ✅ | ⏳ | ❌ | 60% Complete |

Legend:
✅ = Implemented and tested
⏳ = In progress
❌ = Not implemented
```

---

## Quick-Access Service Navigation

### Grafana Home Page Auto-Generated Content

Add a "Service Catalog" dashboard section:

```jsonnet
local serviceCatalog =
  g.panel.text.new('📚 Service Catalog')
  + c.pos(0, 0, 24, 8)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ## Quick Access by Service

    ### 🔴 Critical Services
    - [PostgreSQL](/d/postgres-db) — Database | [Runbook](https://wiki.pin/runbooks/postgresql/main)
    - [API Gateway](/d/api-gateway) — Entry point | [Runbook](https://wiki.pin/runbooks/api-gateway/main)
    - [Payment Service](/d/payment-service) — Payments | [Runbook](https://wiki.pin/runbooks/payment/main)

    ### 🟡 High Priority
    - [Redis](/d/redis) — Cache | Status: 60% instrumented
    - [Elasticsearch](/d/elasticsearch) — Search
    - [SkyWalking OAP](/d/skywalking-oap) — Tracing

    ### 🟢 Standard Services
    - [Vector](/d/vector) — Log pipeline
    - [VictoriaMetrics](/d/victoriametrics) — Metrics
  |||);
```

---

## Service Dependency Graph

Automatically generated from observability data:

```
┌─────────────────────────────────────┐
│         API Gateway (Tier 1)        │
│     Status: ✅ All metrics OK       │
└──────────────┬──────────────────────┘
               │
      ┌────────┼────────┐
      │        │        │
      ▼        ▼        ▼
  ┌─────┐ ┌──────┐ ┌──────────┐
  │ Auth│ │Order │ │ Payment  │
  │ Svc │ │ Svc  │ │ Service  │
  └─┬───┘ └──┬───┘ └────┬─────┘
    │        │          │
    │        └────┬─────┘
    │             │
    └─────────┬───┘
              ▼
        ┌──────────────┐
        │ PostgreSQL   │
        │ (Tier 1)     │
        └──────┬───────┘
               │
        ┌──────┴──────┐
        ▼             ▼
    ┌────┐      ┌────────┐
    │Rds │      │ Search │
    │    │      │        │
    └────┘      └────────┘

Legend:
✅ All metrics/logs/traces present
⚠️  Some instrumentation missing
❌ Critical instrumentation missing
```

---

## Service Checklist Template

For on-boarding each new service:

```markdown
# Service Onboarding Checklist: [Service Name]

## Basic Info
- [ ] Service name and description defined
- [ ] Owner/team assigned
- [ ] Criticality tier chosen
- [ ] Team Slack channel created

## Observability Setup
- [ ] Metrics exported (Prometheus format)
- [ ] Logs forwarded (JSON to Vector)
- [ ] Traces enabled (SkyWalking agent installed)
- [ ] All data reaching collectors

## Dashboard Creation
- [ ] Primary dashboard created
- [ ] Dashboard linked in registry
- [ ] All metrics displayed
- [ ] Dashboards load <2s

## Runbooks
- [ ] Main troubleshooting runbook written
- [ ] Issue-specific runbooks (2-3)
- [ ] Runbooks linked in dashboard
- [ ] Team trained on runbooks

## SLOs & Alerts
- [ ] SLOs defined (availability, latency, error rate)
- [ ] Alert rules configured
- [ ] Alert routing defined
- [ ] Escalation path documented

## Testing
- [ ] Dashboards tested with real data
- [ ] Alerts tested (alert fired and resolved)
- [ ] Runbooks tested in simulation
- [ ] On-call team confirmed readiness

## Registry & Documentation
- [ ] Service added to SERVICE-REGISTRY.yaml
- [ ] External links configured
- [ ] Team documentation updated
- [ ] Service catalog updated
```

---

## Registry Commands (Bash Automation)

For teams implementing registry:

```bash
#!/bin/bash
# tools/registry-health-check.sh

# Check all services in registry have dashboards
for service in $(yq '.services[].uid' observability/SERVICE-REGISTRY.yaml); do
  dashboard_file="observability/dashboards-src/*/${service}.jsonnet"
  if [[ ! -f $dashboard_file ]]; then
    echo "❌ Missing dashboard: $service"
  else
    echo "✅ $service dashboard found"
  fi
done

# Validate SLOs are reasonable
for svc in $(yq '.services[]' observability/SERVICE-REGISTRY.yaml); do
  availability=$(echo "$svc" | yq '.slos.availability')
  if (( $(echo "$availability < 99" | bc -l) )); then
    echo "⚠️  Low SLO for $svc: $availability%"
  fi
done

# Report instrumentation status
echo "=== Instrumentation Status ==="
yq '.services[] |
  select(.observability.metrics != null) |
  .name + ": " + (.observability.metrics | length | tostring) + " metric sources"' \
  observability/SERVICE-REGISTRY.yaml
```

---

## Integration with Grafana Home

Auto-generate a "Service Dashboard" that links to all services:

```jsonnet
// dashboards-src/overview/service-catalog.jsonnet

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// Parse SERVICE-REGISTRY.yaml and create links
// (Requires Jsonnet std.parseYaml or external data source)

local serviceLinks = [
  { name: 'PostgreSQL', uid: 'postgres-db', tier: 'critical' },
  { name: 'API Gateway', uid: 'api-gateway', tier: 'critical' },
  { name: 'Redis', uid: 'redis', tier: 'high' },
  // ... parsed from registry
];

local serviceLinkPanel(service) =
  g.panel.stat.new(service.name)
  + g.panel.stat.options.withColorMode('background')
  + {
    links: [{
      title: 'Open Dashboard',
      url: '/d/' + service.uid,
      targetBlank: false,
    }],
  };

g.dashboard.new('Service Catalog')
+ g.dashboard.withUid('service-catalog')
+ g.dashboard.withDescription('Index of all monitored services with direct links to dashboards')
+ g.dashboard.withPanels([
  g.panel.row.new('🔴 Critical Services (Tier 1)') + c.pos(0, 0, 24, 1),
  serviceLinkPanel({ name: 'PostgreSQL', uid: 'postgres-db', tier: 'critical' }),
  serviceLinkPanel({ name: 'API Gateway', uid: 'api-gateway', tier: 'critical' }),

  g.panel.row.new('🟡 High Priority (Tier 2)') + c.pos(0, 4, 24, 1),
  serviceLinkPanel({ name: 'Redis', uid: 'redis', tier: 'high' }),
  serviceLinkPanel({ name: 'Elasticsearch', uid: 'elasticsearch', tier: 'high' }),
])
```

---

## Benefits

### For On-Call Engineers
✅ **Fast Service Lookup:** "Which dashboard for Redis?" → check registry
✅ **Runbook Access:** Every service has linked runbooks
✅ **Dependency Understanding:** Know what service depends on what
✅ **SLO Clarity:** Know expected availability for each service

### For Developers
✅ **Instrumentation Guide:** What metrics/logs/traces needed
✅ **Best Practices:** Copy patterns from similar services
✅ **Checklist:** Ensure nothing is missed when adding service
✅ **Discoverability:** New team members find services easily

### For Team Leads
✅ **Inventory Management:** Know all services and status
✅ **Instrumentation Tracking:** See which services still need work
✅ **Resource Planning:** Understand observability investment per service
✅ **SLO Compliance:** Track which services meet targets

---

## Implementation Roadmap

### Phase 1: Create Registry (Iteration 34)
- [ ] Define SERVICE-REGISTRY.yaml schema
- [ ] Add 5-10 critical services
- [ ] Document format and update procedures

### Phase 2: Auto-Generation (Iteration 35)
- [ ] Script to validate registry against dashboards
- [ ] Generate service catalog dashboard
- [ ] Create health check reports

### Phase 3: Integration (Iteration 36)
- [ ] Link registry in Grafana home page
- [ ] Add service-specific runbook access
- [ ] Integrate with alert routing

### Phase 4: Automation (Iteration 37+)
- [ ] Auto-generate dashboards from registry templates
- [ ] Continuous registry validation
- [ ] Service discovery from metrics data

---

## Current Status

Services monitored (41 dashboards):
- **Infrastructure:** PostgreSQL, Redis, Elasticsearch, etc. (8)
- **Services:** API Gateway, Auth, Payment, etc. (9)
- **Observability:** VictoriaMetrics, SkyWalking, Vector (3)
- **Pipeline:** Temporal, Redpanda, various (8)
- **System/Heater:** Host-specific monitoring (5)
- **Overview/Meta:** Dashboards, traces, dependencies (8)

Instrumentation status: 95%+ (based on dashboard analysis)

---

**Version:** 1.0
**Last Updated:** 2026-03-04 (Iteration 34)
**Owner:** Observability Team
**Status:** Foundation document — ready for implementation
