# 📊 Dashboard Consolidation Analysis — Iteration 8

**Date**: 2026-03-04
**Status**: Analysis Phase
**Goal**: Identify consolidation opportunities WITHOUT destructive changes

---

## Executive Summary

Analyzed 31 dashboards across 8 categories. Identified 3 minimal dashboards that could be enhanced or consolidated.

**Key Finding**: No destructive consolidation needed. Instead, **enrich minimal dashboards** with complementary data and improve navigation.

---

## Minimal Dashboards Identified

### 1. 📋 observability/logs.jsonnet (2 queries)
**Current**: All-services log exploration dashboard
**Queries**:
- Log volume by level (statsRange query)
- Live logs (raw logs panel with filters)

**Assessment**: ✅ KEEP + ENHANCE
- Already provides valuable utility (log filtering/searching)
- Could add: log patterns, error analysis, top error messages
- Non-redundant with other dashboards

**Enhancement Plan**:
- Add log error rate time series
- Add top 10 error messages table
- Add log ingestion rate trend

---

### 2. 🏠 overview/home.jsonnet (0 queries)
**Current**: Navigation hub with cards linking to all services/dashboards
**Panels**: All HTML/CSS cards (no metric queries)

**Assessment**: ✅ KEEP AS-IS (IRREPLACEABLE)
- This IS the landing page
- Core UI function
- No consolidation opportunity

---

### 3. 📊 slo/overview.jsonnet (2 queries)
**Current**: SLO compliance and error budget tracking
**Queries**:
- 4 SLO stat panels (compliance %)
- 4 error budget time series (budget remaining)

**Assessment**: ⚠️ KEEP + OPTIONALLY LINK TO SERVICES-HEALTH
- Provides specialized SLO tracking
- Complements services-health (which shows current status)
- Different purpose: SLO compliance vs. operational health

**Enhancement Plan**:
- Add link button to services-health dashboard
- Add SLO breach alerts table
- Add historical compliance trends

---

## Category Distribution Analysis

```
Observability (8)      → DENSE: alertmanager, alerts, grafana, logs, 
                         metrics-discovery, performance, skywalking, vmalert
                         ⚠️ Consider creating subcategories

Overview (4)           → BALANCED: home (hub), homelab, services-health, 
                         serena-backends

Services (9)           → OPTIMAL: One per service (redis, postgres, temporal, etc.)

Heater (5)             → OPTIMAL: One per component (system, jvm, gpu, 
                         processes, claude-code)

Pipeline (3)           → LIGHT: vector, arbitraje, arbitraje-dev

SLO (1)                → SINGLE: overview (SLO tracking)

APM (1)                → SINGLE: pin-traces (trace viewer)
```

---

## Consolidation Strategies (Non-Destructive)

### Strategy 1: Enrich Minimal Dashboards
**Target**: logs, slo/overview
**Action**: Add complementary panels without breaking existing queries
**Impact**: ✅ Zero disruption, pure enhancement

### Strategy 2: Create Dashboard Subcategories
**Target**: Observability (8 dashboards too dense)
**Proposal**:
```
observability/
  ├── system/         (vmalert, alertmanager, alerts, grafana)
  ├── metrics/        (metrics-discovery, performance)
  ├── tracing/        (skywalking)
  └── logs/           (logs - already here, maybe rename to core/)
```
**Impact**: Better organization, no content changes

### Strategy 3: Add Cross-Dashboard Navigation
**Action**: Add "Related Dashboards" links in:
- slo/overview → services-health
- performance → metrics-discovery
- alerts → vmalert

**Impact**: Improved UX, better discoverability

---

## Recommendation for Iteration 8-10

| Iteration | Task | Type | Complexity |
|-----------|------|------|------------|
| **8** | Enrich logs + SLO dashboards | Enhancement | Low |
| **9** | Add cross-dashboard navigation | UX | Low |
| **10** | Create observability subcategories | Organization | Medium |

---

## Non-Consolidation Items (Keep Separate)

These dashboards MUST remain independent:

1. **services-health** vs **slo/overview**: Different purposes
   - services-health = Current operational status
   - slo/overview = Compliance tracking

2. **logs** vs **observability/(others)**: Specialized tool
   - Provides interactive log exploration
   - Different query patterns than metrics dashboards

3. **performance** vs **metrics-discovery**: Complementary
   - performance = System performance KPIs
   - metrics-discovery = Metric catalog exploration

4. **alertmanager** vs **vmalert**: Different layers
   - vmalert = Rule evaluation
   - alertmanager = Alert routing/grouping

---

## Next Steps

✅ **Iteration 8 (Current)**: Enrich logs + SLO dashboards
- [ ] Add error analysis panels to logs dashboard
- [ ] Add SLO breach alerts to slo/overview dashboard  
- [ ] Test all dashboards compile without errors
- [ ] Update quality score

⏳ **Iteration 9**: Navigation improvements
- [ ] Add "related dashboards" links
- [ ] Improve dashboard descriptions
- [ ] Add category headers

⏳ **Iteration 10+**: Future optimizations
- [ ] Consider dashboard folder structure
- [ ] Implement dashboard usage analytics
- [ ] Create dashboard templates

---

**Status**: READY FOR ITERATION 8
