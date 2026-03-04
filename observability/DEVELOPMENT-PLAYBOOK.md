# 🚀 Dashboard Development Playbook

**Date:** 2026-03-04 (Iteration 31)
**Purpose:** Step-by-step guide for creating production-ready Grafana dashboards
**Audience:** Backend engineers, SREs, observability engineers

---

## Table of Contents

1. [Pre-Development Checklist](#pre-development-checklist)
2. [Design Phase](#design-phase)
3. [Implementation Phase](#implementation-phase)
4. [Testing Phase](#testing-phase)
5. [Deployment Phase](#deployment-phase)
6. [Post-Launch Monitoring](#post-launch-monitoring)

---

## Pre-Development Checklist

### Do We Need a New Dashboard?

Before starting, answer these questions:

- [ ] **Clear Purpose** — What question does this dashboard answer? (e.g., "Is service X healthy?")
- [ ] **Audience** — Who will use it? (engineers, on-call, product team?)
- [ ] **Data Available** — Do metrics/logs for this dashboard exist?
- [ ] **Doesn't Duplicate** — No existing dashboard covers this? (check `/grafana/dashboards/` directory)
- [ ] **Maintenance Plan** — Who will maintain this 6 months from now?

### Approval Checklist

- [ ] **Stakeholder aligned** — Team agrees dashboard is needed
- [ ] **Data ownership clear** — Service owner confirms metrics will be emitted
- [ ] **Performance expectations set** — Team understands <2s load target
- [ ] **SLOs defined** — Dashboard metrics have defined targets/thresholds

---

## Design Phase

### Step 1: Define Dashboard Scope

Create a one-page design document:

```markdown
# Dashboard: [Service Name] — [Purpose]

## Purpose
[One sentence: what does this answer?]

## Audience
- Primary: [e.g., on-call engineers]
- Secondary: [e.g., service owners]

## Metrics Needed
- [ ] metric_1 (from service X)
- [ ] metric_2 (from service Y)
- [ ] metric_3 (optional, from service Z)

## Success Criteria
- Dashboard loads in <2s
- No "No data" errors on fresh deployments
- 95% uptime SLO tracked
- On-call can act within 30s of alert

## Sections (Tentative)
1. **Overview** — Key metrics at a glance
2. **Performance** — Latency and throughput trends
3. **Health** — Error rates and availability
4. **Details** — Detailed breakdowns for troubleshooting
5. **Logs** — Related log panel for context
```

### Step 2: List Required Metrics

For each metric:

| Metric | Type | Source | Frequency | Fallback Needed |
|--------|------|--------|-----------|-----------------|
| `service_latency_ms` | Histogram | app | Every request | No (mandatory) |
| `optional_feature_enabled` | Gauge | config | Every 5m | Yes (feature might be disabled) |

**Guidance:**
- Mandatory metrics → No fallback
- Optional metrics → Add `or vector(0)` fallback
- Rare metrics → Use larger time window + fallback

### Step 3: Sketch Panel Layout

Simple ASCII layout:

```
┌─────────────────────────────────────┐
│ 📊 Overview                         │
├──────────┬──────────┬──────────┐────┤
│ Health   │ Latency  │ Requests │ ER │  (4 stat panels)
└──────────┴──────────┴──────────┘────┘
│ 📈 Performance Trends               │
├────────────────────────────────────┤
│ Latency (p50/p95/p99)               │  (time series)
│ Request Volume (success/errors)     │  (time series)
├────────────────────────────────────┤
│ 🔍 Detailed View                    │
│ Top 10 Endpoints by Latency         │  (table)
│ Error Types (top 20)                │  (table)
├────────────────────────────────────┤
│ 📝 Logs                             │
│ Related logs for this service       │  (logs panel)
└────────────────────────────────────┘
```

**Guidelines:**
- Max 15 panels per dashboard (cognitive load)
- Group related panels in rows
- Put most important info at top
- Use emoji headers for quick scanning

---

## Implementation Phase

### Step 1: Set Up Jsonnet File

Create `observability/dashboards-src/[category]/[service-name].jsonnet`:

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Section: Health Metrics ──────────────────────────────────────────────

// Stat 1: Overall health
local healthStat =
  g.panel.stat.new('Service Health')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    // ✅ Pattern: Fallback for optional metric
    c.vmQ('(healthy_checks / total_checks) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.options.withColorMode('value');

// Stat 2: Request rate
local requestRateStat =
  g.panel.stat.new('Requests/sec')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    // ✅ Pattern: With fallback
    c.vmQ('rate(requests_total[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ops')
  + g.panel.stat.options.withColorMode('value');

// ── Section: Performance Trends ──────────────────────────────────────────

local latencyTs =
  g.panel.timeSeries.new('Latency Percentiles')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    // ✅ Pattern: Histogram with proper aggregation
    c.vmQ('histogram_quantile(0.50, sum by(le) (rate(latency_bucket[5m]))) or vector(0)', 'p50'),
    c.vmQ('histogram_quantile(0.95, sum by(le) (rate(latency_bucket[5m]))) or vector(0)', 'p95'),
    c.vmQ('histogram_quantile(0.99, sum by(le) (rate(latency_bucket[5m]))) or vector(0)', 'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5);

// ── Section: Detailed Analysis ───────────────────────────────────────────

local topEndpointsTable =
  g.panel.table.new('Top Endpoints by Error Rate')
  + c.pos(0, 8, 24, 7)
  + g.panel.table.queryOptions.withTargets([
    // ✅ Pattern: topk with pre-filtering
    c.vmQ(
      'topk(15, (errors_total / requests_total) * 100 by endpoint)',
      'Error Rate %'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('percent')
  + g.panel.table.options.withSortBy([
    { displayName: 'Error Rate %', desc: true },
  ]);

// ── Dashboard Assembly ───────────────────────────────────────────────────

g.dashboard.new('Service Name')
+ g.dashboard.withUid('service-uid-slug')
+ g.dashboard.withDescription('Service description and purpose.')
+ g.dashboard.withTags(['service', 'production', 'observability'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Overview') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  healthStat, requestRateStat,

  g.panel.row.new('📈 Performance') + c.pos(0, 3, 24, 1),
  latencyTs,

  g.panel.row.new('🔍 Details') + c.pos(0, 7, 24, 1),
  topEndpointsTable,
])
```

### Step 2: Apply Optimization Patterns

Before submitting for review, verify:

- [ ] **Histograms** — All `histogram_quantile()` have `sum by(le, ...)`
- [ ] **Fallbacks** — Optional metrics have `or vector(0)`
- [ ] **topk Queries** — Pre-filtered with labels
- [ ] **Rate Windows** — Match metric frequency
- [ ] **Grouping** — Only necessary dimensions in `by()`

### Step 3: Test Locally

```bash
# 1. Compile Jsonnet
nix build '.#dashboards-src' -L

# 2. Load into Grafana (manual: upload JSON or use API)
# JSON output at: result-json/[service-name].json

# 3. Test in Grafana:
# - Try with ?var-service=nonexistent (test fallbacks)
# - Change time range (1h → 1d → 7d)
# - Wait for panels to load
```

---

## Testing Phase

### Performance Testing

1. **Measure Baseline:**
   ```bash
   # Open browser DevTools → Network tab
   # Reload dashboard
   # Note total request time (should be <2s)
   ```

2. **Test Edge Cases:**
   ```bash
   # Empty data:
   # Add filter: ?service=nonexistent → no "No data" errors

   # Large time range:
   # Set to 30d → panels still load <3s

   # Multiple tabs open:
   # Open 3 dashboards → no browser slowdown
   ```

3. **Production-Scale Testing:**
   ```bash
   # Use actual production metrics
   # Query: count(metric_name) → verify series count
   # Expected: <10K series per panel
   ```

### Functional Testing

- [ ] All panels show data (no "No data" errors)
- [ ] Legends are clear and readable
- [ ] Colors match thresholds (green=good, red=bad)
- [ ] Unit labels are correct (ms, %, ops, etc.)
- [ ] Tooltips show useful information
- [ ] Time range selectors work
- [ ] Links/buttons work (if any)

### Query Validation

```bash
# For each query, verify in Explore view:
# 1. Run query manually
# 2. Check execution time (<200ms p95)
# 3. Check series count (<1K typically)
# 4. Check for errors/warnings
# 5. Verify with 7d and 30d ranges
```

---

## Deployment Phase

### Pre-Deployment Checklist

- [ ] **Code Review** — Peer reviewed Jsonnet and queries
- [ ] **Testing Complete** — All test cases pass
- [ ] **Performance OK** — Dashboard loads <2s
- [ ] **No Anti-Patterns** — Reviewed against optimization guidelines
- [ ] **Documentation** — Added comments for complex queries
- [ ] **Owners Confirmed** — Service owner approves dashboard

### Deployment Steps

```bash
# 1. Commit to repo
git add observability/dashboards-src/[category]/[service-name].jsonnet
git commit -m "feat(observability): add [Service Name] dashboard

- Tracks key metrics: latency, error rate, throughput
- Includes performance trends and detailed breakdowns
- All queries optimized: histogram aggregation, topk filtering
- Fallbacks configured for optional metrics
- Load time target: <2s (measured: 1.2s)

[Service Name] team approved this dashboard.
* Haiku - 8k tokens"

# 2. Push and create PR
git push origin feature/[dashboard-name]
gh pr create --title "observability: add [Service] dashboard"

# 3. After merge, rebuild dashboards
nix flake check
nixos-rebuild switch

# 4. Verify in Grafana
# Open http://192.168.0.4:3000/search?tag=[tag]
# Confirm dashboard is visible and loads correctly
```

### Rollback Plan

If dashboard causes issues:

```bash
# 1. Quick fix (if minor issue):
# Edit query directly in Grafana UI
# Save to JSON
# Update Jsonnet file

# 2. Rollback (if major issue):
git revert <commit-hash>
git push origin main
nixos-rebuild switch

# 3. Communicate
# Notify team about issue and rollback
# Plan fix for next attempt
```

---

## Post-Launch Monitoring

### First Week (Intensive)

- [ ] Check Grafana error logs daily
- [ ] Monitor dashboard load time (target: <2s p95)
- [ ] Check VictoriaMetrics query latency for new queries
- [ ] Monitor CPU usage spike (if any)
- [ ] Gather user feedback

**Success Metrics:**
- Zero error reports
- Dashboard load time <2s
- >90% of users report it's helpful
- No performance regression

### Ongoing (Weekly/Monthly)

1. **Monitor Dashboard Performance:**
   - Track in VictoriaMetrics: `grafana_dashboard_load_ms`
   - Alert if load time > 3s

2. **Monitor Data Freshness:**
   - Verify metrics are still being emitted
   - Check for "No data" error spikes

3. **Track Usage:**
   - Dashboard view count (in Grafana)
   - Peak concurrent users
   - Common filters/time ranges used

4. **Gather Feedback:**
   - Monthly check-in with users
   - Are the metrics helpful?
   - Missing information?
   - Too much information?

### Update Cycle

**Monthly Review:**
- Any metrics that are always 0 or always at max? (Remove if useless)
- Queries consistently slow? (Optimize)
- Feedback suggests new metrics? (Add)
- Thresholds correct? (Adjust if needed)

**Quarterly Optimization:**
- Run profiling against latest data
- Apply new optimization patterns
- Update documentation if needed

---

## Common Scenarios & Solutions

### Scenario 1: Dashboard Shows "No Data"

**Diagnosis:**
1. Check if metric exists: Search in Explore view
2. Try different time range (1h → 7d)
3. Check metric labels/selectors

**Solution:**
```jsonnet
// Add fallback pattern
c.vmQ('metric_name or vector(0)')
```

### Scenario 2: Dashboard Loads Slowly (>3s)

**Diagnosis:**
1. Open DevTools → Network tab
2. Identify slowest query
3. Check query execution time in Explore

**Solution:**
```promql
// Check if histogram needs aggregation:
histogram_quantile(0.95, sum by(le) (rate(latency_bucket[5m])))

// Check if topk needs filtering:
topk(10, metric{env="prod"})

// Check if rate window is correct:
rate(metric[1h])  # for hourly metrics
```

### Scenario 3: High CPU Usage During Dashboard Load

**Diagnosis:**
1. Check VictoriaMetrics metrics: `vm_request_duration_seconds`
2. Identify which query uses most CPU
3. Check series cardinality

**Solution:**
```promql
# Reduce cardinality:
metric{env="production"}  # Add label filter
by (service, endpoint)     # Remove unnecessary dimensions
```

---

## Quick Reference Checklist

### Before Coding
- [ ] Purpose clear?
- [ ] Metrics exist?
- [ ] No duplicate dashboard?

### While Coding
- [ ] Using optimization patterns?
- [ ] No anti-patterns?
- [ ] Comments for complex queries?

### Before Submitting
- [ ] Tests pass?
- [ ] Performance <2s?
- [ ] All fallbacks working?
- [ ] Code reviewed?

### Before Deploying
- [ ] Metrics confirmed to exist?
- [ ] Team aligned?
- [ ] Runbook updated?

### After Deploying
- [ ] Monitors set up?
- [ ] No errors in first week?
- [ ] Feedback collected?

---

## Templates

### Dashboard Commit Message Template

```
feat(observability): add [Service] dashboard

Description of what the dashboard tracks.

Sections:
- Overview: Key metrics at glance
- Trends: Historical patterns
- Details: Detailed breakdowns

Optimization:
- All histogram queries use sum by(le, ...)
- topk queries pre-filtered by [label]
- Fallbacks configured for [optional metrics]

Performance:
- Load time: <2s (measured: 1.2s)
- Query latency p95: <200ms (measured: 145ms)
- Series count: <500 per panel

Tests:
- Zero data: ✅ Tested with ?service=nonexistent
- Time ranges: ✅ Tested 1h, 1d, 7d, 30d
- Production scale: ✅ Verified series count

Team approval: [Service] team reviewed and approved

* Model - Tokens
```

### Dashboard Code Template

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── [Section Name] ──────────────────────────────────────────────────────

local panelName =
  g.panel.[type].new('[Title]')
  + c.[posFunction]([position])
  + g.panel.[type].queryOptions.withTargets([
    // ✅ Optimization notes:
    // - Uses sum by(le) for histogram aggregation
    // - Pre-filters with {label=value} for topk
    // - Fallback for optional metrics
    c.vmQ('[optimized-query]'),
  ])
  + [further configuration];

// ── Dashboard ──────────────────────────────────────────────────────────

g.dashboard.new('[Service Name]')
+ g.dashboard.withUid('[slug]')
+ g.dashboard.withDescription('[Purpose]')
+ g.dashboard.withTags(['[tag1]', '[tag2]'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('[Emoji] [Section Name]') + c.pos(0, [y], 24, 1),
  panelName1,
  panelName2,
])
```

---

**Version:** 1.0
**Status:** Production-ready
**Last Updated:** 2026-03-04 (Iteration 31)
**Audience:** All dashboard developers
**Contact:** Observability team for questions
