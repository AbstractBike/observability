# 🔗 External Links Registry & Configuration

**Date:** 2026-03-04 (Iteration 32)
**Purpose:** Centralized registry of external service links for dashboard integration
**Status:** Production-ready

---

## Overview

External links provide quick access to complementary UIs for services:
- **SkyWalking UI** — Distributed tracing topology and span details
- **VictoriaMetrics** — Raw metrics explorer and query builder
- **VictoriaLogs** — Log search and analysis
- **Admin UIs** — PostgreSQL, Redis, etc. (service-specific)
- **Documentation** — Runbooks, architecture diagrams, etc.

**Design Principle:** Small icon buttons in dashboard corner (2×1 panel) → external link cluster

---

## Global Links (All Dashboards)

These links appear in every dashboard's top-right corner:

```
📊 VictoriaMetrics    http://192.168.0.4:8428
📝 VictoriaLogs       http://192.168.0.4:9428/vmui
🕵️  SkyWalking Traces http://192.168.0.4:8080
```

**Implementation:** `c.externalLinksPanel()` in `common.libsonnet`

---

## Service-Specific Links

### PostgreSQL
```
🗄️  Admin UI (pgAdmin)     http://pgadmin.pin
📊 Database Explorer       http://pgadmin.pin/browser
```

### Redis
```
🔴 Admin Console (RedisCommander)  http://redis.pin
📊 Memory Analysis                  http://redis.pin/analytics
```

### Elasticsearch
```
🔍 Kibana UI              http://elastic.pin:5601
📊 Dev Tools              http://elastic.pin:5601/app/dev_tools
```

### SkyWalking
```
🌐 Service Topology       http://traces.pin/general/topology
🔍 Trace Viewer          http://traces.pin/general/trace
📊 Service Metrics       http://traces.pin/api/topology
```

### Temporal
```
⏱️  Workflow Dashboard     http://temporal.pin:8233
📋 Task Queue Monitor     http://temporal.pin:8233/#/task-queues
```

### Redpanda (Kafka)
```
🚀 Console UI             http://redpanda.pin
📊 Metrics               http://redpanda.pin/metrics
```

### System Services
```
🌐 AdGuard DNS           http://adguard.pin
📱 Home Manager Config   ~/git/home
🐳 Docker Status         (on homelab host)
```

---

## How to Add Service-Specific Links

### Option 1: Global Service Registry

Add your service to `observability/dashboards-src/lib/common.libsonnet`:

```jsonnet
// In config section at top of common.libsonnet
local config = {
  skywalking_ui_url: 'http://traces.pin',
  victoriametrics_url: 'http://192.168.0.4:8428',
  victorialogs_ui_url: 'http://192.168.0.4:9428/vmui',

  // Add service-specific URLs:
  postgresql_admin_url: 'http://pgadmin.pin',
  redis_admin_url: 'http://redis.pin',
  elasticsearch_kibana_url: 'http://elastic.pin:5601',
};
```

### Option 2: Dashboard-Level Links

In your dashboard Jsonnet file:

```jsonnet
// Define service-specific links
local serviceLinks = {
  postgresql: [
    { title: '🗄️  pgAdmin', url: 'http://pgadmin.pin' },
    { title: '📊 Browser', url: 'http://pgadmin.pin/browser' },
  ],
};

// Create custom external links panel
local customExternalLinks =
  g.panel.text.new('')
  + c.pos(22, 1, 2, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <style>
      .ext-link-btn { ... }  // Copy style from c.externalLinksPanel
    </style>
    <div class="ext-links-container">
      <a class="ext-link-btn" href="http://pgadmin.pin" target="_blank" title="pgAdmin">🗄️</a>
      <a class="ext-link-btn" href="http://redis.pin" target="_blank" title="Redis Console">🔴</a>
    </div>
  |||);

// Add to dashboard:
g.dashboard.withPanels([
  customExternalLinks,
  // ... other panels
])
```

---

## URL Configuration Best Practices

### Environment Variables
For locally-testable dashboards, use environment variables:

```bash
export SKYWALKING_UI=http://traces.pin
export VICTORIAMETRICS_URL=http://192.168.0.4:8428

# Build dashboards
nix build '.#dashboards'
```

### DNS Names vs IPs
**Use DNS names (preferred):**
- Easier to remember: `http://traces.pin`
- Works in any environment (DNS resolves correctly)
- Symmetric with documentation

**Avoid IPs (exception: internal services only):**
- Hard-coded IPs become stale
- Different in dev vs production
- Not user-friendly

### Port Numbers
**Standard ports (prefer):**
- Web UIs: 80/443 (omit in URL)
- Admin panels: 3000-9999
- APIs: 8080-9000

**Custom config (add comment):**
```jsonnet
// Port 8233: Temporal UI requires non-standard port for WebSocket connections
temporal_ui_url: 'http://temporal.pin:8233',
```

---

## Visual Design

### Icon Standards

