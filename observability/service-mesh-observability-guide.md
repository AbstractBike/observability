# Service Mesh Observability & Multi-Hop Tracing Guide

## Overview

This guide explains how to analyze distributed requests across multiple services, identify critical paths, and optimize end-to-end latency using SkyWalking traces and Grafana logs correlation.

## 1. Service Mesh Topology

### What is a Service Mesh?

A **service mesh** is a collection of services communicating via network requests (HTTP, gRPC, database connections, message queues).

**Example architecture:**

```
┌─────────┐
│ Client  │
└────┬────┘
     │ HTTP request
     ▼
┌─────────────────┐
│  API Gateway    │ ← Entry point (orchestrates backend calls)
└────┬────────────┘
     │
     ├─→ Order Service ──→ PostgreSQL ──→ Store orders
     │   (50ms)           (350ms)
     │
     ├─→ Payment Service ──→ Payment Gateway (external)
     │   (async, 200ms)
     │
     └─→ Notification Service
         (async, sends emails)

Total latency (critical path): 50 + 350 = 400ms
```

### Service Dependencies

Each service has **incoming** and **outgoing** dependencies:

| Service | Depends on | Used by |
|---|---|---|
| API Gateway | Order Service, Payment Service, Notification Service | Clients |
| Order Service | PostgreSQL, Redis | API Gateway |
| Payment Service | Payment Gateway (external) | API Gateway |
| PostgreSQL | None | Order Service |

---

## 2. Understanding Multi-Hop Traces

### Trace Propagation

When a request flows through multiple services, SkyWalking propagates the **trace ID** through all hops:

**Request flow:**

```
1. Client creates request
   User-Agent: curl/7.0
   
2. API Gateway receives request
   SkyWalking agent auto-generates trace_id = "abc123...def456"
   Injects into W3C Trace Context header: traceparent=00-abc123-span789-01
   
3. API Gateway → Order Service
   Propagates traceparent header with same trace_id
   Order Service receives header, starts span under same trace
   
4. Order Service → PostgreSQL
   Sends trace_id to database via SQL comments or tags
   Database operation executes, timing recorded
   
5. All responses return with same trace_id
   Response header includes X-Trace-ID: abc123...def456
   
6. SkyWalking OAP aggregates all spans into single trace
   Trace waterfall shows complete request execution timeline
```

### Span Hierarchy

Spans are nested to show the call stack:

```
Trace: abc123...def456
├─ Span: api_gateway.POST /api/orders (Client Entry)
│  ├─ Span: api_gateway→order_service (Exit call)
│  │  └─ Span: order_service.create_order (Entry)
│  │     ├─ Span: order_service→postgres (Exit)
│  │     │  └─ Span: postgres.INSERT (Exit in DB)
│  │     │     └─ Span: postgres.COMMIT (Exit in DB)
│  │     └─ Span: order_service→redis (Exit)
│  │        └─ Span: redis.SET (Exit in Cache)
│  └─ Span: api_gateway response (Client Exit)
└─ Total duration: 500ms
```

---

## 3. Analyzing Service Dependencies

### Using the Service Dependencies Dashboard

Open **[Service Dependencies & Mesh Topology](/d/service-dependencies)** to see:

1. **Total Services**: Count of all instrumented services
2. **Mesh Health**: % of successful requests (99.5% = excellent)
3. **Avg End-to-End Latency**: p50 latency across all requests (50ms = good)
4. **Service Relationships**: Number of service-to-service connections

### Service-to-Service Metrics Table

The "Service-to-Service Latency (Top 20)" table shows:

| From Service | To Service | Latency | Error Rate | Calls/min |
|---|---|---|---|---|
| api-gateway | order-service | 50ms | 0.1% | 120 |
| order-service | postgres | 350ms | 0.0% | 95 |
| order-service | redis | 2ms | 0.0% | 120 |
| payment-service | payment-gateway | 200ms | 2.1% | 30 |
| api-gateway | auth-service | 15ms | 0.0% | 500 |

