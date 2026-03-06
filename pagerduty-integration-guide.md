# PagerDuty Integration Guide - On-Call Automation

**Version**: 1.0  
**Last Updated**: 2026-03-04  
**Purpose**: Automate incident management and on-call escalation  

---

## 📋 Overview

This guide covers integration between Grafana alerts and PagerDuty for:
- Automatic incident creation
- On-call user notification
- Escalation policies
- Alert deduplication
- Incident lifecycle management

---

## 🔧 Setup Steps

### 1. Create PagerDuty Service

**In PagerDuty UI**:
1. Navigate to **Services** → **New Service**
2. Name: "Homelab Observability"
3. Description: "Automated alerts from Grafana"
4. Escalation Policy: (select existing or create)
   - Level 1 (5 min): Primary On-Call
   - Level 2 (5 min): Backup On-Call
   - Level 3 (5 min): Team Lead

**Service Details**:
```
Service Name: Homelab Observability
Service Description: Automated incident creation from critical alerts
Status: Active
Escalation Policy: Observability On-Call (see below)
Teams: SRE, Infrastructure
```

### 2. Create Escalation Policy

**Escalation Policy Configuration**:
```
Policy Name: Observability On-Call
Description: Primary and backup on-call rotation

Level 1: Escalate after 5 minutes if not acknowledged
├─ Assigned to: On-Call Schedule (Primary)
├─ Notification: Email + SMS + Phone
└─ Repeat: Yes (repeat every 30 min until acknowledged)

Level 2: Escalate after 5 minutes
├─ Assigned to: On-Call Schedule (Backup)
├─ Notification: Email + SMS + Phone
└─ Repeat: Yes

Level 3: Escalate after 5 minutes
├─ Assigned to: Team Lead (Direct)
├─ Notification: SMS + Phone
└─ Repeat: No
```

### 3. Create On-Call Schedules

**Primary On-Call Schedule**:
```
Schedule Name: Primary On-Call
Timezone: UTC
Rotation: Weekly
Start: Monday 9 AM
Duration: 1 week
Team members:
  - Engineer 1 (Week 1)
  - Engineer 2 (Week 2)
  - Engineer 3 (Week 3)
  - ... (rotate)
```

**Backup On-Call Schedule**:
```
Schedule Name: Backup On-Call
Timezone: UTC
Rotation: Weekly
Start: Monday 9 AM (offset 1 day)
Duration: 1 week
Team members:
  - (Same as primary, shifted 1 week)
```

### 4. Generate Integration Key

**In PagerDuty Service**:
1. Navigate to **Integrations** → **Email Integration**
2. Copy Integration Email: `{service-id}+{integration-key}@incidents.pagerduty.com`

**Or use Events API v2**:
1. Navigate to **Integrations** → **Generic Events API Integration**
2. Copy Integration Key (format: `xxxxxxxxxxxxxxxxxxxx`)
3. This gives more control over incident properties

### 5. Configure Alertmanager Integration

**In alertmanager-config.yaml**:

```yaml
receivers:
  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: '${PAGERDUTY_SERVICE_KEY}'  # Integration key from step 4
        description: '{{ .GroupLabels.alertname }}'
        details:
          firing: '{{ range .Alerts.Firing }}{{ .Labels.instance }} {{ .Annotations.description }}\n{{ end }}'
          resolved: '{{ range .Alerts.Resolved }}{{ .Labels.instance }}\n{{ end }}'
        client: 'Grafana Alertmanager'
        client_url: 'http://192.168.0.4:3000'
        # Group alerts by alert name to avoid duplicate incidents
        group_key: '{{ .GroupLabels.alertname }}'
        # Use the same incident key to update existing incident
        incident_key: '{{ .GroupLabels.alertname }}-{{ .GroupLabels.severity }}'
```

**Environment Variable**:
```bash
export PAGERDUTY_SERVICE_KEY='pxxxxxxxxxxxxxxxxxx'
systemctl restart alertmanager
```

---

## 🔄 Incident Lifecycle

### Alert → Incident Flow

