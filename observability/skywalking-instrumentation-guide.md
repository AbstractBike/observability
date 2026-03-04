# SkyWalking Instrumentation Guide

## Overview

This guide explains how to instrument services in the homelab to send distributed traces to SkyWalking OAP.

**SkyWalking OAP Endpoints:**
- **gRPC agent ingest**: `192.168.0.4:11800` (for language agents)
- **HTTP/GraphQL API**: `192.168.0.4:12800` (for manual trace submission)
- **UI**: `http://traces.pin` (service topology, trace inspection)

**All signals must include `trace_id` for correlation:**
- Traces (from SkyWalking agents)
- Logs (JSON field in Vector)
- Metrics (exemplars with trace_id)

---

## 1. Java Services

### Automatic Instrumentation (Recommended)

Use SkyWalking Java Agent — zero-code instrumentation via javaagent.

**Setup:**

1. **Download agent JAR** (already in homelab):
   ```bash
   # Agent is pre-downloaded in docker image or via Nix
   SKYWALKING_AGENT_JAR="/path/to/skywalking-agent.jar"
   ```

2. **Add JVM arguments** (for your Java service startup):
   ```bash
   java \
     -javaagent:${SKYWALKING_AGENT_JAR} \
     -Dskywalking.agent.service_name="my-service" \
     -Dskywalking.agent.instance_name="instance-1" \
     -Dskywalking.collector.backend_service="192.168.0.4:11800" \
     -Dskywalking.agent.trace_mode="GRPC" \
     -jar myapp.jar
   ```

3. **Required environment variable** (if using container):
   ```yaml
   environment:
     - SKYWALKING_AGENT_SERVICE_NAME=my-service
     - SKYWALKING_AGENT_INSTANCE_NAME=${HOSTNAME}
     - SKYWALKING_COLLECTOR_BACKEND_SERVICE=192.168.0.4:11800
   ```

4. **MDC correlation** (automatic in SkyWalking 8.0+):
   - SkyWalking automatically injects `trace_id` into SLF4J MDC
   - In your logs config (logback.xml), add:
     ```xml
     <property name="pattern">%d{ISO8601} %-5level %thread %logger{36} traceId=%X{traceId} - %msg%n</property>
     ```
   - Logs will now have `traceId` field → Vector picks it up as `trace_id`

### Manual Instrumentation (Advanced)

For fine-grained control, use the SkyWalking Java SDK:

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.apache.skywalking</groupId>
    <artifactId>apm-toolkit-trace</artifactId>
    <version>10.3.0</version>
</dependency>
<dependency>
    <groupId>org.apache.skywalking</groupId>
    <artifactId>apm-toolkit-logback-1.x</artifactId>
    <version>10.3.0</version>
</dependency>
```

```java
import org.apache.skywalking.apm.toolkit.trace.Trace;
import org.apache.skywalking.apm.toolkit.trace.TraceContext;

public class MyService {
    @Trace
    public void processRequest(String id) {
        String traceId = TraceContext.traceId();
        // traceId is now available in MDC for logs
        logger.info("Processing request", Map.of("trace_id", traceId));
    }
}
```

---

## 2. Python Services

### Using `apache-skywalking` SDK

**Installation:**
```bash
pip install apache-skywalking
```

**Initialization** (do this at app startup):

```python
from skywalking import agent

# Start agent before app initialization
agent.start(
    service_name="my-python-service",
    backend_service="192.168.0.4:11800"
)

# Then start your app (Flask, FastAPI, etc.)
```

**For Flask:**
```python
from flask import Flask
from skywalking import agent
from skywalking.trace.context import trace_id

agent.start(
    service_name="my-flask-app",
    backend_service="192.168.0.4:11800"
)

app = Flask(__name__)

@app.route("/")
def hello():
    current_trace_id = trace_id.get()  # Get trace_id for logging
    app.logger.info(f"Request handled", extra={"trace_id": current_trace_id})
    return "OK"

