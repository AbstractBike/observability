# Alert Runbooks - Emergency Response Procedures

**Version**: 1.0  
**Last Updated**: 2026-03-04  
**Owner**: Infrastructure & SRE Team  

---

## 📋 Quick Reference

| Alert | Severity | Response Time | On-Call | Page |
|-------|----------|---------------|---------|------|
| ServiceDown | 🔴 Critical | Immediate | ✓ | ✓ |
| MultipleServicesDown | 🔴 Critical | Immediate | ✓ | ✓ |
| DatabaseDiskSpaceLow | 🔴 Critical | 5 minutes | ✓ | ✓ |
| ConsumerLagCritical | 🔴 Critical | 5 minutes | ✓ | ✓ |
| SystemHealthCritical | 🔴 Critical | 5 minutes | ✓ | ✓ |
| ErrorRateHigh | ⚠️ Warning | 30 minutes | - | - |
| LatencyHigh | ⚠️ Warning | 30 minutes | - | - |
| DatabaseSlowQueries | ⚠️ Warning | 30 minutes | - | - |
| CacheHitRateLow | ⚠️ Warning | 1 hour | - | - |

---

## 🔴 CRITICAL ALERTS

### 1. ServiceDown 🔴

**Alert**: One or more services have been unavailable for 2+ minutes

**Severity**: Critical  
**Response Time**: Immediate (< 5 minutes)  
**On-Call**: Yes  
**Page**: Yes  

**Symptoms**:
- Service stops responding
- Health checks failing
- Connections timing out
- Error rate: 100%

**Investigation Steps**:

1. **Confirm the alert**
   ```bash
   # Check service status in Grafana
   curl http://192.168.0.4:3000/d/services-health
   
   # Check service logs
   systemctl status <service-name>
   journalctl -u <service-name> -n 50
   ```

2. **Identify the root cause**
   ```bash
   # Check if service is running
   ps aux | grep <service-name>
   
   # Check port availability
   netstat -tlnp | grep <port>
   
   # Check for crashes
   dmesg | tail -20
   ```

3. **Check dependencies**
   - Is the database up? → Check Database Health dashboard
   - Is the cache up? → Check Cache Health dashboard
   - Is the network OK? → Check connectivity
   - Is disk space full? → `df -h`

**Recovery Actions**:

**Option 1: Service Restart (80% success rate)**
```bash
# Restart the service
systemctl restart <service-name>

# Wait for health check
sleep 10
systemctl status <service-name>

# Verify in dashboard (2-3 min for metrics to appear)
```

**Option 2: Check Logs for Errors**
```bash
# Stream recent logs
journalctl -u <service-name> -f

# Look for:
# - Connection refused
# - Out of memory
# - File not found
# - Permission denied
```

**Option 3: Database/Cache Issues**
- If database is down, restart it first
- If cache is down, restart cache and service
- Run migrations if needed

**Escalation**:
- After 5 min: Page on-call senior engineer
- After 15 min: Page team lead
- After 30 min: Start incident bridge

**Verification**:
```
✓ Service is running (ps aux)
✓ Port is listening (netstat)
✓ Health check passes (curl /health)
✓ Dashboard shows "Up" (green)
✓ Error rate returns to baseline
```

**Related Dashboards**:
- [Services Health](/d/services-health)
- [Observability — Logs](/d/observability-logs)
- [Alerts](/d/alerts-dashboard)

---

### 2. MultipleServicesDown 🔴

**Alert**: More than 2 services are down simultaneously

**Severity**: Critical  
**Response Time**: Immediate (< 5 minutes)  
**Indicates**: Infrastructure-level failure  

**Symptoms**:
- Multiple services unavailable
- Cascade failures likely
- Possible network or host issue
- Cascading errors across dashboards

**Investigation Steps**:

1. **Identify affected services**
   ```
   Go to: Services Health Dashboard
   Look for: Red/Down status items
   Count affected services
   ```

2. **Check infrastructure**
   ```bash
   # Host availability
   ping 192.168.0.4
   
   # SSH access
   ssh root@192.168.0.4
   
   # Resource availability
   free -h          # Memory
   df -h            # Disk
   top -b -n 1      # CPU
   ```

3. **Check common infrastructure components**
   - Network connectivity
   - Host CPU/Memory/Disk
   - Database availability
   - Cache availability
   - Shared storage (NFS, etc.)

**Recovery Actions**:

**Priority Order**:
1. Database (if down, everything fails)
2. Cache (if down, services slowdown)
3. Message Queues (if down, async processing fails)
4. Individual services (one by one)

```bash
# Step 1: Restart database
systemctl restart postgresql

# Wait 30 seconds
sleep 30

# Step 2: Restart cache
systemctl restart redis

# Step 3: Restart message queues
systemctl restart kafka

# Step 4: Restart services one by one
for service in api-server worker background-jobs; do
  systemctl restart $service
  sleep 10
done
```

**If host resources are exhausted**:
```bash
# Kill non-essential processes
killall node    # Node.js apps
killall python3 # Python apps

# Free up memory
sync; echo 3 > /proc/sys/vm/drop_caches

# Restart critical services
systemctl restart postgresql redis kafka
```