```
Grafana Alert Fires
       ↓
Alertmanager Routes
       ↓
PagerDuty Incident Created
       ↓
├─ Notification sent to Primary On-Call
├─ SMS alert
└─ Phone call (if not acknowledged)
       ↓
5 minutes (no acknowledgement)
       ↓
Escalate to Backup On-Call
       ↓
5 minutes (no acknowledgement)
       ↓
Escalate to Team Lead
```

### Incident Deduplication

**Same Alert = Same Incident**:
```yaml
# Using incident_key for deduplication
incident_key: '{{ .GroupLabels.alertname }}-{{ .GroupLabels.severity }}'

Example:
- Alert fires at 14:00 → Creates Incident #1
- Alert fires again at 14:05 → Updates Incident #1
- Alert resolves at 14:15 → Closes Incident #1
```

**No Multiple Incidents** for the same problem

### Incident Resolution

**Automatic**:
```yaml
# Alert resolves
Alert Status: Resolved
       ↓
Alertmanager sends
'resolved' webhook
       ↓
PagerDuty closes
Incident automatically
```

---

## 📊 Routing by Alert Severity

### Critical Alerts → PagerDuty

```yaml
route:
  - match:
      severity: critical
    receiver: 'pagerduty-critical'
    # Immediate notification
    group_wait: 10s
    group_interval: 1m
```

**Result**:
- Incident created immediately
- On-call notified via all channels
- Automatic escalation after 5 min
- Resolves automatically when alert clears

### Warning Alerts → Slack Only

```yaml
route:
  - match:
      severity: warning
    receiver: 'slack-warning'
    # No PagerDuty for warnings
    group_wait: 1m
```

**Result**:
- Posted to Slack #alerts-warning
- No incidents created
- Manual action if escalation needed

---

## 📱 Notification Channels

### Configure PagerDuty Notifications

**For Each Team Member**:

1. **Email Notifications**:
   - ✓ Immediately enabled
   - Alert includes: Service name, alert description, action

2. **SMS Notifications**:
   - Opt-in required
   - Add phone number in profile
   - SMS when escalated (Level 2+)

3. **Phone Notifications**:
   - Opt-in required
   - Add phone number in profile
   - Phone call when escalated (Level 3)

4. **Mobile Push**:
   - Download PagerDuty mobile app
   - Enable push notifications
   - Get notified even when offline

---

## 🔗 Linking Incidents to Runbooks

### Add Runbook Link to Incident

**In PagerDuty Incident**:

1. Click **+ Add Contextual Information**
2. Paste URL to runbook:
   ```
   https://internal.example.com/docs/alert-runbooks#ServiceDown
   ```

3. Or configure automatic link in alert description:
   ```yaml
   # In Grafana alert annotation:
   runbook_url: 'https://internal.example.com/docs/alert-runbooks#{{ .Labels.alert_name }}'
   ```

**Incident now shows**:
- Alert details
- Runbook link
- Investigation steps
- Recovery procedures

---

## 📊 Monitoring Integration

### Webhook Health

```bash
# Test webhook delivery
curl -X POST https://events.pagerduty.com/v2/enqueue \
  -H 'Content-Type: application/json' \
  -d '{
    "routing_key": "'$PAGERDUTY_SERVICE_KEY'",
    "event_action": "trigger",
    "dedup_key": "test-integration",
    "payload": {
      "summary": "Test alert from Grafana",
      "severity": "critical",
      "source": "Grafana Alertmanager"
    }
  }'
```

### Monitor Incident Metrics

**In PagerDuty Analytics**:
- Incident count
- MTTR (Mean Time to Resolution)
- On-call response time
- Escalation frequency
- Alert noise

---

## 🚨 Alert Tuning by Metrics

### Track Metrics in PagerDuty

**High Incident Volume (> 5/hour)**:
- Alert too sensitive
- Adjust thresholds upward
- Increase evaluation window
- Consider suppression rules

**Low Incident Volume (< 1/week)**:
- Alert working correctly
- Appropriate for critical level
- Keep as-is

**No Incidents (0/month)**:
- Alert might be unnecessary
- Or very good prevention
- Review and possibly disable

---

## 🔄 Integration Testing

### Test Workflow

**Step 1: Create Test Alert**
```bash
# Trigger a test alert in Grafana
# Go to Alerts → Test notification
```

