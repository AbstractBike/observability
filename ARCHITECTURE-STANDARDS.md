# 📐 Observability Architecture Standards

**Version:** 1.0
**Date:** 2026-03-04
**Scope:** All Grafana dashboards and panels in homelab

---

## 🎯 Panel Naming Convention

### Standard Format
```
{MetricType} — {Service/Component} — {Context}
```

### Examples
✅ **Good:**
- `Latency — API Gateway — p99`
- `Error Rate — PostgreSQL — 5m average`
- `CPU Usage — VictoriaMetrics — peak utilization`
- `Memory — Heap — Java GC duration`
- `Storage — VictoriaMetrics — growth rate`
- `Cardinality — Metrics — unique series count`

❌ **Avoid:**
- `Query Latency` (missing service context)
- `P99` (too vague)
- `Storage usage growth` (inconsistent format)
- `metric_latency_histogram` (technical, not user-friendly)

### Components
1. **MetricType:** What is being measured?
   - Examples: `Latency`, `Error Rate`, `CPU Usage`, `Memory`, `Storage`, `Throughput`

2. **Service/Component:** What system does it measure?
   - Examples: `API Gateway`, `PostgreSQL`, `VictoriaMetrics`, `Elasticsearch`
   - Use full names, not abbreviations

3. **Context:** Additional specificity
   - Examples: `p99`, `peak`, `5m avg`, `growth rate`, `heap usage`
   - Optional but recommended for clarity

---

## 📊 Unit Standardization

### Available Units Library
Access via `c.units.<unit_name>` in Jsonnet:

#### Time Metrics
```jsonnet
c.units.latency_ms     // Milliseconds (1 decimal)
c.units.latency_s      // Seconds (2 decimals)
c.units.duration_s     // Seconds (no decimals)
c.units.uptime         // Seconds (no decimals, for durations)
```

#### Data Storage
```jsonnet
c.units.bytes          // Bytes with auto-scaling
c.units.megabytes      // MB (1 decimal)
c.units.gigabytes      // GB (1 decimal)
```

#### Rates
```jsonnet
c.units.rate_per_sec   // requests/sec (short, no decimals)
c.units.rate_per_min   // requests/min (short, no decimals)
c.units.rate_per_hour  // per hour (short, no decimals)
```

#### Percentages
```jsonnet
c.units.percent        // 0-100 scale (no decimals)
c.units.percent_decimal // 0.0-1.0 decimal scale (2 decimals)
```

#### Counts
```jsonnet
c.units.count          // Simple count (short, no decimals)
c.units.count_decimal  // Count with decimals (1 decimal)
```

#### Performance
```jsonnet
c.units.cpu_percent    // CPU % (1 decimal)
c.units.memory_percent // Memory % (1 decimal)
c.units.disk_percent   // Disk % (no decimals)
```

#### Errors
```jsonnet
c.units.errors         // Error count (short, no decimals)
c.units.error_rate     // Error rate 0.0-1.0 (4 decimals)
```

### Usage Example
```jsonnet
local panel =
  g.panel.stat.new('Latency — API Gateway — p99')
  + g.panel.stat.standardOptions.withUnit(c.units.latency_ms.unit)
  + g.panel.stat.standardOptions.withDecimals(c.units.latency_ms.decimals);
```

---

## 🎨 Color & Threshold Standards

### Threshold Palettes

#### Percentage Thresholds (e.g., CPU, Memory, Disk)
```
0-69%      = Green    ✅ Healthy
70-89%     = Yellow   ⚠️  Warning
90-100%    = Red      🔴 Critical
```

#### Latency Thresholds (milliseconds)
```
0-100ms    = Green    ✅ Fast
100-500ms  = Yellow   ⚠️  Acceptable
500ms+     = Red      🔴 Slow
```

#### Error Count Thresholds
```
0-5        = Green    ✅ Normal
5-20       = Yellow   ⚠️  Elevated
20+        = Red      🔴 High
```

### Usage
```jsonnet
// For CPU/Memory:
+ c.percentThresholds

// For latency:
+ c.latencyThresholds

// For errors:
+ c.errorThresholds
```

---

## 📁 Directory Structure

```
observability/dashboards-src/
├── lib/
│   ├── common.libsonnet                    # Shared helpers & standards
│   └── dashboard-metadata.libsonnet        # Versioning & metadata
├── overview/                               # Entry points (home, services-health)
├── observability/                          # Core observability dashboards
├── services/                               # Service-specific dashboards
├── apm/                                    # Tracing & distributed systems
├── heater/                                 # Host-specific (developer machine)
├── pipeline/                               # Data pipelines & ETL
├── slo/                                    # Service level objectives
├── claude/                                 # AI/Claude integration metrics
└── claude-chat/                            # Claude chat analytics
```