if __name__ == "__main__":
    app.run()
```

**For FastAPI:**
```python
from fastapi import FastAPI, Request
from skywalking import agent
from skywalking.trace.context import trace_id
import logging

agent.start(
    service_name="my-fastapi-app",
    backend_service="192.168.0.4:11800"
)

app = FastAPI()
logger = logging.getLogger(__name__)

@app.get("/")
async def hello(request: Request):
    current_trace_id = trace_id.get()
    logger.info("Handling request", extra={"trace_id": current_trace_id})
    return {"status": "ok"}
```

**Logging with trace_id** (Python standard library):

```python
import logging
import json
from skywalking.trace.context import trace_id

# JSON logging with trace_id
class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "trace_id": trace_id.get() or "",  # Inject trace_id
            "service": "my-python-service"
        }
        return json.dumps(log_data)

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger = logging.getLogger()
logger.addHandler(handler)
```

---

## 3. Go Services

### Using `go2sky` SDK

**Installation:**
```bash
go get github.com/SkyAPM/go2sky
```

**Initialization:**

```go
package main

import (
	"context"
	"github.com/SkyAPM/go2sky"
	"github.com/SkyAPM/go2sky/reporter"
	"github.com/SkyAPM/go2sky/reporter/grpc"
	"log"
	"os"
)

func main() {
	// Create GRPC reporter
	rpt, err := grpc.NewGRPCReporter("192.168.0.4:11800")
	if err != nil {
		log.Fatal(err)
	}

	// Create tracer
	tracer, err := go2sky.NewTracer("my-go-service", go2sky.WithReporter(rpt))
	if err != nil {
		log.Fatal(err)
	}

	// Use in request handler
	ctx, span, err := tracer.Start(context.Background())
	defer span.End()

	// span.SetOperationName("myOperation")
	// span.SetTag("http.method", "GET")

	log.Printf("Handling request with trace_id: %s", extractTraceID(span))
}

func extractTraceID(span go2sky.Span) string {
	// SkyWalking Go SDK doesn't expose trace_id directly
	// Must pass span through context and correlate via service topology
	return "trace_id_not_directly_available"
}
```

**Better approach for correlation:**

```go
import (
	"context"
	"github.com/SkyAPM/go2sky"
	"github.com/SkyAPM/go2sky/propagation"
)

func handleRequest(w http.ResponseWriter, r *http.Request) {
	// Extract trace context from incoming request
	span, ctx, err := tracer.StartLocalSpan(
		context.WithValue(r.Context(), "request_id", r.Header.Get("X-Request-ID")),
		"handleRequest",
	)
	defer span.End()

	// Pass context to logging
	log.Printf("Processing request", map[string]interface{}{
		"trace_id": r.Header.Get("X-Request-ID"),
		"service": "my-go-service",
	})
}
```

---

## 4. Node.js Services

### Using `skywalking-backend-js` SDK

**Installation:**
```bash
npm install skywalking-backend-js
```

**Initialization** (at app startup):

```javascript
const SwAgent = require('skywalking-backend-js');

SwAgent.start({
  serviceName: 'my-nodejs-service',
  serverAddr: '192.168.0.4:11800'
});

const express = require('express');
const app = express();

app.get('/', (req, res) => {
  // Trace ID is automatically in request context
  const traceId = req.headers['x-skywalking-trace-id'] || 'unknown';
  
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: 'info',
    service: 'my-nodejs-service',
    message: 'Handling request',
    trace_id: traceId
  }));

  res.json({ status: 'ok' });
});

app.listen(3000);
```

**With Pino logging (JSON):

```javascript
const SwAgent = require('skywalking-backend-js');
const pino = require('pino');

SwAgent.start({
  serviceName: 'my-nodejs-service',
  serverAddr: '192.168.0.4:11800'
});

const logger = pino({
  transport: {
    target: 'pino-pretty',
    options: {
      colorize: true
    }
  }
});

