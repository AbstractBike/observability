# Vector Pipeline Map

Source: `modules/vector.nix`

---

## Main Branch Pipeline

```
SOURCES                    TRANSFORMS                    SINKS
───────                    ──────────                    ─────

journald ──────────────► logs_normalize ─────────────► VictoriaLogs
(current boot)             (map PRIORITY→level,          http://127.0.0.1:9428/insert/jsonline
                            extract service,              stream fields: host, service, level
                            tag host="homelab",
                            strip journald internals)

host_metrics ─────────► metrics_tag_homelab ──────────► VictoriaMetrics
(CPU, disk, FS,            (add host="homelab")           http://127.0.0.1:8428/api/v1/write
 load, memory, net)
(scrape 15s)

internal_metrics ─────► metrics_tag_homelab ──────────► VictoriaMetrics
(Vector self-stats)
(scrape 15s)

claude_sessions ──────► parse_claude_sessions ────────► sessions_to_metrics ────► VictoriaMetrics
(~/.claude/projects/        (extract: input_tokens,        (counters per project/model)
 **/*.jsonl)                 output_tokens, cost_usd,       claude_session_input_tokens_total
                             project, model)                claude_session_output_tokens_total
                                                            claude_session_cost_usd_total
```

---

## Worktree Branch (pin-si-hub) — Additional Sources

```
SOURCES                    TRANSFORMS                    SINKS
───────                    ──────────                    ─────

HTTP :9195 ────────────► parse_messages_sse ───────────► messages_to_metrics ────► VictoriaMetrics
(Nginx body_filter          (parse SSE stream:              claude_messages_duration_ms_total
 /v1/messages tap)           model, stop_reason,            claude_messages_ttfb_ms_total
                             duration_ms, ttfb_ms,          claude_messages_input_tokens_total
                             input_tokens, output_tokens)   claude_messages_output_tokens_total
                                                            claude_api_calls_total

HTTP :9192 ────────────► (passthrough) ───────────────► VictoriaMetrics
(claude_event_log)

HTTP :9193 ────────────► parse_segment_batch ──────────► segment_to_metrics ─────► VictoriaMetrics
(segment.io events)         (parse batch events)           claude_segment_events_total

HTTP :9194 ────────────► parse_datadog_logs ───────────► datadog_to_metrics ─────► VictoriaMetrics
(datadog logs)
```

---

## Adding a New Pipeline Stage

### New source (file-based logs):
```nix
# In modules/vector.nix — sources section
services.vector.settings.sources.my_service = {
  type = "file";
  include = [ "/var/log/my-service/*.log" ];
};
```

### New source (HTTP server):
```nix
services.vector.settings.sources.my_http_source = {
  type = "http_server";
  address = "127.0.0.1:9199";
  encoding = "json";
};
```

### New sink (metrics to VictoriaMetrics):
```nix
services.vector.settings.sinks.my_metrics_to_vm = {
  type = "prometheus_remote_write";
  inputs = [ "my_transform" ];
  endpoint = "http://127.0.0.1:8428/api/v1/write";
};
```

### New sink (logs to VictoriaLogs):
```nix
services.vector.settings.sinks.my_logs_to_vlogs = {
  type = "http";
  inputs = [ "my_source" ];
  uri = "http://127.0.0.1:9428/insert/jsonline";
  encoding.codec = "ndjson";
  request.headers."Content-Type" = "application/stream+json";
};
```

---

## Vector Health

- Self metrics exposed at: `http://127.0.0.1:8686` (internal API)
- Uptime alert: `VectorDown` fires if `vector_uptime_seconds{host="heater"}` absent 2m
- Pipeline error alert: `VectorErrorRate` fires if errors > 0.1/s for 2m
- Dashboard: `dashboards-src/pipeline/vector.jsonnet`
