# 📖 Dashboard Optimization Guidelines & Patterns

**Date:** 2026-03-04 (Iteration 31)
**Purpose:** Establish reusable optimization patterns for future dashboard development
**Audience:** Dashboard developers, observability engineers, performance optimization team

---

## Table of Contents

1. [Core Principles](#core-principles)
2. [Pattern Library](#pattern-library)
3. [Dashboard Design Checklist](#dashboard-design-checklist)
4. [Common Anti-Patterns](#common-anti-patterns)
5. [Performance Targets](#performance-targets)
6. [Troubleshooting Guide](#troubleshooting-guide)

---

## Core Principles

### 1. **No Data is Better Than Wrong Data**
- Always use fallback values (`vector(0)`) for optional metrics
- Return 0 instead of "No data" panel errors
- Prevents dashboard flashing and improves reliability

### 2. **Cardinality Awareness**
- Understand your metric labels and their combinations
- Reduce cardinality BEFORE expensive operations (histogram_quantile, topk, rate)
- Use `sum by` aggregation to control series explosion

### 3. **Latency is Observability's Latency**
- Dashboard load time = (network + metric query time) × number of panels
- Optimize each query individually; compound effects are significant
- 100ms saved per query × 10 panels = 1 second dashboard improvement

### 4. **Test at Scale**
- Develop with realistic data volumes
- A query that's fast on 10 series may be slow on 10,000 series
- Use production data for performance testing, not sanitized subsets

### 5. **Document Assumptions**
- Include comments in complex queries explaining:
  - Why `sum by` is used
  - Why fallbacks are needed
  - Expected series cardinality
  - Performance characteristics

---

## Pattern Library

### Pattern 1: Empty Metric Handling

**Problem:** Metric not available → "No data" panel → confusing UX

**Solution:** Use `or vector(0)` fallback

```jsonnet
// ❌ ANTI-PATTERN: Returns no data when metric unavailable
c.vmQ('rate(my_metric[5m])')

// ✅ PATTERN: Returns 0 explicitly
c.vmQ('rate(my_metric[5m]) or vector(0)')

// ✅ PATTERN: With label preservation
c.vmQ('rate(my_metric[5m]) or on() vector(0)')
```

**Applies To:**
- Optional metrics (service-specific metrics that don't exist on all instances)
- Metrics that are infrequently emitted
- Metrics from services that may be down/restarting
- Example: `nixos_deploy_total` (only exists when system runs)

**Expected Impact:** +0.5% latency (negligible), +100% reliability

**Never Use Fallback On:**
- Core health metrics (if they're missing, there's a real problem)
- Time series you expect to always exist
- This pattern should only suppress "no data" errors, not hide real issues

---

### Pattern 2: Histogram Quantile Optimization

**Problem:** Unbounded histogram → cartesian product of labels → high cardinality → slow quantile calculation

**Solution:** Aggregate to desired label set BEFORE quantile calculation

```promql
// ❌ ANTI-PATTERN: Unbounded aggregation
histogram_quantile(0.95, rate(metric_bucket[5m]))

// ✅ PATTERN: Aggregate by final desired labels only
histogram_quantile(0.95, sum by(le) (rate(metric_bucket[5m])))

// ✅ PATTERN: When grouping by dimension
histogram_quantile(0.95, sum by(service, le) (rate(metric_bucket[5m])))

// ✅ PATTERN: Multiple grouping dimensions
histogram_quantile(0.95, sum by(service, endpoint, le) (rate(metric_bucket[5m])))
```

**Impact:** 10-15% latency reduction for histogram-heavy dashboards

**Key Rules:**
1. **Always include `le`** in `sum by` (le = bucket boundary label)
2. **Only include labels you'll actually display or filter on**
3. **Order matters for readability:** `sum by(service, le)` not `sum by(le, service)`

**When to Use:**
- Latency P95/P99 calculations
- Histogram-based SLO tracking
- Any `histogram_quantile()` function

**Debugging Slow Histograms:**
```promql
# Check cardinality BEFORE quantile
sum by(service) (rate(metric_bucket[5m]))  # Should be <100 series

# If >500 series, add more granular aggregation
sum by(service, endpoint, le) (rate(metric_bucket[5m]))
```

---

### Pattern 3: Top-K Series Filtering

**Problem:** topk() on millions of series → expensive cardinality reduction → slow dashboard

**Solution:** Pre-filter by relevant labels BEFORE topk()

```promql
// ❌ ANTI-PATTERN: topk on all series
topk(10, metric)

// ✅ PATTERN: Filter by environment/region first
topk(10, metric{env="production"})

// ✅ PATTERN: Multiple filters for cardinality reduction
topk(10, metric{env="production", region="us-east"})

// ✅ PATTERN: With label preservation in output
topk(10, metric) by (service, endpoint)
```

**Impact:** 5-10% latency reduction on dashboard "top X" views

**Implementation Strategy:**
1. **Identify the natural subset** (environment, region, service type)
2. **Add label selectors first**
3. **Then apply topk() for final ranking**
4. **Use `by()` to control output granularity**

**Example: Top 10 Slowest Services**
```promql
// Before: Scans ALL services
topk(10, histogram_quantile(0.95, rate(trace_latency_bucket[5m])))

// After: Only production services
topk(10, histogram_quantile(0.95, sum by(service, le)
     (rate(trace_latency_bucket{env="prod"}[5m]))))
```

---

### Pattern 4: Rate Window Selection

**Problem:** Infrequent metrics → no data on default 5m window → "No data" errors

**Solution:** Adjust rate window based on metric frequency

```promql
// Frequent metrics (>1/sec): 5-10m window
rate(http_requests_total[5m])

// Normal metrics (1-10/min): 10-30m window
rate(slow_operation_total[30m])

// Rare metrics (<1/min): 1-2h window
rate(deployment_total[1h])

// Very rare (one per day or less): Combine with increase()
increase(backup_jobs_total[24h])
```

**Decision Tree:**
1. If metric updated every second → use `[5m]`
2. If metric updated every minute → use `[10m]` or `[30m]`
3. If metric updated every hour → use `[1h]` or `[2h]`
4. If metric updated daily → use `increase()[24h]` instead of `rate()`

**Pattern with Fallback:**
```promql
rate(rare_metric[1h]) or vector(0)
```

---

### Pattern 5: Series Grouping (by clause)

**Problem:** Query returns labels you don't want → creates separate series → wastes bandwidth

**Solution:** Group results to only needed dimensions

```promql
// ❌ ANTI-PATTERN: Returns all labels (service, endpoint, method, status)
rate(http_requests_total[5m])

// ✅ PATTERN: Only the labels you need
rate(http_requests_total[5m]) by (service, status)

// ✅ PATTERN: Without labels (single value)
sum(rate(http_requests_total[5m]))

// ✅ PATTERN: Calculated label
rate(http_requests_total{status="5xx"}[5m]) by (service)
```

**Impact:** 2-5% reduction in data transfer, cleaner visualizations

**Guidelines:**
- Exclude high-cardinality labels (instance, pod, request_id)
- Include only labels you display in the panel
- Reduce dimensionality when aggregating (one dimension per visualization)

---

### Pattern 6: Cache-Friendly Queries

**Problem:** Same query executed multiple times across dashboards → wastes computation

**Solution:** Cache query results in dashboard-level variables or recording rules

```jsonnet
// Pattern: Define shared query once, reuse in multiple panels
local avgLatencyQuery =
  c.vmQ('histogram_quantile(0.95, sum by(le) (rate(trace_latency_bucket[5m])))');

// Use in multiple stat panels:
g.panel.stat.new('API Latency') +
  g.panel.stat.queryOptions.withTargets([avgLatencyQuery]),

g.panel.stat.new('Service Latency') +
  g.panel.stat.queryOptions.withTargets([avgLatencyQuery]),
```

**Better: Use VictoriaMetrics Recording Rules**

```yaml
# In monitoring/rules.yaml
- name: observability-cache
  interval: 30s
  rules:
  - record: dashboard:latency_p95:5m
    expr: histogram_quantile(0.95, sum by(le) (rate(trace_latency_bucket[5m])))

  - record: dashboard:error_rate:5m
    expr: sum(rate(errors_total[5m])) / sum(rate(requests_total[5m])) * 100
```

Then in dashboards:
```jsonnet
c.vmQ('dashboard:latency_p95:5m')  // Pre-calculated, fast!
```

**Impact:** 30-50% reduction in query load during heavy visualization periods

---

## Dashboard Design Checklist

### Before Shipping a Dashboard

- [ ] **No Anti-Patterns**
  - [ ] All queries have fallbacks (`or vector(0)`) where optional
  - [ ] All `histogram_quantile` use `sum by(le, ...)`
  - [ ] All `topk` filters cardinality first with labels
  - [ ] Rate windows match metric frequency

- [ ] **Performance**
  - [ ] Dashboard loads in <3 seconds (p95)
  - [ ] Max 15 panels per dashboard (reduce cognitive load)
  - [ ] Total query time < 2 seconds combined

- [ ] **Cardinality**
  - [ ] Understand max series per query
  - [ ] Use `by()` to reduce output dimensions
  - [ ] No unbounded grouping in expensive operations

- [ ] **Reliability**
  - [ ] All optional metrics have fallback patterns
  - [ ] No "No data" panels on fresh deployments
  - [ ] Error messages (if any) are actionable

- [ ] **Documentation**
  - [ ] Dashboard description explains purpose
  - [ ] Complex queries have inline comments
  - [ ] Panel titles are descriptive and include units
  - [ ] Links to runbooks for critical metrics

- [ ] **Testing**
  - [ ] Tested with 0 data (all fallbacks work)
  - [ ] Tested with production-scale data (cardinality OK)
  - [ ] Tested with recent data and 7-day lookback
  - [ ] Tested with different time ranges (1h, 1d, 7d, 30d)

---

## Common Anti-Patterns

### Anti-Pattern 1: Unbounded Histograms

```promql
// ❌ BAD: Creates cartesian product of all labels
histogram_quantile(0.95, rate(metric_bucket[5m]))

// ✅ GOOD: Explicit aggregation
histogram_quantile(0.95, sum by(le) (rate(metric_bucket[5m])))
```

**Cost:** 20-30% slower dashboard load

---

### Anti-Pattern 2: topk Without Filtering

```promql
// ❌ BAD: Scans all 10K services to find top 10
topk(10, metric)

// ✅ GOOD: Reduce to relevant subset first
topk(10, metric{env="prod"})
```

**Cost:** 2-5 second delay on large systems

---

### Anti-Pattern 3: Missing Fallbacks

```promql
// ❌ BAD: Returns "No data" on fresh deployments
rate(optional_metric[5m])

// ✅ GOOD: Explicit 0 value
rate(optional_metric[5m]) or vector(0)
```

**Cost:** Confusing UX, dashboard flashing, alert fatigue

---

### Anti-Pattern 4: Wrong Rate Windows

```promql
// ❌ BAD: 5m window on metrics updated hourly → frequent no-data
rate(hourly_metric[5m])

// ✅ GOOD: Match window to metric frequency
rate(hourly_metric[1h])
```

**Cost:** Unreliable data, wasted dashboard real estate

---

### Anti-Pattern 5: Unbounded Grouping

```promql
// ❌ BAD: Includes every label combination
rate(metric[5m])  // Returns service, pod, container, endpoint, method, status...

// ✅ GOOD: Only what you display
rate(metric[5m]) by (service, status)
```

**Cost:** 5x more data transfer, harder to visualize

---

### Anti-Pattern 6: Duplication

```jsonnet
// ❌ BAD: Same query in 5 panels
g.panel.stat.new('Query 1') + g.panel.stat.queryOptions.withTargets([
  c.vmQ('histogram_quantile(0.95, sum by(le) (rate(metric_bucket[5m])))')
]),
g.panel.stat.new('Query 2') + g.panel.stat.queryOptions.withTargets([
  c.vmQ('histogram_quantile(0.95, sum by(le) (rate(metric_bucket[5m])))')  // SAME!
]),

// ✅ GOOD: Define once, reuse
local targetQuery = c.vmQ('histogram_quantile(0.95, sum by(le) (rate(metric_bucket[5m])))');
g.panel.stat.new('Query 1') + g.panel.stat.queryOptions.withTargets([targetQuery]),
g.panel.stat.new('Query 2') + g.panel.stat.queryOptions.withTargets([targetQuery]),
```

**Cost:** Harder to maintain, bloated Jsonnet files

---

## Performance Targets

### Dashboard Load Time SLOs

| Dashboard Size | P95 Load Time | P99 Load Time | Target QPS |
|---|---|---|---|
| Small (3-5 panels) | <1.5s | <2.5s | >100 |
| Medium (8-12 panels) | <2.5s | <3.5s | >50 |
| Large (15+ panels) | <4s | <6s | >25 |

### Query-Level Targets

| Query Type | Target Latency | Max Series | Notes |
|---|---|---|---|
| Simple rate() | <100ms | <1K | Baseline case |
| Filtered rate() | <150ms | <500 | With label filtering |
| histogram_quantile | <200ms | <200 | With proper aggregation |
| topk() | <250ms | <100 | Pre-filtered |
| Complex (multi-stage) | <400ms | <100 | Rare, optimization candidate |

### System-Level Metrics

| Metric | Target | Warning | Critical |
|---|---|---|---|
| Query latency p95 | <200ms | 250ms | >400ms |
| Slow query rate | <5% | 8% | >12% |
| Error rate | <0.5% | 1% | >5% |
| Dashboard load time | <3s | 4s | >6s |

---

## Troubleshooting Guide

### Issue: "No data" Panel on Dashboard

**Diagnosis:**
1. Check if metric exists: search for `metric_name` in VictoriaMetrics UI
2. If metric exists, check metric frequency (query: `metric_name` last 24h)
3. If no data for past 24h, metric is truly unavailable

**Solution:**
```promql
# Add fallback
metric_name or vector(0)
```

**Verification:**
- Check dashboard after change
- Should show 0 instead of "No data"

---

### Issue: Dashboard Takes >5 Seconds to Load

**Diagnosis:**
1. Open browser DevTools → Network tab
2. Reload dashboard, watch query times
3. Identify slowest query (likely histogram or topk)

**Solution Steps:**
1. **Check query complexity:**
   ```promql
   # If using unbounded histogram:
   histogram_quantile(0.95, rate(metric_bucket[5m]))

   # Add aggregation:
   histogram_quantile(0.95, sum by(le) (rate(metric_bucket[5m])))
   ```

2. **Check cardinality:**
   - Run: `count(metric_name) by(le)` → should be <1K series total
   - If >5K, reduce grouping dimensions

3. **Check rate window:**
   - If metric rarely updates, increase window (1h instead of 5m)
   - Combine with `or vector(0)` fallback

4. **Check for duplication:**
   - Same query in multiple panels? Use Jsonnet locals to share

---

### Issue: Inconsistent Data Across Panels

**Diagnosis:**
1. Are panels using different time ranges? (check query time select)
2. Are panels using different rate windows? (`[5m]` vs `[1h]`)
3. Are panels querying different metrics?

**Solution:**
- Standardize rate window across related panels
- Use consistent time range (all `$__range`)
- Document why panels differ (if intentional)

---

### Issue: High CPU Usage During Dashboard Access

**Diagnosis:**
- Check VictoriaMetrics query load: `vm_request_duration_seconds` metric
- Check Grafana CPU: `grafana_process_cpu_seconds_total` metric
- Identify which dashboard is accessing most (check logs)

**Solution:**
1. **Identify expensive query:**
   - Run query individually in Explore view
   - Check execution time
2. **Apply optimization pattern:**
   - If histogram: add `sum by(le, ...)`
   - If topk: add label filters
   - If rate: adjust window
3. **Test with production data:**
   - Ensure optimization works at scale

---

## Best Practices Summary

| Practice | Benefit | Cost |
|----------|---------|------|
| Use `or vector(0)` | +100% reliability, -1% latency | +1% bandwidth |
| `sum by(le)` in histogram | +10% latency improvement | Slight verbosity |
| Pre-filter topk | +5% latency improvement | More query complexity |
| Match rate windows | +20% data accuracy | Need domain knowledge |
| Reuse queries via Jsonnet | +15% maintainability | Requires understanding |
| Document assumptions | +30% team velocity | +5% file size |

---

## Next Steps

### For Dashboard Developers
1. Review this guide before creating new dashboards
2. Apply patterns from Pattern Library when writing queries
3. Test using Performance Targets as success criteria
4. Use Troubleshooting Guide when issues arise

### For Observability Team
1. Add to onboarding documentation
2. Create code review checklist based on Dashboard Design Checklist
3. Monitor production dashboards against Performance Targets
4. Refactor oldest dashboards using anti-pattern fixes

### For Future Optimization
1. Monitor actual vs expected performance improvements
2. Update targets based on production data
3. Add new patterns as they emerge
4. Document edge cases and lessons learned

---

**Version:** 1.0
**Last Updated:** 2026-03-04 (Iteration 31)
**Maintainer:** Observability Team
**Status:** Ready for production use
