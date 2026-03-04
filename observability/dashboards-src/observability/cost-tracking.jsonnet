// Cost Tracking Dashboard
//
// Monitor resource consumption and estimated costs across all services.
// Tracks CPU, memory, storage, and network metrics to calculate cost allocation.

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Cost Summary Stats ──────────────────────────────────────────────────────

local totalCostStat =
  g.panel.stat.new('💰 Est. Monthly Cost')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(process_resident_memory_bytes[30d]) * 0.01 + rate(container_cpu_usage_seconds_total[30d]) * 0.05) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('background');

local cpuCostStat =
  g.panel.stat.new('📊 CPU Cost (30d)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(container_cpu_usage_seconds_total[30d]) * 0.05) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value');

local memoryCostStat =
  g.panel.stat.new('💾 Memory Cost (30d)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(process_resident_memory_bytes[30d]) * 0.01) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value');

local storageCostStat =
  g.panel.stat.new('🗄️ Storage Cost (30d)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(vm_data_size_bytes or vector(0)) * 0.000001 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('currencyUSD')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value');

// ── Cost by Service (Top 10) ────────────────────────────────────────────────

local serviceCostTable =
  g.panel.table.new('Cost by Service (Top 10)')
  + c.pos(0, 4, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('topk(10, sum by (job) (rate(container_cpu_usage_seconds_total[30d]) * 0.05 + rate(process_resident_memory_bytes[30d]) * 0.01) or vector(0))'),
  ])
  + g.panel.table.standardOptions.withUnit('currencyUSD')
  + g.panel.table.standardOptions.withDecimals(2)
  + g.panel.table.fieldConfig.defaults.custom.withAlign('center');

// ── Cost Trends ─────────────────────────────────────────────────────────────

local costTrendTs =
  g.panel.timeSeries.new('Daily Cost Trend (7d)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(container_cpu_usage_seconds_total[1d]) * 0.05 + rate(process_resident_memory_bytes[1d]) * 0.01) or vector(0)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local cpuVsMemoryTs =
  g.panel.timeSeries.new('CPU vs Memory Cost (30d)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(container_cpu_usage_seconds_total[30d]) * 0.05)', 'CPU Cost'),
    c.vmQ('sum(rate(process_resident_memory_bytes[30d]) * 0.01)', 'Memory Cost'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('currencyUSD')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Cost Analysis Info ──────────────────────────────────────────────────────

local infoPanel =
  g.panel.text.new('💡 Cost Optimization Guide')
  + c.pos(0, 17, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Cost Drivers & Optimization

    **CPU Costs** ($0.05 per unit/30d):
    - Baseline: Core services (Grafana, VictoriaMetrics, Alertmanager)
    - High: Vector, ElasticSearch, ClickHouse
    - Optimization: Query caching, aggregation windows

    **Memory Costs** ($0.01 per GB/30d):
    - Monitor JVM services (Temporal, Elasticsearch, SkyWalking)
    - Watch for memory leaks in long-running processes
    - Optimization: Heap tuning, GC optimization

    **Storage Costs** ($0.000001 per byte/30d):
    - VictoriaMetrics: Primary cost driver (~85% of storage)
    - Cardinality management: High-cardinality metrics = high costs
    - Optimization: Reduce retention, drop unused labels

    ### Related Dashboards
    - **[Performance & Optimization](/d/performance-optimization)** — System bottlenecks
    - **[Metrics Discovery](/d/metrics-discovery)** — Cardinality analysis
    - **[Services Health](/d/services-health)** — Service efficiency
  |||)
  + g.panel.text.options.withMode('markdown');

// ── Logs panel ──────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Cost Tracking Logs', 'observability', y=20);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Cost Tracking')
+ g.dashboard.withUid('cost-tracking')
+ g.dashboard.withDescription('Infrastructure cost allocation and optimization: monitor resource consumption (CPU, memory, storage) and estimated monthly costs by service.')
+ g.dashboard.withTags(['observability', 'cost', 'optimization', 'budgeting'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Cost Summary') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  totalCostStat, cpuCostStat, memoryCostStat, storageCostStat,

  g.panel.row.new('Service Breakdown') + c.pos(0, 3, 24, 1),
  serviceCostTable,

  g.panel.row.new('Cost Trends') + c.pos(0, 11, 24, 1),
  costTrendTs, cpuVsMemoryTs,

  g.panel.row.new('Optimization Guide') + c.pos(0, 16, 24, 1),
  infoPanel,

  g.panel.row.new('Logs') + c.pos(0, 19, 24, 1),
  logsPanel,
])
