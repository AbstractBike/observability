# Dashboard Troubleshooting Runbooks

Documentación consolidada de runbooks para guías de troubleshooting en dashboards.

## Infrastructure — Heater Machine

### System Performance Issues

**Symptom: High CPU Usage**
- Check: `Heater — System` dashboard, CPU stat panel
- Query: `rate(node_cpu_seconds_total[5m])` 
- Investigation: Top processes in `Heater — Processes` dashboard
- Remediation: Kill non-essential processes, check for runaway workloads

**Symptom: Memory Pressure**
- Check: Memory utilization in `Heater — System` dashboard
- Query: `100 * (1 - (node_memory_MemFree_bytes / node_memory_MemTotal_bytes))`
- Investigation: Top processes by memory in `Heater — Processes`
- Remediation: Restart memory-heavy services, tune JVM heap in `Heater — JVM`

**Symptom: Disk I/O Saturation**
- Check: Disk utilization in `Heater — System` dashboard
- Query: `rate(node_disk_io_time_ms_total[5m])`
- Investigation: I/O operations by device in system dashboard
- Remediation: Check for slow queries (PostgreSQL), optimize indexing

### GPU Acceleration Issues

**Symptom: GPU Memory Exhaustion**
- Check: GPU memory utilization in `Heater — GPU` dashboard
- Query: `nvidia_smi_memory_used_mb / nvidia_smi_memory_total_mb`
- Investigation: GPU processes in `Heater — Processes`
- Remediation: Reduce batch size in training jobs, release unused GPU memory

**Symptom: GPU Utilization Too Low**
- Check: GPU utilization stat in `Heater — GPU` dashboard
- Query: `nvidia_smi_utilization_gpu_percent`
- Investigation: Check if workloads are running
- Remediation: Increase parallelism, profile kernel for bottlenecks

### JVM Monitoring

**Symptom: JVM Heap Pressure**
- Check: Heap utilization in `Heater — JVM` dashboard
- Query: `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}`
- Investigation: GC pause frequency and duration
- Remediation: Increase heap size, tune GC algorithm, find memory leaks with profiler

**Symptom: High GC Pause Time**
- Check: GC pause duration in `Heater — JVM` dashboard
- Query: `rate(jvm_gc_pause_seconds_sum[5m]) / rate(jvm_gc_pause_seconds_count[5m])`
- Investigation: GC frequency and pause count
- Remediation: Tune GC collector (G1GC, ZGC), increase heap, reduce object allocation

---

## Observability Stack

### Alerts System

**Symptom: Alerts Not Firing**
- Check: `Alerts Dashboard` alert count panel
- Query: `count(ALERTS)` vs expected alert rules
- Investigation: Check VMAlert targets in `VMAlert Dashboard`
- Remediation: Verify alert rules in Grafana, check data source connectivity

**Symptom: Alert Fatigue (Too Many Alerts)**
- Check: Alert count in `Alerts Dashboard`
- Query: `count(ALERTS) by severity`
- Investigation: Filter by severity in `Alertmanager Dashboard`
- Remediation: Tune thresholds, add suppression rules, group related alerts

### Logs Processing

**Symptom: Logs Not Appearing**
- Check: `Logs Dashboard` panel for log count
- Query: `count(logs)` by service in VictoriaLogs
- Investigation: Check Vector pipeline in `Pipeline — Vector` dashboard
- Remediation: Verify log source configuration, check network connectivity to VictoriaLogs

**Symptom: High Log Volume**
- Check: Log ingestion rate in `Logs Dashboard`
- Query: `rate(vector_processed_events_total[5m])`
- Investigation: Check which services are logging most
- Remediation: Reduce verbose logging, adjust log level for high-volume services

### Tracing (SkyWalking)

**Symptom: Traces Missing**
- Check: Service count in `Pin Traces — APM Overview`
- Query: SkyWalking service list in SkyWalking UI
- Investigation: Check instrumentation status in `Heater — Claude Code` for agent status
- Remediation: Deploy SkyWalking agent, verify network connectivity to OAP (192.168.0.4:11800)

**Symptom: Trace Latency High**
- Check: P99 latency in `Pin Traces — APM Overview`
- Query: `histogram_quantile(0.99, rate(meter_service_resp_time_bucket[5m]))`
- Investigation: Check top services by latency in service grid
- Remediation: Profile slow services, optimize database queries, check network

---

## Services

### Database Services

**PostgreSQL — Slow Queries**
- Check: `Services — PostgreSQL` dashboard, query performance panel
- Query: `rate(pg_stat_user_tables_seq_scan[5m])` for full table scans
- Investigation: Check query logs for sequential scans
- Remediation: Add indexes, rewrite queries, update statistics with ANALYZE

**Redis — Eviction Policy**
- Check: `Services — Redis` dashboard, evicted keys counter
- Query: `redis_evicted_keys_total`
- Investigation: Check memory utilization vs max memory
- Remediation: Increase max memory, adjust eviction policy, optimize key design

**ClickHouse — Slow Insert Rate**
- Check: `Services — ClickHouse` dashboard, insert latency
- Query: `rate(clickhouse_table_insert_elapsed_microseconds_total[5m])`
- Investigation: Check table compression and replication
- Remediation: Batch inserts, tune insert settings, check disk I/O

### Message Bus

**Redpanda — Topic Lag**
- Check: `Services — Redpanda` dashboard, consumer lag panel
- Query: Lag by consumer group in Redpanda Console
- Investigation: Check if consumer is stuck
- Remediation: Restart consumer, check for processing errors, scale consumers

---

## APM & Tracing

**Symptom: Service Error Rate Spike**
- Check: Error rate in `Pin Traces — APM Overview`
- Query: `rate(meter_service_resp_time_count{status="ERROR"}[1m])`
- Investigation: Check error logs in `Logs Dashboard`
- Remediation: Check recent deployments, review exception logs, verify dependencies

**Symptom: New Service Down**
- Check: Service count in `Pin Traces — APM Overview`
- Query: SkyWalking service list
- Investigation: Verify service is deployed and running
- Remediation: Check deployment status, verify network routing, enable logging

---

## Navigation by Severity

### CRITICAL
- Service unavailable: Check `Services Health` → specific service → logs
- Data loss: Check `Services — PostgreSQL`, `Services — ClickHouse` backup status
- High error rate (>5%): Check `Pin Traces — APM Overview`, then drill down by service

### WARNING
- High latency (>1000ms P99): Check `Pin Traces — APM Overview`, top services by latency
- Memory pressure (>80%): Check `Heater — System`, `Services` dashboards
- Disk filling up (>80%): Check `Heater — System` disk panel

### INFO
- Unusual traffic patterns: Check service dashboards for spikes
- Cost increases: Check `Cost Tracking` dashboard
- SLO budget consumption: Check `SLO — Overview`

---

## Quick Reference

| Issue | Primary Dashboard | Secondary Dashboard |
|-------|-------------------|---------------------|
| CPU high | Heater — System | Heater — Processes |
| Memory high | Heater — System | Services dashboards |
| Disk full | Heater — System | Cost Tracking |
| Service slow | Service-specific | Pin Traces — APM |
| Service down | Services Health | Service-specific |
| Errors spiking | Alerts Dashboard | Logs Dashboard |
| Traces missing | Pin Traces — APM | SkyWalking Dashboard |
| Logs missing | Logs Dashboard | Pipeline — Vector |

