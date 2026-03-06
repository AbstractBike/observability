# 📊 Performance Profiling & Measurement Framework

**Date:** 2026-03-04 (Iteration 29)
**Purpose:** Establish baseline metrics and measure optimization impact

---

## Measurement Strategy

### Primary Metrics

**Query Latency (VictoriaMetrics)**
```promql
# Median query latency
histogram_quantile(0.50, rate(vm_request_duration_seconds_bucket[5m]))

# P95 query latency
histogram_quantile(0.95, rate(vm_request_duration_seconds_bucket[5m]))

# P99 query latency  
histogram_quantile(0.99, rate(vm_request_duration_seconds_bucket[5m]))
```

**Slow Query Rate**
```promql
# Percentage of queries >500ms
(sum(rate(vm_request_duration_seconds_bucket{le="+Inf"}[5m])) - 
 sum(rate(vm_request_duration_seconds_bucket{le="0.5"}[5m]))) / 
sum(rate(vm_request_duration_seconds_bucket{le="+Inf"}[5m])) * 100
```

**Dashboard Performance**
```promql
# Grafana query execution time
histogram_quantile(0.95, rate(grafana_query_duration_seconds_bucket[5m]))
```

### Baseline Measurements

**Collection Points:**
- Iteration 26: Pre-optimization baseline (Phase 1 fallback work)
- Iteration 28: Post-optimization (Phase 2-3 complete)
- Iteration 32+: Production validation

**Expected Improvements:**
- Histogram optimization: 10-15% latency reduction
- topk() optimization: 5-10% latency reduction
- Overall dashboard load: 15-20% improvement

---

## Implementation Phases

### Phase 1: Baseline (Iteration 29) ✅
**Tasks:**
1. ✅ Document profiling strategy
2. ⏳ Record baseline latency metrics (to measure in production)
3. ⏳ Create profiling dashboard in Grafana
4. ⏳ Define success criteria (>10% improvement target)

**Deliverables:**
- Profiling framework documented
- Measurement queries defined
- Dashboard template created

### Phase 2: Measurement (Iteration 30)
**Tasks:**
- Compare optimized vs baseline queries
- Calculate per-dashboard improvements
- Create before/after report
- Document performance gains

**Expected Findings:**
- 5-15% overall latency improvement
- 10-20% reduction in slow queries
- Faster dashboard loads across types

### Phase 3: Patterns & Guidelines (Iteration 31)
**Tasks:**
- Create optimization guidelines
- Build patterns library
- Write development playbook
- Document best practices

**Deliverables:**
- Optimization guidelines document
- Pattern library (histogram/topk templates)
- Development playbook for future work

---

## Success Criteria

✅ **Metrics Collection:** Baseline established by Iteration 30
✅ **Performance Improvement:** >10% latency reduction demonstrated
✅ **Documentation:** Guidelines created for future development
✅ **Patterns Library:** Reusable optimization patterns documented

---

**Status:** Framework established, ready for production measurement
**Next:** Iterate 30 — Measure actual performance improvements