**To investigate high latency:**
1. Click row in table (order-service → postgres: 350ms)
2. Note service pair
3. Go to [SkyWalking UI](http://traces.pin/general/topology)
4. Click on edge: order-service → postgres
5. Drill down into traces between these services
6. Identify slow queries, connection pool exhaustion, network latency

---

## 4. Identifying Critical Paths

A **critical path** is the longest synchronous chain of service calls that determines overall request latency.

### Critical Path Analysis

For order processing request:

**Path 1 (Critical):**
```
Client → API Gateway (10ms) → Order Service (40ms) → PostgreSQL (350ms) → Response
Total: 400ms ← THIS IS THE CRITICAL PATH
```

**Path 2 (Parallel):**
```
→ Payment Service (200ms) [async, doesn't block]
```

**Path 3 (Parallel):**
```
→ Notification Service (100ms) [async, doesn't block]
```

**Result:** Total request latency = 400ms (critical path dominates)

### Finding Critical Paths in Dashboards

1. Open **[Distributed Tracing](/d/skywalking-traces)**
2. Look for traces with high P99 latency
3. Open [SkyWalking UI](http://traces.pin/general/trace)
4. Click longest latency trace
5. Examine span waterfall:
   - Expand all spans
   - Identify longest single span (slowest operation)
   - Note service and operation name
   - This is your bottleneck

---

## 5. Optimizing Latency

### Latency Optimization Workflow

**Step 1: Measure Critical Path**

```json
{
  "trace_id": "abc123...def456",
  "total_latency": "500ms",
  "critical_path": "api-gateway → order-service → postgres",
  "critical_latency": "400ms",
  "optimization_potential": "80%"
}
```

**Step 2: Analyze Bottleneck**

If **postgres** is 350ms out of 400ms (87.5%):

```sql
-- Slow query identified
SELECT * FROM orders o
  LEFT JOIN items i ON o.id = i.order_id
  LEFT JOIN customers c ON o.customer_id = c.id
WHERE o.created_at > NOW() - INTERVAL '30 days'
ORDER BY o.created_at DESC
LIMIT 1000;

-- Problems:
-- 1. No index on o.created_at
-- 2. Fetches 1000 rows when only 10 needed
-- 3. LEFT JOINs scan large tables
```

**Step 3: Implement Fix**

```sql
-- 1. Add index
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- 2. Optimize query
SELECT o.id, o.customer_id, COUNT(*) as item_count
FROM orders o
WHERE o.created_at > NOW() - INTERVAL '7 days'  -- Narrower window
ORDER BY o.created_at DESC
LIMIT 10;  -- Paginate instead of fetching all

-- New query: 50ms (7x improvement!)
```

**Step 4: Measure Improvement**

Wait 5 minutes for traces to accumulate, then:

1. Go to **[Service Dependencies](/d/service-dependencies)**
2. Check "Service-to-Service Latency" table
3. order-service → postgres: 350ms → 50ms ✅
4. Total request: 400ms → 100ms ✅
5. **4x latency improvement** across entire request flow

### Optimization Strategies by Service Type

#### Application Services (Python, Node.js, Go)

**Problem**: Slow business logic
**Detection**: High span duration but low I/O latency
**Solutions**:
- Profile code with pprof (Go), cProfile (Python), clinic.js (Node.js)
- Use APM span tags to annotate slow operations
- Implement caching for repeated operations
- Use async/await for non-blocking I/O

#### Databases (PostgreSQL, Elasticsearch)

**Problem**: Slow queries
**Detection**: Span includes SQL query text (if available)
**Solutions**:
- Add indexes on WHERE, JOIN, ORDER BY columns
- Reduce result set size (pagination, filtering)
- Use EXPLAIN ANALYZE to profile query plans
- Consider materialized views for complex joins

#### Cache Services (Redis, Memcached)

**Problem**: Misses or evictions
**Detection**: High hit rate should be 90%+, if lower → misses
**Solutions**:
- Increase cache size if memory available
- Adjust eviction policy (LRU vs LFU)
- Adjust TTL based on data freshness requirements
- Monitor cache statistics in [Metrics Discovery](/d/metrics-discovery)

#### Message Queues (Kafka, RabbitMQ)

**Problem**: High consumer lag
**Detection**: Message processing time > expected
**Solutions**:
- Increase consumer parallelism (more workers)
- Optimize message processing logic
- Consider compression if network-bound
- Monitor partition distribution

---

## 6. Service Correlation Patterns

### Pattern 1: Sync Chain

```
Client → A → B → C → Response
```

**Characteristics:**
- Total latency = sum of all service latencies
- A calls B, waits for response before calling C
- One slow service blocks entire chain
- **Optimization**: Parallelize non-dependent calls

### Pattern 2: Parallel Fan-Out

```
        ┌→ Service B
Client → A → Service C → Response
        └→ Service D
```

**Characteristics:**
- A calls B, C, D in parallel
- Total latency = max(B, C, D) + A overhead
- One slow service blocks response
- **Optimization**: Timeout slow services, use fallback

### Pattern 3: Cascading/Aggregation

```
Client → API (orchestrator) → [B, C, D]
                              │ │ │
                              └─┼─┘
                                ↓
                           Database
```

**Characteristics:**
- API receives one request, fans out to multiple services
- All must complete before response
- **Optimization**: Cache results, use read replicas

### Pattern 4: Async/Fire-and-Forget

```
Client → Service A → Response
         (queues message for B to process)
         
Service B (async consumer)
├─ Process message
└─ No impact on Client response
```

**Characteristics:**
- A queues work for B without waiting
- Doesn't increase user-facing latency
- **Monitoring**: Track consumer lag, processing time

---

## 7. Trace-Based Optimization Workflow

### Complete Example: Order Processing

**Step 1: Monitor via Dashboard**

Visit **[Service Dependencies](/d/service-dependencies)**
- api-gateway → order-service latency: **50ms** ✅
- order-service → postgres latency: **350ms** ⚠️ (BOTTLENECK)
- order-service → redis latency: **2ms** ✅
- **Total: 400ms**

**Step 2: Drill Down**

1. Click [Distributed Tracing](/d/skywalking-traces)
2. Check "Error Rate by Service" — all 0.0% ✅
3. Check "Latency P95 by Service" — postgres is P95: 480ms
4. Go to [SkyWalking UI](http://traces.pin) → Topology
5. Click edge: order-service → postgres
6. View recent traces, sort by duration

**Step 3: Analyze Trace**

Open a slow trace (500ms total):
```
Trace: xyz789...abc123
├─ api-gateway.POST /api/orders [0ms-50ms]
│  └─ order-service.create_order [50ms-400ms]
│     ├─ order-service logic [50ms-55ms]
│     ├─ postgres.SELECT orders [55ms-405ms] ← SLOW (350ms!)
│     └─ redis.SET [405ms-407ms]
└─ Response sent [400ms-500ms]
```

**Postgres query text** (if captured): `SELECT * FROM orders...`

**Step 4: Get Logs**

1. Copy trace ID: xyz789...abc123
2. Go to [Observability — Logs](/d/observability-logs)
3. Search: `service:"order-service" AND trace_id:"xyz789...abc123"`
4. See logs from order-service showing query:
   ```json
   {
     "timestamp": "2026-03-04T12:34:56Z",
     "service": "order-service",
     "level": "debug",
     "message": "Executing query",
     "trace_id": "xyz789...abc123",
     "query": "SELECT * FROM orders WHERE created_at > NOW() - '30 days'",
     "duration_ms": 350
   }
   ```

**Step 5: Fix & Deploy**

Add index and optimize query (see section 5 above)

**Step 6: Verify Improvement**

Wait 5 minutes, then:
1. Go back to **[Service Dependencies](/d/service-dependencies)**
2. Check "Service-to-Service Latency" table
3. order-service → postgres: 350ms → **50ms** ✅
4. Congratulations: **7x improvement!**

---

## 8. Monitoring Service Dependencies

### Key Metrics to Watch

| Metric | Target | Alert if |
|---|---|---|
| Mesh Health (success %) | > 99.5% | < 99.0% |
| Avg End-to-End Latency | < 200ms | > 500ms |
| Service-to-Service Latency | < 100ms | > 500ms |
| Service Relationship Count | Stable | Rapidly increasing |
| Error Rate by Pair | < 0.5% | > 2.0% |

### Dashboard Checklist

- [ ] Monitor [Service Dependencies](/d/service-dependencies) weekly
- [ ] Review [Performance & Optimization](/d/performance-optimization) for trends
- [ ] Check [Alert Rules](/d/alerts-dashboard) for critical path violations
- [ ] Profile slow services using [Service Tracing Catalog](/d/service-tracing-catalog)

---

## 9. Advanced Topics

### Service Mesh Frameworks (Istio, Linkerd)

If using Istio or Linkerd, additional observability:

- **Sidecar metrics**: Envoy proxy metrics (connection pooling, retries)
- **mTLS**: Encrypted inter-service communication (latency overhead: 1-5ms)
- **Traffic management**: Rate limiting, circuit breaking
- **Advanced retry logic**: Automatic retries on failures

**In Grafana:**
- [Service Dependencies](/d/service-dependencies) already covers all traffic
- Sidecar metrics visible in Prometheus (if scraped)
- Combine with traces for full request context

### Service Mesh Pattern: Circuit Breaker

When calling a failing service (payment-gateway down):

```
┌─ Circuit breaker checks service health
│  └─ If error rate > threshold (5% for 30s)
│     └─ "Circuit opens" → start rejecting requests
│
├─ Fast fail: Return fallback response (e.g., "Try again later")
├─ Protects backend: Doesn't overwhelm failing service
└─ Faster user experience: User gets response immediately vs timeout
```

**In observability:**
- Watch "error-rate-by-pair" for payment-service
- Alert when error rate exceeds threshold
- Trace investigation: See "circuit breaker open" error tags

---

## 10. Related Dashboards & Tools

| Dashboard/Tool | Purpose |
|---|---|
| [Distributed Tracing](/d/skywalking-traces) | Central trace overview |
| [Service Dependencies](/d/service-dependencies) | Topology & critical paths |
| [Service Tracing Catalog](/d/service-tracing-catalog) | All service dashboards |
| [Observability — Logs](/d/observability-logs) | Trace-correlated logs |
| [Performance & Optimization](/d/performance-optimization) | Resource utilization |
| [SkyWalking UI](http://traces.pin) | Interactive topology, trace details |

---

## 11. Troubleshooting

### Problem: Missing Service Relationships

**Symptoms:** Service pair doesn't appear in table

**Causes:**
- Service not calling other service (by design)
- Service not instrumented yet
- Trace propagation headers not set

**Solution:**
1. Check service instrumentation status in [Service Tracing Catalog](/d/service-tracing-catalog)
2. Verify service names match (SkyWalking service_name)
3. Ensure W3C Trace Context headers are propagated

### Problem: High Latency, No Clear Bottleneck

**Symptoms:** Total latency 500ms, but all service pairs < 100ms

**Causes:**
- Network latency between services
- Connection pool exhaustion
- Request queuing in load balancer

**Solution:**
1. Check individual spans in [SkyWalking UI](http://traces.pin)
2. Look for gaps between spans (queueing time)
3. Monitor connection pool metrics

### Problem: Can't Find Slow Span in Trace

**Symptoms:** Trace waterfall shows total 500ms but can't account for time

**Causes:**
- Async operations (captured differently)
- Middleware/proxy overhead
- Client-side latency (before server processes)

**Solution:**
1. Check span tags for additional timing info
2. Add custom spans for untraced operations
3. Include client-side tracing (browser agents)

---

## Conclusion

Service mesh observability requires analyzing spans across service boundaries. By combining:

1. **Trace topology** (SkyWalking UI)
2. **Service metrics** (dashboards)
3. **Logs correlation** (trace_id)
4. **Performance data** (resource utilization)

You can identify and optimize critical paths, improving end-to-end request latency and system reliability.

**Next steps:**
- Set up alerts on service pair latencies
- Profile your slowest services
- Implement fixes and measure improvement
- Iterate towards target SLOs

---

## Quick Reference

**To analyze slow request:**

1. Open [Distributed Tracing](/d/skywalking-traces)
2. Note high latency time
3. Go [SkyWalking UI](http://traces.pin/general/trace)
4. Click slowest trace
5. Identify slowest span (service → operation)
6. Copy trace_id
7. Search in [Observability — Logs](/d/observability-logs)
8. See full context across services
9. Correlate with [Performance](/d/performance-optimization) metrics
10. Implement fix
11. Verify improvement in 5 minutes
