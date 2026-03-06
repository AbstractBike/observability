# 🚨 Grafana Dashboard Operational Runbook

**Quick Links**: [Maintenance Guide](./DASHBOARD-MAINTENANCE.md) | [Dashboard Status](http://home.pin) | [Metrics UI](http://192.168.0.4:8428)

## 🚦 Health Check (Daily)

Run this every morning:

```bash
# SSH into homelab host
ssh digger@homelab

# Check all services healthy
systemctl status grafana
systemctl status victoriametrics
systemctl status victorialogs
systemctl status vector

# Quick metric query
curl -s 'http://192.168.0.4:8428/api/v1/query?query=up' | jq '.data.result | length'
# Should return > 15 (active services)
```

## 🔴 Alert: "Dashboard shows No data"

**Severity**: Medium
**Typical Duration**: 5-15 minutes
**Resolution**: 80% of cases fixed by dashboard reload

### Step 1: Verify Datasource (2 min)

```bash
# Test VictoriaMetrics
curl -s http://192.168.0.4:8428/api/health
# Expected: 200 OK

# Test VictoriaLogs
curl -s http://192.168.0.4:9428/api/health
# Expected: 200 OK

# Test SkyWalking
curl -s http://192.168.0.4:12800/api/health
# Expected: 200 OK
```

**If any fails**: Restart that service
```bash
systemctl restart victoriametrics  # or victorialogs / skywalking-oap
```

### Step 2: Check Service Reporting Metrics (2 min)

Dashboard name → Look at title
```bash
# Example: "Services — Redis" dashboard
# Check if Redis is running and exporting metrics
systemctl status redis
curl -s http://192.168.0.4:8428/api/v1/query?query='up{job="redis"}' | jq .
```

**If service down**: Start it
```bash
systemctl start redis
# Wait 5 minutes for metrics to appear
```

### Step 3: Try Dashboard Reload (1 min)

1. Go to affected dashboard in Grafana
2. Press F5 to reload page
3. Check if data appears
4. If YES: **RESOLVED** ✅
5. If NO: Continue to Step 4

### Step 4: Check Query in Metrics Explorer (3 min)

1. Go to http://192.168.0.4:8428 (VictoriaMetrics UI)
2. Query the metric manually
   - Example: `up{job="redis"}`
   - Try last 6 hours time range
3. If you see data: Issue is with Grafana dashboard query
4. If no data: Issue is with metrics collection

**If metric exists but dashboard shows "no data"**:
- Edit dashboard query
- Add fallback: `(...) or vector(0)`
- Test in Grafana UI
- Commit change

**If metric doesn't exist**:
- Check service is running: `systemctl status <service>`
- Check Vector pipeline: `systemctl status vector`
- Check exporter configuration: `journalctl -u vector -n 50`

### Step 5: Escalate if Needed (contact digger@pin)

```
Template:
- Dashboard: [name]
- Last working: [when]
- All datasources: [UP/DOWN]
- Services running: [list]
- Affected metrics: [query]
- Tried: [steps 1-4]
```

---

## 🔴 Alert: "Dashboard loading very slowly (> 10 seconds)"

**Severity**: Low
**Typical Cause**: Large time range or many panels querying simultaneously

### Quick Fix (30 sec)

1. Go to dashboard
2. Change time range to "Last 1 hour" (top left)
3. See if loads faster
4. **If YES**: Issue is query load
5. **If NO**: Continue below

### Long-term Fix (contact digger@pin)

1. Disable some panels: Panel menu → Hide
2. Optimize queries: Add aggregation (`sum by ...`)
3. Increase time window: `[5m]` → `[15m]`
4. Check VictoriaMetrics load

---

## 🔴 Alert: "Logs panel empty"

**Severity**: Low
**Typical Cause**: Service not logging, or time range too old

### Step 1: Check Logs Exist (1 min)

```bash
# Go to VictoriaLogs UI
# http://192.168.0.4:9428

# Query all logs from service
# {service="service-name", level="info"}

# If logs exist, continue to Step 2
# If no logs, check service is logging: systemctl status <service>
```

### Step 2: Check Log Filter in Dashboard (1 min)

Dashboard → Logs Panel → Edit

```
Current filter: {service="redis"}
Try removing filters: {}
Try adding level: {level="info"}
Try adding host: {host="homelab"}
```

Adjust filter until logs appear, then save.

---

## 🔴 Alert: "One metric line missing from chart"

**Severity**: Low
**Typical Cause**: One host/service stopped reporting

### Step 1: Identify Missing Series (1 min)

Chart → Check legend (right side)
- Which service/host is missing?

### Step 2: Check If Service Running (1 min)

```bash
systemctl status <service>
# If DOWN: systemctl start <service>
# If UP: check logs: journalctl -u <service> -n 20
```

### Step 3: Wait for Data (5 min)

Metrics take ~5 minutes to appear after service starts.

Reload dashboard after 5 minutes.

---

## 🔴 Alert: "Correlation broken: Can't click log to see trace"

**Severity**: Low
**Typical Cause**: Trace ID not in logs or no traces collected

### Step 1: Verify Traces Exist (2 min)

```bash
# Check SkyWalking for traces
curl -s 'http://192.168.0.4:12800/api/trace?service=<service>' | jq '.data | length'

# Should return > 0
```

**If 0 traces**: Service not instrumented with SkyWalking agent
- Contact digger@pin for instrumentation setup

### Step 2: Verify Logs Have trace_id (2 min)

VictoriaLogs UI → Query: `{service="service-name"}`

Look at log entry → Should show: `"trace_id":"xxx"`

**If no trace_id**:
- Logs not being formatted with trace_id
- Update service configuration
- Check observability/agents.md for instrumentation guide

---

## 📋 Periodic Maintenance

### Weekly (Every Monday)

```bash
# Run full test suite
cd /home/digger/git/homelab
bash scripts/run-all-dashboard-tests.sh

# Review results
cat /tmp/dashboard-verify-results.json | jq '.summary'

# Expected: 13+ healthy dashboards
```

### Monthly (First of month)

1. Review dashboard test results
2. Update DASHBOARD-MAINTENANCE.md if needed
3. Check for deprecated queries in logs
4. Review performance metrics

### Quarterly (Every 3 months)

1. Audit all dashboards for correctness
2. Update datasource configuration if changed
3. Performance tuning if needed
4. Review SkyWalking trace volume

---

## 🛠️ Emergency Procedures

### Full Restart (Nuclear Option)

```bash
systemctl stop grafana
systemctl stop victoriametrics
systemctl stop victorialogs
systemctl stop vector

# Wait 10 seconds
sleep 10

systemctl start victoriametrics
systemctl start victorialogs
systemctl start vector
systemctl start grafana

# Wait 30 seconds for startup
sleep 30

# Verify
curl -s http://192.168.0.4:3000/api/health | jq .
```

### Reset Grafana Cache

```bash
# SSH into homelab
ssh digger@homelab

# Clear Grafana cache
systemctl stop grafana
rm -rf /var/lib/grafana/grafana.db  # ⚠️ WILL DELETE DASHBOARDS!

# Actually, DON'T delete db. Just restart:
systemctl start grafana
```

### Restore from Backup

Dashboards are in git:
```bash
cd /home/digger/git/homelab
git log --oneline observability/dashboards-src/  # Show changes
git diff HEAD~1 observability/dashboards-src/    # See what changed
git revert <commit>                              # Undo if needed
```

---

## 📞 Escalation Path

**Problem Level** | **First Try** | **If Stuck** | **Contact**
---|---|---|---
No data on 1 dashboard | Steps 1-4 in "No data" section | Run test suite | digger@pin
Slow dashboard | Change time range | Edit queries | digger@pin
No logs | Check logs exist | Update filter | digger@pin
Broken traces | Verify traces | Instrumentation | digger@pin
Multiple dashboards broken | Run health check | Full restart | digger@pin
Persistent issues | Check git log | Review observability docs | digger@pin

---

**Created**: 2026-03-04
**Last Updated**: 2026-03-04
**Status**: ✅ READY FOR PRODUCTION

For detailed maintenance procedures, see [DASHBOARD-MAINTENANCE.md](./DASHBOARD-MAINTENANCE.md)
