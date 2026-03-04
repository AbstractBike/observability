# Instrumentation Agents Reference

How to instrument a service for traces, metrics, and logs in the homelab stack.

---

## Java

### SkyWalking Java Agent (recommended)

**Module:** `modules/skywalking-java-agent.nix`
**Version:** 9.6.0

```bash
# Add to JVM args
-javaagent:${SW_AGENT_JAR} \
-Dskywalking.agent.service_name=my-service \
-Dskywalking.collector.backend_service=192.168.0.4:11800
```

**Environment variables set by the NixOS module:**
```
SW_AGENT_JAR   = /path/to/skywalking-agent.jar
SW_OAP_SERVER  = 192.168.0.4:11800   (default, overridable)
```

**Log correlation:** SkyWalking Java agent auto-injects `trace_id` into MDC.
In Logback/Log4j2 add `%X{SW_CTX_TRACE_ID}` to your pattern, or use the JSON appender with MDC.

**Known limitation:** Do NOT use with JDK 11 + Elasticsearch (crashes with SIGSEGV — ServiceManagementClient bug).

**Spring Boot actuator metrics:**
Expose `/actuator/prometheus` and add a scrape target in `modules/victoriametrics.nix`.

---

## Python

### apache-skywalking

```python
from skywalking import agent, config

config.init(
    agent_name='my-service',
    collector_address='192.168.0.4:11800'
)
agent.start()
```

**Log correlation:** The Python agent auto-injects `trace_id` into log context.
Include `trace_id` in your JSON log formatter:
```python
import logging
import json

class JsonFormatter(logging.Formatter):
    def format(self, record):
        from skywalking.trace.context import get_context
        ctx = get_context()
        trace_id = str(ctx.segment.related_traces[0]) if ctx else ""
        return json.dumps({
            "_msg": record.getMessage(),
            "level": record.levelname.lower(),
            "service": "my-service",
            "host": "homelab",
            "trace_id": trace_id,
        })
```

---

## Go

### go2sky

```go
import (
    "github.com/SkyAPM/go2sky"
    "github.com/SkyAPM/go2sky/reporter"
)

r, _ := reporter.NewGRPCReporter("192.168.0.4:11800")
tracer, _ := go2sky.NewTracer("my-service", go2sky.WithReporter(r))
```

Pass trace context via `go2sky.TraceContext(ctx)` through your call chain.

---

## Rust

### tracing + tracing-opentelemetry → OTLP → SkyWalking

```toml
# Cargo.toml
[dependencies]
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
tracing-opentelemetry = "0.22"
opentelemetry = "0.21"
opentelemetry-otlp = { version = "0.14", features = ["grpc-tonic"] }
opentelemetry_sdk = "0.21"
```

```rust
use opentelemetry_otlp::WithExportConfig;
use tracing_opentelemetry::OpenTelemetryLayer;
use tracing_subscriber::{layer::SubscriberExt, Registry};

let tracer = opentelemetry_otlp::new_pipeline()
    .tracing()
    .with_exporter(
        opentelemetry_otlp::new_exporter()
            .tonic()
            .with_endpoint("http://192.168.0.4:11800")
    )
    .install_batch(opentelemetry_sdk::runtime::Tokio)?;

let subscriber = Registry::default()
    .with(tracing_opentelemetry::layer().with_tracer(tracer));

tracing::subscriber::set_global_default(subscriber)?;
```

**Log correlation:** Extract `trace_id` from the current span and include it in JSON logs:
```rust
use tracing::Span;
use opentelemetry::trace::TraceContextExt;

let trace_id = Span::current()
    .context()
    .span()
    .span_context()
    .trace_id()
    .to_string();
```

---

## Node.js / TypeScript

### OpenTelemetry → SkyWalking OAP

```bash
npm install @opentelemetry/sdk-node @opentelemetry/exporter-trace-otlp-grpc
```

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';

const sdk = new NodeSDK({
  serviceName: 'my-service',
  traceExporter: new OTLPTraceExporter({
    url: 'grpc://192.168.0.4:11800',
  }),
});

sdk.start();
```

---

## Any Language — SkyWalking Rover (eBPF)

**Zero code changes required.** Rover intercepts network traffic at the kernel level.

**Status:** Disabled in main branch (v0.7.0 lacks bare-metal process discovery).
**Module:** `modules/skywalking-rover.nix`
**Container:** `apache/skywalking-rover:0.7.0`

When enabled, Rover auto-discovers all running processes and reports spans to OAP at `127.0.0.1:11800`.
Useful for: services where you cannot modify code (third-party binaries, legacy apps).

---

## Prometheus Exporters (existing)

If the service has no native `/metrics` endpoint, use an exporter.
Existing exporters in `modules/exporters.nix`:

| Service | Exporter | Port |
|---------|---------|------|
| PostgreSQL | prometheus-postgres-exporter | :9187 |
| Redis | prometheus-redis-exporter | :9121 |
| Elasticsearch | prometheus-elasticsearch-exporter | :9114 |
| ClickHouse | built-in Prometheus endpoint | :9363 |
| Redpanda | built-in Prometheus endpoint | :9644 |

To add a new exporter: add a systemd service in `modules/exporters.nix` then add the scrape target in `modules/victoriametrics.nix`.

---

## Checklist — New Service Instrumentation

- [ ] Expose `/metrics` (Prometheus format) OR configure push to `:8428/api/v1/write`
- [ ] Add scrape target in `modules/victoriametrics.nix` (if scrape mode)
- [ ] Add SkyWalking agent / OTLP exporter pointing to `192.168.0.4:11800`
- [ ] Include `trace_id` in all structured JSON logs
- [ ] Ship logs to VictoriaLogs at `:9428/insert/jsonline` (via Vector or direct HTTP)
- [ ] Create a Grafana dashboard in `dashboards-src/<folder>/<service>.jsonnet`
- [ ] Add alert rules in `modules/alerts/<domain>.yaml`
- [ ] Document service in `observability/services.md`
