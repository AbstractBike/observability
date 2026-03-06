// Service Dependencies & Mesh Topology
//
// Advanced distributed tracing dashboard showing:
// - Service dependency graph (which services communicate)
// - Latency and error rates between services
// - Service-to-service call patterns and throughput
// - Request flow visualization
// - Multi-hop trace analysis (client → gateway → service → db → cache)
//
// Data sources:
// - SkyWalking OAP GraphQL API (service topology, service relations)
// - VictoriaMetrics (service-to-service metrics via trace spans)
// - VictoriaLogs (full request context across services)

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Service Topology Stats ────────────────────────────────────────────────

local alertPanel = c.alertCountPanel('skywalking', col=0);

// 5-stat layout: alert(6) + totalServices(4) + meshHealth(4) + avgLatency(5) + relationships(5) = 24
local totalServicesStat =
  g.panel.stat.new('Total Services')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (service) ({__name__=~"skywalking.*"}))'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local meshHealthStat =
  g.panel.stat.new('Mesh Health')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (count(skywalking_trace_status_total{status="error"}) / count(skywalking_trace_status_total))) * 100 or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 95 },
    { color: 'green', value: 99 },
  ])
  + g.panel.stat.options.withColorMode('background');

local avgEndToEndLatencyStat =
  g.panel.stat.new('Avg End-to-End Latency')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.50, sum by(le) (rate(skywalking_trace_latency_bucket[5m]))) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local serviceRelationshipsStat =
  g.panel.stat.new('Service Relationships')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (source_service,dest_service) (skywalking_service_relation_total)) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

// ── Service Dependency Graph Info ──────────────────────────────────────────

local dependencyGraphInfo =
  g.panel.text.new('📊 Service Dependency Topology')
  + c.pos(0, 4, 24, 2)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Distributed Service Graph

    **To view the service topology graph:**
    1. Open [SkyWalking UI](http://traces.pin/general/topology)
    2. Shows real-time service interactions
    3. Node color indicates health (green=healthy, yellow=warning, red=error)
    4. Edge thickness = traffic volume
    5. Hover over edge → see latency and error rate
    6. Click edge → drill down into service-pair traces

    **Edge information (service → service calls):**
    - Source service (left)
    - Destination service (right)
    - Latency (p95)
    - Error rate
    - Throughput (calls/min)

    **Service dependency types:**
    - **Direct**: A calls B directly
    - **Indirect**: A calls B via C (transitive)
    - **Cyclic**: A calls B, B calls A (potential deadlock?)
  |||);

// ── Service-to-Service Latency ─────────────────────────────────────────────