**Step 2: Verify Incident Creation**
```bash
# Check PagerDuty
# Should see incident appear within 10 seconds
```

**Step 3: Verify Notification**
```bash
# Check on-call engineer received:
# - Email notification
# - SMS (if configured)
# - Mobile push (if app installed)
```

**Step 4: Resolve Alert**
```bash
# Resolve the test alert in Grafana
# Incident should close automatically
```

---

## 📋 Configuration Checklist

- [ ] PagerDuty service created
- [ ] Escalation policy configured
- [ ] On-call schedules created
- [ ] Primary on-call assigned
- [ ] Backup on-call assigned
- [ ] Integration key generated
- [ ] Alertmanager config updated
- [ ] Webhook tested
- [ ] Notifications verified
- [ ] Runbook links added
- [ ] Team trained
- [ ] On-call rotation started

---

## 📞 Team Setup Example

```
On-Call Rotation (Weekly):

Week 1 (Mar 4-10):
  Primary: Alice (alice@example.com)
  Backup:  Bob (bob@example.com)
  Lead:    Carol (carol@example.com)

Week 2 (Mar 11-17):
  Primary: Bob
  Backup:  Carol
  Lead:    Dave

Week 3 (Mar 18-24):
  Primary: Carol
  Backup:  Dave
  Lead:    Eve
```

---

## 🎯 Escalation Scenarios

### Scenario 1: ServiceDown Alert
```
14:00:00 - Alert fires (ServiceDown)
14:00:05 - Incident #123 created in PagerDuty
14:00:10 - Alice (primary) gets email
14:00:15 - Alice gets SMS
14:00:20 - Alice gets phone call
14:02:00 - Alice acknowledges incident
14:05:00 - Alice investigates (see runbook)
14:10:00 - Alice restarts service
14:10:30 - Alert resolves
14:10:35 - Incident #123 closes automatically
```

### Scenario 2: No Response
```
14:00:00 - Critical alert fires
14:00:05 - Alice notified
14:05:00 - No acknowledgement from Alice
14:05:05 - Escalates to Bob (backup)
14:05:10 - Bob gets notifications
14:10:00 - Still no acknowledgement
14:10:05 - Escalates to Carol (team lead)
14:10:10 - Carol gets phone call
14:10:15 - Carol acknowledges, takes over
```

---

## 🔧 Advanced Configuration

### Custom Escalation Rules

```yaml
# Different escalation for different alert types
routes:
  - match:
      severity: critical
      alertname: 'ServiceDown'
    receiver: 'pagerduty-critical'
    # Very aggressive escalation
    group_wait: 5s
    group_interval: 1m
    
  - match:
      severity: critical
      alertname: 'SystemHealthCritical'
    receiver: 'pagerduty-infrastructure'
    # Infrastructure team escalation
    group_wait: 10s
```

### Suppress Alerts During Maintenance

```yaml
# In Alertmanager routes
routes:
  - match_re:
      alertname: '.*'
    receiver: 'default'
    # Add mute time interval for maintenance windows
    mute_time_intervals:
      - 'maintenance_window'

mute_time_intervals:
  - name: 'maintenance_window'
    time_intervals:
      - weekdays: ['saturday']  # Every Saturday maintenance
        times:
          - start_time: '02:00'
            end_time: '04:00'
```

---

## 📊 Success Metrics

Track these metrics for on-call health:

| Metric | Target | Status |
|--------|--------|--------|
| MTTR (Mean Time to Response) | < 5 min | - |
| Incident Acknowledgement | < 2 min | - |
| False Positive Rate | < 10% | - |
| On-Call Satisfaction | > 8/10 | - |
| Escalation Rate | < 20% | - |

---

## 📚 Additional Resources

- [PagerDuty Documentation](https://support.pagerduty.com/)
- [Alert Runbooks](/alert-runbooks.md)
- [Alertmanager Config](/alertmanager-config.example.yaml)
- [Alert Rules](/ITERATION-21-ALERT-AUTOMATION.md)

---

**Maintained By**: SRE Team  
**Last Updated**: 2026-03-04  
**Next Review**: 2026-06-04