### Naming Rules
- **Directory:** lowercase, hyphenated (e.g., `api-gateway`)
- **File:** `{service}-{dashboard-type}.jsonnet`
  - Examples: `postgres-db.jsonnet`, `api-gateway-tracing.jsonnet`
- **UID:** Match file name, lowercase, hyphenated
  - Example: File `postgres-db.jsonnet` → UID `postgres-db`

---

## 🏷️ Dashboard Tags

### Required Tags (every dashboard must have all three)

1. **Environment:** `production` or `development` or `staging`
2. **Category:** Choose one:
   - `observability` (core monitoring)
   - `services` (application health)
   - `infrastructure` (system level)
   - `database` (data storage)
   - `tracing` (distributed tracing)
   - `apm` (application performance)
   - `pipeline` (data processing)
   - `meta` (meta-observability)

3. **Domain:** Choose one or more:
   - `core` (critical systems)
   - `optional` (nice-to-have)
   - `experimental` (beta/testing)

### Optional Tags
- `health`, `performance`, `optimization`, `troubleshooting`, `discovery`
- `real-time`, `historical`, `trends`
- Service names: `postgresql`, `redis`, `elasticsearch`, etc

### Example
```jsonnet
g.dashboard.withTags(['observability', 'database', 'core'])
```

---

## 🔍 Dashboard Validation

All dashboards must pass automated validation:

```bash
node scripts/dashboard-validator.js
```

### Validation Checks
- ✅ Required fields (uid, title, tags, description)
- ✅ Query health (all targets have queries)
- ✅ Panel integrity (valid panel types)
- ✅ Unit consistency (uses standard units)
- ✅ Naming conventions (follows format)
- ✅ Documentation (has description)

---

## 📝 Documentation Requirements

### Dashboard Description
Every dashboard must have a concise description explaining:
1. **What:** What does this dashboard monitor?
2. **When:** When should someone look at it?
3. **How:** How to interpret the panels?

### Example
```
"PostgreSQL database health: connection count, query latency,
replication lag, and disk usage. Check when database feels slow
or connections are exhausted. Red alerts indicate immediate action needed."
```

### Panel Descriptions
Recommended for panels with non-obvious queries:
- What metric is shown?
- How is it calculated?
- What does the threshold mean?

---

## 🔐 Datasource Rules

### Always Use Variables
```jsonnet
// ✅ Good
c.vmQ('up{job="$service"}')

// ❌ Avoid
c.vmQ('up{job="postgres"}')  // Hardcoded
```

### Datasource Fallback
For critical panels, use fallback error message:
```jsonnet
+ self.errorPanel(
    'Error',
    'VictoriaMetrics unavailable. Check connection.',
    y=10
  )
```

### Query Optimization
- Always use interval hints for large time ranges
- Use `step` parameter: `[5m]` for hour-scale, `[1h]` for day-scale
- Avoid unbounded `.*` regex when specific names available

---

## 🚀 Version Control

### Commit Message Format
```
obs(dashboards): <category> - <brief description>

Body: Detailed description of changes, why made, and impact
```

### Examples
```
obs(dashboards): perf - improve query latency thresholds
obs(dashboards): arch - add panel naming standards
obs(dashboards): new - create database query tracing dashboard
```

---

## 📊 Monitoring the Monitors

### Key Metrics to Track
- **Dashboard uptime:** All panels return data without errors
- **Query performance:** p95 latency < 5 seconds
- **Data freshness:** All panels update within expected interval

### Health Check Dashboard
Run automated validator:
```bash
# Check all dashboards weekly
0 0 * * 0 /home/digger/git/homelab/observability/scripts/dashboard-validator.js
```

---

## 🎓 Examples & Templates

### Minimal Database Dashboard
```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

g.dashboard.new('PostgreSQL — Health')
+ g.dashboard.withUid('postgres-health')
+ g.dashboard.withDescription('PostgreSQL connection pool, query latency, replication.')
+ g.dashboard.withTags(['observability', 'database', 'core'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  // Panels here
])
```

### Minimal Metric Panel
```jsonnet
local connectionsStat =
  g.panel.stat.new(c.panelTitle('Connections', 'PostgreSQL', 'active'))
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('pg_stat_activity_count{service="postgres"}'),
  ])
  + g.panel.stat.standardOptions.withUnit(c.units.count.unit);
```

---

## ✨ Summary

These standards ensure:
- 🎯 **Consistency** — Easy to navigate between dashboards
- 🚀 **Scalability** — Patterns support 100+ dashboards
- 🔧 **Maintainability** — Clear naming, structure, versioning
- 📈 **Quality** — Automated validation catches errors early
- 🎓 **Accessibility** — New team members can contribute easily

All dashboards are checked against these standards via CI/CD.
Questions? See `IMPROVEMENTS-AUDIT.md` for more details.
