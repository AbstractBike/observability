# 🎨 Icon & Emoji Standards

**Version:** 1.0
**Date:** 2026-03-04
**Scope:** All dashboard row headers and section titles

---

## 📋 Row Header Iconography

All dashboard row headers should follow this standard emoji convention for consistent visual navigation.

### Status & Health
```
📊 Status              — Current operational state, health metrics
🎯 Core               — Critical/important functionality
⚠️  Warnings           — Issues or degradation
✅ Health             — Health checks and uptime
```

### Performance & Optimization
```
⚡ Performance         — Performance metrics, latency, throughput
🚀 Optimization       — Optimization opportunities, improvements
📈 Trends             — Historical trends, growth patterns
🔴 Errors             — Error rates, failures, exceptions
```

### Infrastructure & Systems
```
🏗️ Infrastructure     — System-level metrics (CPU, memory, disk)
🖥️ Host               — Host-specific data
🔧 Configuration      — Configuration and setup
💾 Storage            — Disk, database storage, retention
```

### Data & Processing
```
📝 Logs               — Log data and streaming
🔄 Pipeline           — Data pipelines and ETL
📊 Metrics            — Metric data and collection
🗄️ Database            — Database-specific metrics
```

### Tracing & APM
```
📡 Tracing            — Distributed tracing, spans
🕵️ Traces             — Trace details and visualization
👥 Services           — Service topology and relationships
🔍 Discovery          — Service discovery, endpoints
```

### Quality & SLOs
```
📈 SLO                — Service level objectives
💯 Quality            — Quality metrics and scoring
🎯 Targets            — Target metrics and thresholds
📊 Analytics          — Analytics and analysis
```

### Observability Meta
```
🔬 Internal           — Internal/meta observability
🔧 Tools              — Monitoring tools and infrastructure
⚙️ Configuration       — System configuration
🎛️ Controls            — Controls and settings
```

### Development & Testing
```
🧪 Testing            — Test results and coverage
📝 Debug              — Debug information
🔬 Experimental       — Experimental features
🛠️ Development        — Development environment
```

---

## 🎨 Complete Icon Reference

### By Category

**Core Metrics:**
- 📊 Status/Dashboard
- 📈 Trends/Growth
- 🔴 Errors/Failures
- ⚡ Performance/Speed
- 💯 Quality/Health

**Systems:**
- 🏗️ Infrastructure
- 🖥️ Host/Server
- 💾 Storage/Disk
- 🔧 Tools/Configuration
- ⚙️ Settings

**Data Flow:**
- 📝 Logs
- 📡 Tracing/Signals
- 🔄 Pipelines
- 🗄️ Databases
- 📤 Exports

**Operations:**
- 🚀 Optimization
- 🎯 Targets/Goals
- 📋 Navigation/Index
- 💡 Tips/Guides
- 🔐 Security

**Special:**
- ✅ Success/Health
- ⚠️  Warning/Alert
- 🔬 Meta/Internal
- 🧪 Test/Experimental

---

## ✨ Usage Guidelines

### Row Header Format
```
{EMOJI} {CATEGORY_NAME}
```

### Examples
```
✅ Row.new('📊 Status')                    # Good: emoji + clear title
✅ Row.new('⚡ Performance & Optimization') # Good: emoji + descriptive
❌ Row.new('Status')                      # Bad: missing emoji
❌ Row.new('Performance')                 # Bad: ambiguous (which kind?)
```

### Panel Title Format
```
{EMOJI} {METRIC} — {SERVICE} — {CONTEXT}
```

### Examples
```
✅ "📊 Latency — API Gateway — p99"
✅ "⚡ CPU Usage — VictoriaMetrics — peak"
✅ "🔴 Error Rate — PostgreSQL — 5m avg"
❌ "Latency"                              # Bad: missing context
❌ "Query Performance"                    # Bad: ambiguous
```

---

## 🎨 Visual Consistency

### Color Palette (Optional CSS)

If applying colors, use these standardized hex codes:

```css
/* Status indicators */
--color-success:   #10b981  /* Green - healthy */
--color-warning:   #f59e0b  /* Amber - attention needed */
--color-error:     #ef4444  /* Red - critical */
--color-info:      #3b82f6  /* Blue - informational */

/* Categories */
--color-status:        #1f77b4  /* Blue */
--color-performance:   #ff7f0e  /* Orange */
--color-errors:        #d62728  /* Red */
--color-infrastructure: #2ca02c  /* Green */
--color-tracing:       #9467bd  /* Purple */
--color-meta:          #8c564b  /* Brown */
```

### Emoji Consistency Rules

1. **Every row header starts with emoji** (no exceptions)
2. **Use consistent emoji for same category** across all dashboards
3. **Emoji should match the content** (not decorative, semantic)
4. **One emoji per row** (clarity over decoration)

---

## 📊 Icon Legend for Quick Reference

```
OBSERVABILITY STACK
├─ 📊 Status           (Current health)
├─ ⚡ Performance      (Speed metrics)
├─ 🔴 Errors          (Failures/issues)
├─ 📈 Trends          (Historical data)
└─ 💯 Quality         (SLOs/health)

INFRASTRUCTURE
├─ 🏗️ Infrastructure   (System level)
├─ 🖥️ Host            (Server metrics)
├─ 💾 Storage         (Disk/retention)
├─ 🔧 Tools           (Monitoring tools)
└─ ⚙️ Configuration    (Settings)

DATA & PROCESSING
├─ 📝 Logs            (Log data)
├─ 📡 Tracing         (Distributed traces)
├─ 🔄 Pipeline        (Data flows)
├─ 🗄️ Database         (Data storage)
└─ 📤 Export          (Data egress)

OPERATIONS
├─ 🚀 Optimization    (Improvements)
├─ 🎯 Targets         (Goals/SLOs)
├─ 💡 Tips            (Guidance)
├─ 📋 Navigation      (Index/discovery)
└─ 🔬 Internal        (Meta observability)
```

---

## 🎓 Examples from This Session

### Logs Dashboard
```jsonnet
g.panel.row.new('📊 Analysis')      // Status emoji - shows analysis metrics
g.panel.row.new('📝 Logs')          // Logs emoji - log viewer panel
g.panel.row.new('🔴 Error Analysis') // Error emoji - error-focused analysis
```

### SkyWalking Dashboard
```jsonnet
g.panel.row.new('📊 Status')        // Status emoji
g.panel.row.new('⚡ JVM')           // Performance emoji for JVM metrics
g.panel.row.new('📡 Traces')        // Tracing emoji for trace panels
```

### Dashboard Index
```jsonnet
g.panel.row.new('🎯 Core Observability')           // Core services
g.panel.row.new('⚡ Performance & Optimization')    // Performance focus
g.panel.row.new('🏗️ Infrastructure & Databases')   // Infrastructure level
g.panel.row.new('🔧 Observability Stack')          // Tools/infrastructure
g.panel.row.new('📡 Application Tracing & APM')    // Tracing focus
```

---

## 🔄 Migration Guide (Existing Dashboards)

When updating existing dashboards:

1. **Identify row category** → Choose matching emoji
2. **Add emoji to row title** → Format: `{EMOJI} {TITLE}`
3. **Review consistency** → Ensure same categories use same emoji
4. **Test visually** → Verify emoji displays correctly

### Before/After
```
Before: g.panel.row.new('Status')
After:  g.panel.row.new('📊 Status')

Before: g.panel.row.new('JVM')
After:  g.panel.row.new('⚡ JVM')

Before: g.panel.row.new('Analysis')
After:  g.panel.row.new('📈 Analysis')
```

---

## ✨ Summary

These icon standards ensure:
- 🎯 **Consistency** — Same category = same emoji across all dashboards
- 🧭 **Navigation** — Visual scanning is faster with emoji cues
- 🎨 **Polish** — Professional, organized appearance
- 📚 **Accessibility** — Icons aid both visual and semantic understanding
- 🌍 **Universality** — Emoji works in all languages/locales

All new dashboards should follow these standards from day one.
Existing dashboards should be gradually updated to conform.

---

**Status:** ✅ Ready to apply across all 46+ dashboards
**Priority:** P5 (Low) — Aesthetic improvement, no functional impact