local serviceLatencyTable =
  g.panel.table.new('Service-to-Service Latency (Top 20)')
  + c.pos(0, 6, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(20, sort_desc(avg by (source_service,dest_service) (skywalking_service_relation_latency)))',
      'Latency'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('ms')
  + g.panel.table.options.withSortBy([
    { displayName: 'Latency', desc: true },
  ]);

// ── Service Call Patterns ──────────────────────────────────────────────────

local callVolumeByPairTs =
  g.panel.timeSeries.new('Call Volume Between Services (Top 5 pairs)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(5, sum by(source_service,dest_service) (rate(skywalking_service_relation_total[5m])))',
      '{{source_service}} → {{dest_service}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local errorRateByPairTs =
  g.panel.timeSeries.new('Error Rate Between Services (Top 5 with errors)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(5, (count by (source_service,dest_service) (skywalking_service_relation_status_total{status="error"}) / count by (source_service,dest_service) (skywalking_service_relation_status_total)) * 100)',
      '{{source_service}} → {{dest_service}}%'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Distributed Request Tracing ────────────────────────────────────────────

local multiHopTracesInfo =
  g.panel.text.new('🔗 Multi-Hop Request Tracing')
  + c.pos(0, 14, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Tracing Across Service Mesh

    **Request path example (client → gateway → service → db → cache):**

    1. **Client** makes HTTP request to api-gateway
    2. **API Gateway** (api-gateway service)
       - Trace ID: abc123... (injected by SkyWalking agent)
       - Operation: \`POST /api/orders\`
       - Latency: 500ms (total request time)
    3. **API Gateway calls Order Service** (order-service service)
       - Propagates trace ID via X-Trace-ID header
       - Span: \`order_service.create_order\`
       - Latency: 400ms (order service processing)
    4. **Order Service calls Database** (postgres service)
       - Same trace ID, new span
       - Span: \`postgres.INSERT orders\`
       - Latency: 350ms (database query)
    5. **Order Service checks cache** (redis service)
       - Span: \`redis.SET order:123\`
       - Latency: 2ms (cache write)
    6. **Response returned to client**

    ### Request Flow Timeline

    ```
    T=0ms:    Client → API Gateway [Trace ID: abc123]
    T=20ms:   API Gateway → Order Service
    T=50ms:   Order Service → PostgreSQL
    T=400ms:  PostgreSQL query completes
    T=420ms:  Order Service → Redis (cache)
    T=430ms:  Order Service response sent
    T=500ms:  API Gateway response sent to client
    ```

    ### Analyzing Multi-Hop Latency

    **Total latency breakdown:**
    - 500ms total
    - 50ms order-service.create_order overhead
    - 350ms database time (70% of total)
    - 2ms redis time
    - 98ms network/marshalling

    **Optimization opportunity:** Database query is 70% of latency → consider:
    - Query optimization (add index, reduce rows)
    - Caching results (avoid repeated queries)
    - Connection pooling (reduce connection overhead)

    ### How to investigate in Grafana + SkyWalking

    1. **Identify slow trace** in [Distributed Tracing](/d/skywalking-traces)
    2. **Open SkyWalking UI** → [Topology](http://traces.pin/general/topology)
    3. **Click specific trace** → See span waterfall
    4. **Hover over slow span** → Show query text, error, tags
    5. **Copy Trace ID** and search in [Observability — Logs](/d/observability-logs)
    6. **Correlate with logs** from all services in chain
  |||);

// ── Service Hop Analysis ───────────────────────────────────────────────────

local serviceHopCountTable =
  g.panel.table.new('Request Hops per Service (Avg calls involved)')
  + c.pos(0, 17, 24, 6)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(15, sort_desc(avg by (source_service) (skywalking_service_relation_count)))',
      'Avg Hops'
    ),
  ])
  + g.panel.table.standardOptions.withUnit('short')
  + g.panel.table.options.withSortBy([
    { displayName: 'Avg Hops', desc: true },
  ]);

// ── Critical Paths ──────────────────────────────────────────────────────────

local criticalPathsInfo =
  g.panel.text.new('⚠️ Critical Paths & Optimization')
  + c.pos(0, 23, 24, 3)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Identifying Critical Paths

    A **critical path** is the longest chain of synchronous service calls in a request.

    **Example: E-commerce order processing**
    ```
    Client → API Gateway → Order Service → [Database, Redis] → Response
                          └─ Payment Service → Payment Gateway (async)
                          └─ Notification Service (async)
    ```

    Critical path: Client → Gateway → OrderService → Database → Response

    **Optimization strategies by service:**

    | Service | Latency | Strategy | Impact |
    |---------|---------|----------|--------|
    | Database | 350ms | Add index, cache results | -80% |
    | Order Service | 50ms | Optimize business logic | -40% |
    | Network | 50ms | Connection pooling | -30% |
    | Cache | 2ms | No action needed | - |

    ### Related Dashboards

    - [Performance & Optimization](/d/performance-optimization) — Database + CPU analysis
    - [Observability — Logs](/d/observability-logs) — Full logs from critical path
    - [Services Health](/d/services-health) — Service availability
  |||);

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('skywalking', [
  { symptom: 'Service Topology Not Visible', runbook: 'skywalking/topology-missing', check: 'Verify agents are running and sending spans to SkyWalking OAP' },
  { symptom: 'High Latency Between Services', runbook: 'skywalking/service-latency', check: 'Check "Service-to-Service Latency" table and identify slowest pair' },
  { symptom: 'Service Errors in Mesh', runbook: 'skywalking/mesh-errors', check: 'Examine "Error Rate Between Services" for problematic connections' },
  { symptom: 'Circular Dependencies Detected', runbook: 'skywalking/circular-deps', check: 'Review topology for cyclic patterns in "Request Hops" analysis' },
], y=38);

// ── Logs panel ────────────────────────────────────────────────────────────

local logsPanel = c.serviceLogsPanel('Multi-Service Request Logs', 'all-services', y=27);

// ── Dashboard ──────────────────────────────────────────────────────────────

g.dashboard.new('Service Dependencies & Mesh Topology')
+ g.dashboard.withUid('service-dependencies')
+ g.dashboard.withDescription('Service mesh topology: dependencies, service-to-service latency, call patterns, multi-hop tracing, and critical path analysis.')
+ g.dashboard.withTags(['observability', 'tracing', 'service-mesh', 'topology', 'dependencies', 'advanced', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('🌐 Topology Overview') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, totalServicesStat, meshHealthStat, avgEndToEndLatencyStat, serviceRelationshipsStat,

  g.panel.row.new('📊 Service Graph') + c.pos(0, 3, 24, 1),
  dependencyGraphInfo,

  g.panel.row.new('🔗 Service Relations') + c.pos(0, 5, 24, 1),
  serviceLatencyTable,

  g.panel.row.new('📡 Call Patterns') + c.pos(0, 13, 24, 1),
  callVolumeByPairTs, errorRateByPairTs,

  g.panel.row.new('🔍 Multi-Hop Tracing') + c.pos(0, 14, 24, 1),
  multiHopTracesInfo,

  g.panel.row.new('➡️ Service Hops') + c.pos(0, 17, 24, 1),
  serviceHopCountTable,

  g.panel.row.new('🎯 Optimization Guide') + c.pos(0, 23, 24, 1),
  criticalPathsInfo,

  g.panel.row.new('📝 Request Logs') + c.pos(0, 26, 24, 1),
  logsPanel,

  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 37, 24, 1),
  troubleGuide,
])