app.use((req, res, next) => {
  // Add trace_id to each request
  req.traceId = req.headers['x-skywalking-trace-id'] || 'unknown';
  next();
});

app.get('/', (req, res) => {
  logger.info({
    message: 'Handling request',
    trace_id: req.traceId,
    service: 'my-nodejs-service'
  });
  res.json({ status: 'ok' });
});
```

---

## 5. Rust Services

### Using `tracing` + OpenTelemetry + OTLP

**Cargo.toml:**
```toml
[dependencies]
tracing = "0.1"
tracing-opentelemetry = "0.21"
opentelemetry = { version = "0.20", features = ["trace"] }
opentelemetry-otlp = { version = "0.13", features = ["grpc-tonic"] }
tokio = { version = "1", features = ["full"] }
tracing-subscriber = { version = "0.3", features = ["json"] }
```

**Setup:**

```rust
use opentelemetry::global;
use opentelemetry_otlp::new_pipeline;
use tracing_subscriber::fmt::format::FmtSpan;
use tracing::{info, instrument};

#[tokio::main]
async fn main() {
    // Initialize OpenTelemetry with SkyWalking OAP
    let tracer = new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://192.168.0.4:12800")
                .with_service_name("my-rust-service"),
        )
        .install_batch(opentelemetry::runtime::Tokio)
        .expect("Failed to install OpenTelemetry tracer");

    // Set up tracing subscriber with JSON formatting
    tracing_subscriber::fmt()
        .json()
        .with_span_list(false)
        .with_span_events(FmtSpan::ACTIVE)
        .with_writer(std::io::stdout)
        .init();

    // Your app code
    process_request().await;
}

#[instrument(skip_all)]
async fn process_request() {
    info!("Processing request", service = "my-rust-service");
}
```

---

## 6. System-Level Tracing (eBPF)

### SkyWalking Rover — No Code Changes Required

Rover automatically captures:
- System calls (syscall tracing)
- Network flows (TCP/UDP connections)
- Process behavior (spawning, termination)

**Already deployed on homelab — no per-service setup needed.**

Access in SkyWalking UI:
1. Go to http://traces.pin
2. Select "Rover" or "System" to see kernel-level tracing
3. View network topology automatically discovered via network flows

---

## 7. Trace-to-Logs Correlation Setup

### Ensure logs include `trace_id`

For all services, structure logs as JSON with `trace_id` field:

```json
{
  "_msg": "Processing request",
  "_time": "2026-03-04T12:00:00Z",
  "service": "my-service",
  "level": "info",
  "host": "homelab",
  "trace_id": "abc123...def456"
}
```

### Vector Configuration

Add to `vector.toml` (already in homelab):

```toml
[sources.app_logs]
type = "file"
include = ["/var/log/myapp/*.log"]
json_encoding = "json"

[transforms.enrich_logs]
type = "remap"
inputs = ["app_logs"]
source = """
  .service = get_source_tag!("service")
  .host = get_hostname!()
  # trace_id is already in the JSON log
"""

