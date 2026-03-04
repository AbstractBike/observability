// Service Level Objectives (SLO) Overview Dashboard
//
// Track SLO compliance across all services:
// - Availability (uptime %)
// - Latency (response time targets)
// - Error rate (reliability %)
// - Throughput (capacity targets)
//
// Shows:
// - Current SLO status (on-track, at-risk, violated)
// - Budget remaining this month (for error budget)
// - Trend lines toward targets
// - Service comparison matrix

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── SLO Status Indicators ──────────────────────────────────────────────────

local overallSloHealthStat =
  g.panel.stat.new('Overall SLO Health')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((count(count by (service) (skywalking_trace_status_total{status="success"})) / count(count by (service) (skywalking_trace_status_total))) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 95.0 },
    { color: 'green', value: 99.0 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local availabilitySloStat =
  g.panel.stat.new('Availability SLO')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((count(up{job=~".*"}) / count(count by (job) (up{job=~".*"}))) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 99.5 },
    { color: 'green', value: 99.95 },
  ])
  + g.panel.stat.options.withColorMode('background');

local latencySloStat =
  g.panel.stat.new('Latency SLO (P95)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.95, sum by(le) (rate(skywalking_trace_latency_bucket[5m]))) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local errorBudgetStat =
  g.panel.stat.new('Error Budget Remaining')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(100 - ((count(skywalking_trace_status_total{status="error"}[30d]) / count(skywalking_trace_status_total[30d])) * 100)) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 20 },
    { color: 'green', value: 50 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── SLO Compliance Trends ──────────────────────────────────────────────────

local availabilityTrendTs =
  g.panel.timeSeries.new('Availability Trend (99.95% target)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(count(up{job=~".*"}) / count(count by (job) (up{job=~".*"}))) * 100', 'Current'),
    c.vmQ('99.95', 'Target'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local latencyTrendTs =
  g.panel.timeSeries.new('Latency Trend (500ms P95 target)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.95, sum by(le) (rate(skywalking_trace_latency_bucket[5m])))', 'Current'),
    c.vmQ('500', 'Target'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Service SLO Compliance Table ───────────────────────────────────────────

local serviceSloTable =
  g.panel.table.new('Service SLO Compliance Status')
  + c.pos(0, 7, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(20, sort_desc(avg by (service) (skywalking_trace_status_total{status="success"} / skywalking_trace_status_total)))',
      'Availability %'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('percent')
  + g.panel.table.options.withSortBy([
    { displayName: 'Availability %', desc: true },
  ]);

// ── SLO Violation Alerts ───────────────────────────────────────────────────

local sloViolationInfo =
  g.panel.text.new('⚠️ SLO Management Guide')
  + c.pos(0, 15, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Service Level Objectives (SLOs)

    **SLO** = Service Level Objective (what you commit to customers)
    **SLI** = Service Level Indicator (what you measure)
    **SLA** = Service Level Agreement (contract with penalties)

    ### Our SLO Targets

    | Service Type | Availability | Latency (P95) | Error Rate |
    |---|---|---|---|
    | **Critical (api-gateway)** | 99.95% | < 500ms | < 0.5% |
    | **High (databases, payment)** | 99.9% | < 1s | < 1.0% |
    | **Standard (cache, queues)** | 99.5% | < 100ms | < 2.0% |
    | **Internal (infrastructure)** | 99.0% | < 5s | < 5.0% |

    ### Error Budget

    **30-day error budget** (based on 99.95% availability):
    - Total requests: ~2.6B (assuming 1000 req/s)
    - Allowed errors: 13M (0.05%)
    - Budget remaining this month: Shows above

    If budget exhausted:
    1. Stop adding new features
    2. Focus only on reliability improvements
    3. Conduct post-mortems on outages

    ### Handling SLO Violations

    **If Latency SLO violated:**
    1. Check [Performance & Optimization](/d/performance-optimization)
    2. Identify slowest service pair
    3. Review [Service Dependencies](/d/service-dependencies)
    4. Run [Anomaly Detection](/d/observability-logs)

    **If Availability SLO violated:**
    1. Check [Services Health](/d/services-health)
    2. Review error logs for patterns
    3. Trigger incident response
    4. Post-mortem after resolution

    ### SLO Tiers (Recommended)

    - **Tier 1** (customer-facing): 99.95% availability, <500ms latency
    - **Tier 2** (internal services): 99.5%, <2s latency
    - **Tier 3** (batch, non-critical): 95%, <30s latency
  |||);

// ── Error Budget Burndown ──────────────────────────────────────────────────

local errorBudgetBurndownTs =
  g.panel.timeSeries.new('Error Budget Burndown (30-day window)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('100 - ((count(skywalking_trace_status_total{status="error"}[30d]) / count(skywalking_trace_status_total[30d])) * 100)', 'Remaining'),
    c.vmQ('50', 'Caution line (50%)'),
    c.vmQ('20', 'Critical line (20%)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local sloComplianceTs =
  g.panel.timeSeries.new('SLO Compliance by Service (Top 5)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(5, avg by (service) (skywalking_trace_status_total{status="success"} / skywalking_trace_status_total)) * 100',
      '{{service}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Service Level Objectives (SLO) Overview')
+ g.dashboard.withUid('slo-overview')
+ g.dashboard.withDescription('SLO compliance tracking: availability, latency, error rates, error budget burndown.')
+ g.dashboard.withTags(['observability', 'slo', 'slr', 'reliability', 'compliance'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('SLO Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  overallSloHealthStat, availabilitySloStat, latencySloStat, errorBudgetStat,

  g.panel.row.new('Compliance Trends') + c.pos(0, 4, 24, 1),
  availabilityTrendTs, latencyTrendTs,

  g.panel.row.new('Service Compliance') + c.pos(0, 6, 24, 1),
  serviceSloTable,

  g.panel.row.new('SLO Management') + c.pos(0, 14, 24, 1),
  sloViolationInfo,

  g.panel.row.new('Error Budget & Trends') + c.pos(0, 17, 24, 1),
  errorBudgetBurndownTs, sloComplianceTs,
])