**Escalation**:
- Immediately: Page senior engineer + team lead
- After 5 min with no progress: Start incident bridge
- After 15 min: Page infrastructure team

**Verification**:
```
✓ All database queries responding
✓ Cache responding to requests
✓ Message queues processing messages
✓ Services returning to "Up" status
✓ Overall system health > 90%
```

---

### 3. DatabaseDiskSpaceLow 🔴

**Alert**: Database disk usage above 80%

**Severity**: Critical  
**Response Time**: 5 minutes  
**Action**: Free space or escalate  

**Investigation Steps**:

```bash
# Check disk space
df -h | grep postgres

# Check database size
psql -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database ORDER BY pg_database_size(pg_database.datname) DESC;"

# Check for large tables
psql -c "\dt+ *.*" | head -20

# Check WAL files (Write-Ahead Log)
du -sh /var/lib/postgresql/*/pg_wal/
```

**Recovery Actions**:

**Option 1: Clean up WAL files (Fastest - < 1 min)**
```bash
# WARNING: Only if replication is caught up
# Check replication lag first!

# Remove old WAL files
pg_archivecleanup -d /var/lib/postgresql/*/pg_wal/ \
  $(psql -t -c 'SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), '\'0/0\'') - 10 * 1024 * 1024 * 1024')

# Vacuum to reclaim space
psql -c "VACUUM FULL;"
```

**Option 2: Archive and delete old data (5-15 min)**
```bash
# Identify old data
SELECT COUNT(*) FROM table_name 
WHERE created_at < NOW() - INTERVAL '1 year';

# Archive to backup storage
pg_dump table_name > /backup/archive-2025.sql

# Delete archived data
DELETE FROM table_name 
WHERE created_at < NOW() - INTERVAL '1 year';

# Vacuum
VACUUM FULL table_name;
```

**Option 3: Reduce retention policy (Permanent fix)**
```bash
# Update data retention
ALTER TABLE events SET (autovacuum_vacuum_scale_factor = 0.01);

# Schedule cleanup jobs
pg_cron: SELECT cron.schedule('cleanup-old-events', '0 2 * * *', 
  'DELETE FROM events WHERE created_at < NOW() - INTERVAL ''6 months''');
```

**Escalation**:
- Immediately if < 5% remaining
- Page database admin if can't resolve
- Alert on capacity planning

**Prevention**:
```
• Set up monitoring for growth rate
• Archive old data monthly
• Implement retention policies
• Monitor transaction log size
```

---

### 4. ConsumerLagCritical 🔴

**Alert**: Kafka consumer lag exceeds 100,000 messages

**Severity**: Critical  
**Response Time**: 5 minutes  
**Indicates**: Consumer severely behind  

**Investigation Steps**:

```bash
# Check consumer lag
kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --group consumer-group-name

# Check broker status
kafka-broker-api-versions --bootstrap-server kafka:9092

# Check topic partitions
kafka-topics --bootstrap-server kafka:9092 \
  --describe --topic topic-name

# Check consumer group details
kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --group consumer-group-name --members
```

**Root Cause Analysis**:

1. **Is consumer application down/slow?**
   ```bash
   # Check consumer process
   ps aux | grep consumer
   
   # Check logs
   journalctl -u consumer-service -f
   ```

2. **Is Kafka broker healthy?**
   ```
   Check Kafka dashboard for:
   - Broker count in ISR
   - Network throughput
   - Disk I/O
   ```

3. **Is the message rate too high?**
   ```
   Compare:
   - Producer rate (msg/sec)
   - Consumer rate (msg/sec)
   - Lag growth rate
   ```

**Recovery Actions**:

**Option 1: Restart consumer (60% success)**
```bash
systemctl restart consumer-service
sleep 5

# Monitor lag decrease
kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --group consumer-group-name \
  --members
```

**Option 2: Scale consumers (best fix)**
```bash
# Increase consumer instances
# Each partition needs a consumer
kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --group consumer-group-name \
  | grep -c ":0"  # Number of partitions

# Scale deployment
kubectl scale deployment consumer --replicas=<partition-count>
# Or
systemctl set-environment CONSUMER_INSTANCES=<count>
systemctl restart consumer-service
```

**Option 3: Increase consumer throughput**
```bash
# Tune consumer config
# Increase fetch size
consumer.properties:
  fetch.min.bytes=1024  # Increase to 10240
  fetch.max.wait.ms=500 # Increase to 1000

# Increase batch processing
  max.poll.records=500    # Increase to 2000
  
# Restart
systemctl restart consumer-service
```

**Escalation**:
- After 5 min: Page consumer team
- After 15 min: Page infrastructure team
- Consider emergency scaling

---

### 5. SystemHealthCritical 🔴

**Alert**: Overall system health below 70%

**Severity**: Critical  
**Response Time**: Immediate  
**Indicates**: Multiple system problems  

**Investigation Steps**:

1. **Check Health Scoring Dashboard**
   ```
   Go to: System Health Scoring
   Look for:
   - Overall health %
   - Which components are down
   - Error rate
   - Latency metrics
   ```

2. **Prioritize by component**
   - Database down? → Restart immediately
   - Cache down? → Restart immediately
   - Services down? → Check dependencies first
   - Infrastructure issues? → Check host resources

3. **Check all critical layers**
   ```bash
   # Database
   systemctl status postgresql
   
   # Cache
   systemctl status redis
   
   # Message Queue
   systemctl status kafka
   
   # Services
   systemctl status api-server
   systemctl status worker
   ```

**Recovery Actions**:

**Phased Recovery**:

```
Phase 1 (0-5 min): Restore critical infrastructure
├─ Restart database
├─ Restart cache
└─ Restart message queues

Phase 2 (5-10 min): Restore services
├─ Check dependencies
├─ Restart services in dependency order
└─ Monitor health dashboard

Phase 3 (10-15 min): Verify
├─ Overall health > 90%
├─ All services responding
└─ Error rates normalized
```

**Detailed steps**:
```bash
# 1. Restart core infrastructure (2-3 min)
systemctl restart postgresql
sleep 30
systemctl restart redis
sleep 30
systemctl restart kafka
sleep 30

# 2. Restart all services (5 min)
systemctl restart api-server
systemctl restart worker
systemctl restart background-jobs
# ... etc

# 3. Monitor recovery
watch -n 2 'systemctl status api-server \
  && curl -s http://api-server:8080/health | jq'

# 4. Verify dashboards
# Check Health Scoring dashboard
# Verify error rates returning to normal
# Check latency metrics
```

**If still critical after services restart**:
- Check host resources (CPU, memory, disk)
- Look for hung processes
- Check network connectivity
- Consider full host restart

---

## ⚠️ WARNING ALERTS

### 1. ErrorRateHigh ⚠️

**Alert**: Error rate above 5%

**Severity**: Warning  
**Response Time**: 30 minutes  

**Investigation**:
1. Check which service has errors
2. Review application logs
3. Check for recent deployments
4. Review database query performance

**Action**:
- Review logs in Observability → Logs
- Check recent changes
- Rollback if needed
- Contact service owner

---

### 2. LatencyHigh ⚠️

**Alert**: p99 latency above 2 seconds

**Severity**: Warning  
**Response Time**: 30 minutes  

**Investigation**:
1. Identify slow endpoints
2. Check database query performance
3. Check cache hit rates
4. Review resource utilization

**Action**:
- Profile slow requests
- Add caching
- Optimize queries
- Scale if needed

---

### 3. DatabaseSlowQueries ⚠️

**Alert**: More than 10 slow queries per 5 minutes

**Severity**: Warning  
**Response Time**: 30 minutes  

**Investigation**:
```sql
-- Find slow queries
SELECT query, mean_time, max_time, calls
FROM pg_stat_statements
WHERE mean_time > 100
ORDER BY mean_time DESC LIMIT 10;

-- Check missing indexes
SELECT * FROM pg_stat_user_tables
WHERE idx_scan = 0;
```

**Action**:
- Add missing indexes
- Optimize query
- Check for sequential scans
- Contact database team

---

### 4. CacheHitRateLow ⚠️

**Alert**: Cache hit rate below 70%

**Severity**: Warning  
**Response Time**: 1 hour  

**Action**:
- Increase TTL
- Pre-warm cache
- Review cache keys
- Monitor trends

---

## 🔧 Escalation Policy

### Critical (🔴 Red)
```
Immediate (0-5 min)
└─ Page on-call engineer
   └─ Respond within 5 minutes
      └─ Start incident (if not resolved)
         └─ Page team lead (15 min)
            └─ Page VP Engineering (30 min)
```

### Warning (⚠️ Yellow)
```
Soon (30 min - 1 hour)
└─ Create ticket
   └─ Assign to team
      └─ Monitor for escalation
         └─ Weekly review
```

---

## 📞 Contact Information

| Role | Name | Phone | Email |
|------|------|-------|-------|
| On-Call Engineer | TBD | TBD | oncall@example.com |
| Database Admin | TBD | TBD | dba@example.com |
| Infrastructure | TBD | TBD | infra@example.com |
| VP Engineering | TBD | TBD | vp-eng@example.com |

---

## 📚 Additional Resources

- [Services Health Dashboard](/d/services-health)
- [Observability — Logs](/d/observability-logs)
- [Health Scoring Dashboard](/d/system-health-scoring)
- [Alerts Dashboard](/d/alerts-dashboard)
- [Performance Dashboard](/d/performance-optimization)
- [Metrics Discovery](/d/metrics-discovery)

---

## ✅ Runbook Update Checklist

- [ ] Test all recovery procedures
- [ ] Update contact information quarterly
- [ ] Review escalation policy annually
- [ ] Add new alerts as they're created
- [ ] Update procedures after incidents
- [ ] Keep dashboard links current
- [ ] Test communication channels

---

**Last Reviewed**: 2026-03-04  
**Next Review**: 2026-06-04  
**Maintained By**: SRE Team