[sinks.victorialogs]
type = "http"
inputs = ["enrich_logs"]
uri = "http://192.168.0.4:9428/insert/jsonline"
encoding.codec = "json"
```

### Verifying Correlation

1. **Get a trace from SkyWalking:**
   - Navigate to http://traces.pin/general/trace
   - Click any trace → note the Trace ID

2. **Search logs by Trace ID in Grafana:**
   - Open [Observability — Logs](/d/observability-logs)
   - Search: `trace_id:"<trace-id-from-skywalking>"`
   - Should return all logs for that request across all services

---

## 8. Quick Reference: Service Checklist

When adding a new service to homelab, ensure:

- [ ] **Metrics exported** to VictoriaMetrics (Prometheus `/metrics`)
- [ ] **Logs structured as JSON** with `service`, `level`, `host`, `trace_id` fields
- [ ] **Tracing enabled:**
  - Java: `-javaagent:skywalking-agent.jar` + service name
  - Python: `agent.start(service_name="...", backend_service="192.168.0.4:11800")`
  - Go: `go2sky` SDK initialized
  - Node.js: `skywalking-backend-js` started
  - Rust: OpenTelemetry OTLP exporter configured
  - Other: Pass `X-Request-ID` headers for manual correlation
- [ ] **Vector pipeline** tails logs and forwards to VictoriaLogs
- [ ] **Dashboard created** in `observability/dashboards-src/**/*.jsonnet`
- [ ] **Alerts configured** for critical error conditions
- [ ] **Runbooks documented** in `observability/alert-runbooks.md`

---

## 9. Troubleshooting

### Traces not appearing in SkyWalking UI

**Check OAP connectivity:**
```bash
# From service container/host
curl -v http://192.168.0.4:12800/graphql  # Should get HTTP 400 (no body)
```

**Check agent configuration:**
```bash
# Java: add this to javaagent startup
-Dskywalking.agent.logging.level=DEBUG
```

**Check service name:**
- Service name in agent must match what you see in SkyWalking UI
- Check: http://traces.pin/general/service

### Logs missing `trace_id`

**Verify agent is running:**
```bash
# Java: check logs for "SkyWalking agent is started"
# Python: check for "SkyWalking agent started"
```

**Ensure MDC/context propagation:**
- SkyWalking SDK must inject trace_id into logging context
- Logging config must include MDC variable in pattern

**Check Vector pipeline:**
```bash
# Verify logs are reaching Vector
curl -v http://192.168.0.4:9195/metrics | grep vector_log_events_total
```

### Traces show latency but logs don't match

**Check time synchronization:**
```bash
# Traces in SkyWalking, logs in Grafana must have overlapping timestamps
# Service clock skew → logs appear outside trace time window
timedatectl  # Check NTP status
```

---

## 10. Integration with Observability Stack

### Data Flow

```
Service (traced)
    ↓ gRPC (traces)
SkyWalking OAP (192.168.0.4:11800)
    ↓ Prometheus/metrics
VictoriaMetrics (192.168.0.4:8428)
    ↓ GraphQL/API
SkyWalking Grafana Plugin (service maps)
    
Service (logging)
    ↓ JSON (structured)
Vector
    ↓ HTTP POST
VictoriaLogs (192.168.0.4:9428)
    ↓ LogsQL
Grafana Logs UI
    
Log entry includes trace_id:
    ↓ Click trace_id
SkyWalking UI (http://traces.pin)
    ↓ Full trace waterfall
Correlate with logs
```

### Cross-Dashboard Workflows

1. **Trace → Logs:**
   - Find slow trace in [SkyWalking UI](http://traces.pin)
   - Copy Trace ID
   - Paste in [Observability — Logs](/d/observability-logs)
   - See all application logs for that trace

2. **Metrics → Traces:**
   - See latency spike in [Performance & Optimization](/d/performance-optimization)
   - Note timestamp + service
   - Go to [SkyWalking UI](http://traces.pin), filter by service + time
   - Click trace to see span waterfall

3. **Logs → Traces:**
   - See error in [Observability — Logs](/d/observability-logs)
   - Click `trace_id` field
   - Opens SkyWalking UI with that trace

---

## Next: Register Service Instrumentation

Once instrumented, update `observability/services-instrumentation.md`:

```markdown
## my-service

- **Metrics**: ✅ Prometheus `/metrics`
- **Logs**: ✅ JSON with trace_id (Vector forwarded)
- **Traces**: ✅ Java Agent / Python SDK / Go SDK
- **Dashboard**: ✅ [my-service](/d/my-service)
- **Alerts**: ✅ 3 rules (uptime, error rate, latency)
- **Instrumentation Date**: 2026-03-04
```

This keeps the observability stack synchronized across all services.