| Icon | Purpose | Examples |
|------|---------|----------|
| 📊 | Metrics/Monitoring | VictoriaMetrics, Grafana |
| 📝 | Logs/Text | VictoriaLogs, Kibana |
| 🕵️  | Tracing/Investigation | SkyWalking, Jaeger |
| 🌐 | Web UI/Dashboard | Admin panels, UIs |
| 🗄️  | Database/Storage | PostgreSQL, Redis |
| 🔴 | Cache/Queue | Redis, RabbitMQ |
| 🚀 | Deployment/Pipeline | ArgoCD, Deployment tools |
| 📱 | Configuration | Home Manager, Ansible |
| ⏱️  | Scheduling/Workflows | Temporal, Airflow |

### Button Styling

Current implementation (production):
```css
.ext-link-btn {
  width: 24px;
  height: 24px;
  background: #2563eb;  /* Blue */
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
}
.ext-link-btn:hover {
  background: #1d4ed8;
  transform: scale(1.1);
  box-shadow: 0 2px 6px rgba(37, 99, 235, 0.4);
}
```

---

## Service-Specific Dashboard Integration Examples

### PostgreSQL Dashboard
```jsonnet
local c = import 'lib/common.libsonnet';

local postgreSQLLinks =
  g.panel.text.new('')
  + c.pos(22, 1, 2, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <style>
      .ext-link-btn { /* styling */ }
    </style>
    <div class="ext-links-container">
      <a class="ext-link-btn" href="http://192.168.0.4:8428" target="_blank" title="Metrics">📊</a>
      <a class="ext-link-btn" href="http://pgadmin.pin" target="_blank" title="pgAdmin">🗄️</a>
      <a class="ext-link-btn" href="http://traces.pin" target="_blank" title="Traces">🕵️</a>
    </div>
  |||);

// In dashboard:
g.dashboard.new('PostgreSQL').withPanels([
  postgreSQLLinks,  // Top-right corner
  // ... metrics panels
])
```

### Service Dependencies Dashboard
```jsonnet
local serviceDependencyLinks =
  g.panel.text.new('')
  + c.pos(22, 1, 2, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <div class="ext-links-container">
      <a class="ext-link-btn" href="http://traces.pin/general/topology" target="_blank" title="Service Topology">🌐</a>
      <a class="ext-link-btn" href="http://192.168.0.4:8428" target="_blank" title="Metrics">📊</a>
    </div>
  |||);
```

---

## Maintenance

### Quarterly Link Audit
- [ ] Verify all URLs still resolve
- [ ] Check for redirects (update if permanent)
- [ ] Test from both internal and external access points
- [ ] Update documentation if any service moves

### Adding New Services
1. **Determine primary UI:** What's the main inspection interface?
2. **Choose icon:** From icon standards above
3. **Add to registry:** Either config or dashboard-specific
4. **Document:** Add section to this file
5. **Test:** Verify link works from dashboard
6. **Commit:** Update with service addition message

### Broken Link Handling

If a link breaks:
1. **Diagnose:** Service down or URL changed?
2. **Temporary:** Remove link from dashboard, file incident
3. **Permanent:** Update URL in config, rebuild dashboards
4. **Communicate:** Note in commit message why link changed

---

## Recommended Additions (Future)

Based on initial deployment:
- [ ] **RunBooks:** Add runbook links alongside external links
- [ ] **Service Topology:** Auto-generate links from service registry
- [ ] **Link Health:** Periodic check that all links resolve
- [ ] **Breadcrumbs:** Show parent service/category in link list
- [ ] **Mobile Optimization:** Responsive link panel for mobile viewers
- [ ] **Search:** Quick-link finder across all dashboards

---

## Quick Copy-Paste Templates

### Minimal External Links (3 global + 1 service)
```jsonnet
local externalLinks = c.externalLinksPanel();  // Uses global links

g.dashboard.new('My Service')
  .withPanels([
    externalLinks,  // Top-right corner
    // ... other panels
  ])
```

### Advanced External Links (service-specific)
```jsonnet
local serviceLinks =
  g.panel.text.new('')
  + c.pos(22, 1, 2, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('html')
  + g.panel.text.options.withContent(|||
    <style>
      .ext-link-btn {
        display: inline-flex; align-items: center; justify-content: center;
        width: 24px; height: 24px; background: #2563eb; color: white;
        text-decoration: none; border-radius: 4px; font-size: 12px;
        margin: 2px; cursor: pointer; transition: all 0.2s;
      }
      .ext-link-btn:hover { background: #1d4ed8; transform: scale(1.1); }
      .ext-links-container { display: flex; gap: 4px; }
    </style>
    <div class="ext-links-container">
      <a class="ext-link-btn" href="[URL1]" target="_blank" title="[Service1]">[Icon1]</a>
      <a class="ext-link-btn" href="[URL2]" target="_blank" title="[Service2]">[Icon2]</a>
      <a class="ext-link-btn" href="[URL3]" target="_blank" title="[Service3]">[Icon3]</a>
    </div>
  |||);

g.dashboard.new('My Service').withPanels([serviceLinks, /* ... */])
```

---

## Status

✅ **Global Links:** Implemented in all 41 dashboards
✅ **Service-Specific Links:** Examples documented
⏳ **Link Health Monitoring:** (Iteration 33 candidate)
⏳ **Runbook Integration:** (Iteration 33 candidate)

---

**Version:** 1.0
**Last Updated:** 2026-03-04 (Iteration 32)
**Owner:** Observability Team
**Status:** Ready for production use
