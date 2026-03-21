// Merged Observability meta-dashboard
//
// Aggregates all 11 observability sub-dashboards into one view.
// Sources (in order):
//   alertmanager · alerts · vmalert · grafana · logs ·
//   metrics-discovery · health-scoring · query-performance · performance ·
//   dashboard-index · skywalking

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ═══════════════════════════════════════════════════════════════════════════
// § 1 — Alertmanager (am_)
// ═══════════════════════════════════════════════════════════════════════════

local am_alertPanel = c.alertCountPanel('alertmanager', col=0);

local am_receivedStat =
  g.panel.stat.new('Alerts Received/sec')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(alertmanager_alerts_received_total[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local am_firedStat =
  g.panel.stat.new('Notifications Sent/sec')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(alertmanager_notifications_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local am_failedStat =
  g.panel.stat.new('Failed Notifications/sec')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(alertmanager_notifications_failed_total[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 0.01 },
  ])
  + g.panel.stat.options.withColorMode('background');

local am_silencesStat =
  g.panel.stat.new('Active Silences')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(alertmanager_silences{state="active"}) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local am_notifTs =
  g.panel.timeSeries.new('Notifications by Receiver')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(rate(alertmanager_notifications_total[5m]) or vector(0))', '{{receiver}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local am_alertsTs =
  g.panel.timeSeries.new('Alerts in Pipeline')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(alertmanager_alerts{state="active"}) or vector(0)', 'active'),
    c.vmQ('(alertmanager_alerts{state="suppressed"}) or vector(0)', 'suppressed'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local am_logsPanel = c.serviceLogsPanel('Alertmanager Logs', 'alertmanager', y=15);

local am_troubleGuide = c.serviceTroubleshootingGuide('alertmanager', [
  { symptom: 'Notification Failures', runbook: 'alertmanager/notification-failures', check: '"Failed Notifications/sec" > 0 — check receiver config (email, webhook)' },
  { symptom: 'Alert Pipeline Backlog', runbook: 'alertmanager/alert-backlog', check: '"Alerts in Pipeline" — high suppressed count = silences or inhibit rules' },
  { symptom: 'High Alert Volume', runbook: 'alertmanager/volume', check: '"Alerts Received/sec" high — check VMAlert rules for over-sensitive thresholds' },
  { symptom: 'Silences Not Working', runbook: 'alertmanager/silences', check: '"Active Silences" = 0 but alerts still suppressed? Check expiry dates' },
], y=26);

// am: max y+h = troubleGuide y=26 h=5 → 31
local am_panels = [
  g.panel.row.new('📊 Alertmanager — Status') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  am_alertPanel, am_receivedStat, am_firedStat, am_failedStat, am_silencesStat,
  g.panel.row.new('⚠️ Alert Routing') + c.pos(0, 6, 24, 1),
  am_notifTs, am_alertsTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 14, 24, 1),
  am_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 25, 24, 1),
  am_troubleGuide,
];
local am_height = 31;

// ═══════════════════════════════════════════════════════════════════════════
// § 2 — Alerts (al_)
// ═══════════════════════════════════════════════════════════════════════════

local al_alertPanel = c.alertCountPanel('alertmanager', col=0);

local al_activeAlertsStat =
  g.panel.stat.new('Grafana Alerts')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('grafana_alerting_active_alerts or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local al_firedAlertsStat =
  g.panel.stat.new('Fired This Hour')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('increase(alertmanager_notifications_total{job="alertmanager"}[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

local al_alertmanagerUpStat =
  g.panel.stat.new('Alertmanager')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('up{job="alertmanager"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name');

local al_vmAlertUpStat =
  g.panel.stat.new('VMAlert')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('up{job="vmalert"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withTextMode('name');

local al_alertRateTs =
  g.panel.timeSeries.new('Alerts Fired Per Hour (5m avg)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(alertmanager_notifications_total{job="alertmanager"}[5m]) * 3600',
      'Notifications/hour'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local al_alertmanagerStatusTs =
  g.panel.timeSeries.new('Alertmanager Health')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('up{job="alertmanager"} or vector(0)', 'Up'),
    c.vmQ('(alertmanager_alerts or vector(0))', 'Total Alerts'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local al_infoPanel =
  g.panel.text.new('Alerting System & Related Dashboards')
  + c.pos(0, 14, 24, 4)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Related Dashboards
    - **[VMAlert](/d/observability-vmalert)** — Rule evaluation and alert processing
    - **[Alertmanager](/d/observability-alertmanager)** — Alert routing and grouping

    ### Alert Channels
    - Email notifications / On-call escalation / Service integration via webhooks
  |||);

local al_logsPanel = c.serviceLogsPanel('Alert Logs', 'alertmanager', y=21);

local al_troubleGuide = c.serviceTroubleshootingGuide('alertmanager', [
  { symptom: 'Alerts Not Firing', runbook: 'alertmanager/no-alerts', check: 'Verify alertmanager is up and receiving alerts from VMAlert' },
  { symptom: 'Alert Spam', runbook: 'alertmanager/alert-spam', check: 'Check grouping rules and adjust thresholds in VMAlert rules' },
  { symptom: 'Notifications Not Sent', runbook: 'alertmanager/notification-failure', check: 'Monitor notification channel status and retry logs' },
  { symptom: 'Alert Rules Not Evaluating', runbook: 'alertmanager/rule-eval', check: 'Check VMAlert health and rule syntax in "Trends" panel' },
], y=32);

// al: max y+h = troubleGuide y=32 h=5 → 37
local al_panels = [
  g.panel.row.new('🚨 Alerts — Status') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  al_alertPanel, al_activeAlertsStat, al_firedAlertsStat, al_alertmanagerUpStat, al_vmAlertUpStat,
  g.panel.row.new('📈 Trends') + c.pos(0, 6, 24, 1),
  al_alertRateTs, al_alertmanagerStatusTs,
  g.panel.row.new('ℹ️ Info') + c.pos(0, 15, 24, 1),
  al_infoPanel,
  g.panel.row.new('📝 Logs') + c.pos(0, 20, 24, 1),
  al_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 31, 24, 1),
  al_troubleGuide,
];
local al_height = 37;

// ═══════════════════════════════════════════════════════════════════════════
// § 3 — VMAlert (va_)
// ═══════════════════════════════════════════════════════════════════════════

local va_alertPanel = c.alertCountPanel('vmalert', col=0);

local va_firingCountStat =
  g.panel.stat.new('Firing Alerts')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(vmalert_alerts_firing) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local va_rulesStat =
  g.panel.stat.new('Rules Loaded')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(vmalert_alerting_rules_last_evaluation_samples) + count(vmalert_recording_rules_last_evaluation_samples) or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value');

local va_evalDurStat =
  g.panel.stat.new('Eval Duration p99 (ms)')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('max(vmalert_iteration_duration_seconds{quantile="0.99"}) * 1000 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.options.withColorMode('value');

local va_errorStat =
  g.panel.stat.new('Eval Errors/sec')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('rate(vmalert_execution_errors_total[5m]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red', value: 0.01 },
  ])
  + g.panel.stat.options.withColorMode('background');

local va_firingTs =
  g.panel.timeSeries.new('Firing Alerts Over Time')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vmalert_alerts_firing', '{{alertname}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local va_evalTs =
  g.panel.timeSeries.new('Evaluation Duration (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('max(vmalert_iteration_duration_seconds{quantile="0.5"}) * 1000', 'p50'),
    c.vmQ('max(vmalert_iteration_duration_seconds{quantile="0.99"}) * 1000', 'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local va_troubleGuide = c.serviceTroubleshootingGuide('vmalert', [
  { symptom: 'Evaluation Errors', runbook: 'vmalert/eval-errors', check: '"Eval Errors/sec" > 0 — check logs for parse errors or invalid metric names' },
  { symptom: 'High Rule Evaluation Latency', runbook: 'vmalert/latency', check: '"Evaluation Duration" p99 rising — check VM query load' },
  { symptom: 'Rules Not Loading', runbook: 'vmalert/rule-loading', check: '"Rules Loaded" = 0 — check vmalert config file and rule file syntax' },
  { symptom: 'Alert Spam', runbook: 'vmalert/alert-spam', check: '"Firing Alerts Over Time" — many firing = bad thresholds or real incident' },
], y=26);

// va: max y+h = troubleGuide y=26 h=5 → 31
local va_panels = [
  g.panel.row.new('⚙️ VMAlert — Status') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  va_alertPanel, va_firingCountStat, va_rulesStat, va_evalDurStat, va_errorStat,
  g.panel.row.new('⚙️ Evaluation') + c.pos(0, 6, 24, 1),
  va_firingTs, va_evalTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 25, 24, 1),
  va_troubleGuide,
];
local va_height = 14;

// ═══════════════════════════════════════════════════════════════════════════
// § 4 — Grafana (gr_)
// ═══════════════════════════════════════════════════════════════════════════

local gr_alertPanel = c.alertCountPanel('grafana', col=0);

local gr_httpRateStat =
  g.panel.stat.new('HTTP Requests/s')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(grafana_http_request_duration_seconds_count{job="grafana"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local gr_activeAlertsStat =
  g.panel.stat.new('Active Alerts')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(grafana_alerting_active_alerts{job="grafana"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local gr_dashboardsStat =
  g.panel.stat.new('Dashboards')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('grafana_stat_totals_dashboard{job="grafana"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local gr_dbConnStat =
  g.panel.stat.new('DB Connections (in use)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('grafana_database_conn_in_use{job="grafana"} or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local gr_httpRateTs =
  g.panel.timeSeries.new('HTTP Request Rate by Handler')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'topk(10, (sum by (handler) (rate(grafana_http_request_duration_seconds_count{job="grafana"}[5m])) or vector(0)))',
      '{{handler}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gr_httpLatTs =
  g.panel.timeSeries.new('HTTP Latency p99 (ms)')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(histogram_quantile(0.99, sum by (le, handler) (rate(grafana_http_request_duration_seconds_bucket{job="grafana"}[5m])) or vector(0))) * 1000',
      '{{handler}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gr_dsRateTs =
  g.panel.timeSeries.new('Datasource Requests/s by Datasource')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(sum by (datasource) (rate(grafana_datasource_request_total{job="grafana"}[5m])) or vector(0))',
      '{{datasource}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('reqps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gr_dsLatTs =
  g.panel.timeSeries.new('Datasource Request Latency p99 (ms)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      '(histogram_quantile(0.99, sum by (le, datasource) (rate(grafana_datasource_request_duration_seconds_bucket{job="grafana"}[5m])) or vector(0))) * 1000',
      '{{datasource}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local gr_logsPanel =
  g.panel.logs.new('Grafana Logs')
  + c.logPos(24)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service="grafana"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local gr_troubleGuide = c.serviceTroubleshootingGuide('grafana', [
  { symptom: 'High HTTP Latency', runbook: 'grafana/latency', check: 'Check "HTTP Latency p99" and handler breakdown' },
  { symptom: 'Datasource Errors', runbook: 'grafana/datasource', check: 'Monitor "Datasource Request Latency" and logs' },
  { symptom: 'High Memory Usage', runbook: 'grafana/memory', check: 'Check "DB Connections" and dashboard count' },
  { symptom: 'Alert System Issues', runbook: 'grafana/alerting', check: 'Verify "Active Alerts" in Grafana UI' },
], y=35);

// gr: max y+h = troubleGuide y=35 h=5 → 40
local gr_panels = [
  g.panel.row.new('📊 Grafana — Status') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  gr_alertPanel, gr_httpRateStat, gr_activeAlertsStat, gr_dashboardsStat, gr_dbConnStat,
  g.panel.row.new('⚡ HTTP Traffic') + c.pos(0, 6, 24, 1),
  gr_httpRateTs, gr_httpLatTs,
  g.panel.row.new('🔧 Datasources') + c.pos(0, 14, 24, 1),
  gr_dsRateTs, gr_dsLatTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  gr_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  gr_troubleGuide,
];
local gr_height = 40;

// ═══════════════════════════════════════════════════════════════════════════
// § 5 — Logs (lg_)
// ═══════════════════════════════════════════════════════════════════════════

local lg_alertPanel = c.alertCountPanel('victorialogs', col=0);

local lg_logVolumePanel =
  g.panel.timeSeries.new('Log Volume by Level')
  + c.pos(0, 4, 12, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vlogsStatsQ('{host=~".*",service=~".*",level=~".*"} | stats by (level) count() as logs'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local lg_errorRatePanel =
  g.panel.timeSeries.new('Error Rate (errors/min)')
  + c.pos(12, 4, 12, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vlogsStatsQ('{host=~".*",service=~".*",level=~"error|critical"} | stats by () count() as errors'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local lg_liveLogsPanel =
  g.panel.logs.new('Live Logs')
  + c.pos(0, 11, 24, 16)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host=~".*",service=~".*",level=~".*"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

local lg_errorAnalysisPanel =
  g.panel.text.new('Error Analysis & Related Dashboards')
  + c.pos(0, 28, 24, 2)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    **Related**: [Services Health](/d/services-health) | [Alerts](/d/alerts-dashboard)

    Filter by service/host above to diagnose issues. Use **Live Logs** to search by keyword, trace_id, or error message.
  |||);

local lg_troubleGuide = c.serviceTroubleshootingGuide('victorialogs', [
  { symptom: 'No Logs Appearing', runbook: 'logs/no-logs', check: 'Verify services are sending logs to VictoriaLogs via Vector pipeline' },
  { symptom: 'High Error Rate', runbook: 'logs/error-spike', check: 'Filter by "error" level and correlate with alert timestamps' },
  { symptom: 'Logs Delayed', runbook: 'logs/latency', check: 'Check Vector pipeline health and VictoriaLogs ingestion rate' },
  { symptom: 'Storage Growing Fast', runbook: 'logs/storage', check: 'Review log retention policy and reduce verbose services' },
], y=33);

// lg: max y+h = troubleGuide y=33 h=5 → 38
local lg_panels = [
  g.panel.row.new('📝 Logs — Analysis') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  lg_alertPanel, lg_logVolumePanel, lg_errorRatePanel,
  g.panel.row.new('📝 Live Logs') + c.pos(0, 10, 24, 1),
  lg_liveLogsPanel,
  g.panel.row.new('⚠️ Error Analysis') + c.pos(0, 28, 24, 1),
  lg_errorAnalysisPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 31, 24, 1),
  lg_troubleGuide,
];
local lg_height = 38;


// ═══════════════════════════════════════════════════════════════════════════
// § 7 — Metrics Discovery (md_)
// ═══════════════════════════════════════════════════════════════════════════

local md_alertPanel = c.alertCountPanel('victoriametrics', col=0);

local md_totalSeriesStat =
  g.panel.stat.new('Total Series')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count({__name__=~".+"}) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local md_uniqueMetricsStat =
  g.panel.stat.new('Unique Metrics')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (__name__) ({__name__=~".+"})) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local md_jobCountStat =
  g.panel.stat.new('Active Jobs')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(count by (job) ({__name__=~".+"})) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local md_ingestionRateStat =
  g.panel.stat.new('Ingestion Rate (5m)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate({__name__=~".+"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqpm')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

local md_topMetricsTs =
  g.panel.timeSeries.new('Top 20 Metrics by Cardinality (5m avg)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('topk(20, count by (__name__) ({__name__=~".+"})) or vector(0)', '{{__name__}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local md_metricsByJobTs =
  g.panel.timeSeries.new('Metric Count by Job')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('count by (job) ({__name__=~".+"}) or vector(0)', '{{job}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local md_topJobsTable =
  g.panel.table.new('Top 10 Jobs by Series Count')
  + c.pos(0, 14, 24, 8)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('sort_desc(topk(10, count by (job) ({__name__=~".+"}) or vector(0)))', 'Series Count'),
  ])
  + g.panel.table.standardOptions.withUnit('short')
  + g.panel.table.options.withSortBy([
    { displayName: 'Value', desc: true },
  ]);

local md_logsPanel = c.serviceLogsPanel('VictoriaMetrics Logs', 'victoriametrics', y=28);

local md_troubleGuide = c.serviceTroubleshootingGuide('victoriametrics', [
  { symptom: 'Missing Service Metrics', runbook: 'metrics/missing-scrape', check: 'Check "Top Jobs" table - verify job appears in Prometheus scrape config' },
  { symptom: 'High Cardinality Alert', runbook: 'metrics/cardinality', check: 'Inspect "Top 20 Metrics" for high-cardinality offenders' },
  { symptom: 'Ingestion Rate Drop', runbook: 'metrics/ingest-drop', check: 'Compare current rate vs baseline in "Ingestion Rate" stat' },
  { symptom: 'Storage Growing Fast', runbook: 'metrics/retention', check: 'Review metric discovery dashboard and reduce retention or cardinality' },
], y=39);

// md: max y+h = troubleGuide y=39 h=5 → 44
local md_panels = [
  g.panel.row.new('📊 Metrics Discovery — Status') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  md_alertPanel, md_totalSeriesStat, md_uniqueMetricsStat, md_jobCountStat, md_ingestionRateStat,
  g.panel.row.new('📈 Metrics Overview') + c.pos(0, 6, 24, 1),
  md_topMetricsTs, md_metricsByJobTs,
  g.panel.row.new('📊 Jobs & Series') + c.pos(0, 14, 24, 1),
  md_topJobsTable,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  md_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  md_troubleGuide,
];
local md_height = 44;

// ═══════════════════════════════════════════════════════════════════════════
// § 8 — Health Scoring (hs_)
// ═══════════════════════════════════════════════════════════════════════════

local hs_alertPanel = c.alertCountPanel('observability-health', col=0);

local hs_overallHealthStat =
  g.panel.stat.new('Overall System Health')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~".+"}[5m] == 0) / count(up{job=~".+"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'orange', value: 70 },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local hs_upstreamHealthStat =
  g.panel.stat.new('Services Up')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~".+"} == 1) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

local hs_downstreamHealthStat =
  g.panel.stat.new('Services Down')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count(up{job=~".+"} == 0) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 3 },
  ])
  + g.panel.stat.options.withColorMode('background');

local hs_healthTrendStat =
  g.panel.stat.new('Health Trend (24h)')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('((1 - (rate(up{job=~".+"}[5m] == 0) / count(up{job=~".+"}[5m])) * 100) - (1 - (rate(up{job=~".+"}[1d] == 0) / count(up{job=~".+"}[1d])) * 100)) * 100 or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.options.withColorMode('value');

local hs_databaseHealthStat =
  g.panel.stat.new('Database Health')
  + c.pos(0, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"postgres|elasticsearch|clickhouse"}[5m] == 0) / count(up{job=~"postgres|elasticsearch|clickhouse"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background');

local hs_cacheHealthStat =
  g.panel.stat.new('Cache Health')
  + c.pos(6, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"redis|memcached"}[5m] == 0) / count(up{job=~"redis|memcached"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background');

local hs_queueHealthStat =
  g.panel.stat.new('Queue Health')
  + c.pos(12, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"kafka|rabbitmq|redpanda"}[5m] == 0) / count(up{job=~"kafka|rabbitmq|redpanda"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background');

local hs_infraHealthStat =
  g.panel.stat.new('Infrastructure Health')
  + c.pos(18, 5, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"node-exporter|host"}[5m] == 0) / count(up{job=~"node-exporter|host"}[5m])) * 100) or vector(100)'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: 90 },
    { color: 'green', value: 95 },
  ])
  + g.panel.stat.options.withColorMode('background');

local hs_healthTrendTs =
  g.panel.timeSeries.new('System Health Score (24h)')
  + c.pos(0, 9, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~".+"}[5m] == 0) / count(up{job=~".+"}[5m])) * 100) or vector(100)', 'Overall'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.standardOptions.withMin(0)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(30);

local hs_componentHealthTs =
  g.panel.timeSeries.new('Component Health Trends')
  + c.pos(12, 9, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(1 - (rate(up{job=~"postgres|elasticsearch|clickhouse"}[5m] == 0) / count(up{job=~"postgres|elasticsearch|clickhouse"}[5m])) * 100) or vector(100)', 'Database'),
    c.vmQ('(1 - (rate(up{job=~"redis|memcached"}[5m] == 0) / count(up{job=~"redis|memcached"}[5m])) * 100) or vector(100)', 'Cache'),
    c.vmQ('(1 - (rate(up{job=~"kafka|rabbitmq|redpanda"}[5m] == 0) / count(up{job=~"kafka|rabbitmq|redpanda"}[5m])) * 100) or vector(100)', 'Queue'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20);

local hs_errorRateTs =
  g.panel.timeSeries.new('Error Rate (5m avg)')
  + c.pos(0, 18, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100) or vector(0)'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(30)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth');

local hs_latencyTs =
  g.panel.timeSeries.new('System Latency (p99)')
  + c.pos(12, 18, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m]))) * 1000'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(20);

local hs_serviceStatusTable =
  g.panel.table.new('Service Health Status')
  + c.pos(0, 27, 24, 6)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ('(up{job=~".+"}) or vector(0)', 'Status'),
  ]);

local hs_logsPanel = c.serviceLogsPanel('System Health Logs', 'victoriametrics', y=41);

local hs_troubleGuide = c.serviceTroubleshootingGuide('observability-health', [
  { symptom: 'Overall Health Score Drop', runbook: 'health/score-drop', check: 'Check which components degraded in component health scores' },
  { symptom: 'Services Down', runbook: 'health/services-down', check: 'Identify down services in "Services Down" stat and Service Status table' },
  { symptom: 'High Error Rate', runbook: 'health/error-rate', check: 'Monitor "Error Rate (5m avg)" and check logs for patterns' },
  { symptom: 'Performance Degradation', runbook: 'health/latency', check: 'Check "System Latency (p99)" and "Health Trends" charts' },
], y=52);

// hs: max y+h = troubleGuide y=52 h=5 → 57
local hs_panels = [
  g.panel.row.new('🏥 Health Scoring — Overall') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  hs_alertPanel, hs_overallHealthStat, hs_upstreamHealthStat, hs_downstreamHealthStat, hs_healthTrendStat,
  g.panel.row.new('🏗️ Component Health') + c.pos(0, 4, 24, 1),
  hs_databaseHealthStat, hs_cacheHealthStat, hs_queueHealthStat, hs_infraHealthStat,
  g.panel.row.new('📈 Health Trends & Performance') + c.pos(0, 8, 24, 1),
  hs_healthTrendTs, hs_componentHealthTs,
  g.panel.row.new('⚠️ Error Rate & Latency') + c.pos(0, 17, 24, 1),
  hs_errorRateTs, hs_latencyTs,
  g.panel.row.new('📊 Service Status') + c.pos(0, 26, 24, 1),
  hs_serviceStatusTable,
  g.panel.row.new('📝 Logs') + c.pos(0, 33, 24, 1),
  hs_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 44, 24, 1),
  hs_troubleGuide,
];
local hs_height = 57;

// ═══════════════════════════════════════════════════════════════════════════
// § 9 — Query Performance (qp_)
// ═══════════════════════════════════════════════════════════════════════════

local qp_alertPanel = c.alertCountPanel('grafana', col=0);

local qp_avgQueryTimeStat =
  g.panel.stat.new('Latency — Query Executor — avg')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.5, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) or vector(0)) * 1000', 'ms'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 100 },
    { color: 'red', value: 500 },
  ])
  + g.panel.stat.options.withColorMode('background');

local qp_p99QueryTimeStat =
  g.panel.stat.new('Latency — Query Executor — p99')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.99, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) or vector(0)) * 1000', 'ms'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local qp_queryErrorRateStat =
  g.panel.stat.new('Error Rate — Queries — 5m')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(sum(rate(grafana_query_errors_total[5m])) / sum(rate(grafana_queries_total[5m])) or vector(0)) * 100', '%'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1 },
    { color: 'red', value: 5 },
  ])
  + g.panel.stat.options.withColorMode('background');

local qp_totalQueriesStat =
  g.panel.stat.new('Throughput — Queries — /sec')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(grafana_queries_total[5m])) or vector(0)', 'queries/sec'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value');

local qp_queryTimeDistributionTs =
  g.panel.timeSeries.new('Latency Distribution — Queries — percentiles')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.5, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) or vector(0)) * 1000', 'p50'),
    c.vmQ('(histogram_quantile(0.95, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) or vector(0)) * 1000', 'p95'),
    c.vmQ('(histogram_quantile(0.99, sum by(le) (rate(grafana_query_duration_seconds_bucket[5m]))) or vector(0)) * 1000', 'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local qp_slowestQueriesTs =
  g.panel.timeSeries.new('Slowest Queries — by datasource')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('topk(5, sum by (datasource) (rate(grafana_query_duration_seconds_bucket{le="1"}[5m]))) * 1000', '{{datasource}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local qp_queryErrorsTs =
  g.panel.timeSeries.new('Errors — Queries — 5m rolling')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum(rate(grafana_query_errors_total[5m])) by (datasource)', '{{datasource}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local qp_queryThroughputTs =
  g.panel.timeSeries.new('Throughput — Queries — by datasource')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('sum by (datasource) (rate(grafana_queries_total[5m]))', '{{datasource}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local qp_troubleGuide = c.serviceTroubleshootingGuide('grafana', [
  { symptom: 'High Query Latency', runbook: 'grafana/query-latency', check: 'Check p99 latency and "Slowest Queries by Datasource"' },
  { symptom: 'Query Errors Spike', runbook: 'grafana/query-errors', check: 'Monitor "Error Rate" stat and errors by datasource' },
  { symptom: 'Slow Datasource', runbook: 'grafana/datasource-perf', check: 'Identify slow datasource in "Slowest Queries" chart' },
  { symptom: 'Dashboard Loading Slow', runbook: 'grafana/dashboard-speed', check: 'Check throughput and consider reducing refresh rate' },
], y=24);

// qp: max y+h = troubleGuide y=24 h=5 → 29
local qp_panels = [
  g.panel.row.new('🔬 Query Performance — Status') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  qp_alertPanel, qp_avgQueryTimeStat, qp_p99QueryTimeStat, qp_queryErrorRateStat, qp_totalQueriesStat,
  g.panel.row.new('📈 Trends') + c.pos(0, 6, 24, 1),
  qp_queryTimeDistributionTs, qp_slowestQueriesTs,
  qp_queryErrorsTs, qp_queryThroughputTs,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 23, 24, 1),
  qp_troubleGuide,
];
local qp_height = 29;

// ═══════════════════════════════════════════════════════════════════════════
// § 10 — Performance & Optimization (pf_)
// ═══════════════════════════════════════════════════════════════════════════

local pf_alertPanel = c.alertCountPanel('observability', col=0);

local pf_avgQueryLatencyStat =
  g.panel.stat.new('Latency — Query Engines — p50')
  + c.pos(6, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.5, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) or vector(0)) * 1000'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 500 },
    { color: 'red', value: 2000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local pf_p99QueryLatencyStat =
  g.panel.stat.new('Latency — Query Engines — p99')
  + c.pos(10, 1, 4, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('(histogram_quantile(0.99, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) or vector(0)) * 1000'),
  ])
  + g.panel.stat.standardOptions.withUnit('ms')
  + g.panel.stat.standardOptions.withDecimals(0)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 1000 },
    { color: 'red', value: 5000 },
  ])
  + g.panel.stat.options.withColorMode('background');

local pf_totalMetricsStat =
  g.panel.stat.new('Total Metrics')
  + c.pos(14, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('count({__name__=~".+"})'),
  ])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local pf_storageUsedStat =
  g.panel.stat.new('Storage Used')
  + c.pos(19, 1, 5, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('vm_data_size_bytes or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('bytes')
  + g.panel.stat.standardOptions.withDecimals(1)
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('line');

local pf_queryLatencyTs =
  g.panel.timeSeries.new('HTTP Request Latency (p50/p95/p99)')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('histogram_quantile(0.50, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) * 1000', 'p50'),
    c.vmQ('histogram_quantile(0.95, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) * 1000', 'p95'),
    c.vmQ('histogram_quantile(0.99, sum by(le) (rate(http_request_duration_seconds_bucket{instance=~".*:3000|.*:8428|.*:9428"}[5m]))) * 1000', 'p99'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ms')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pf_storageGrowthTs =
  g.panel.timeSeries.new('Storage — VictoriaMetrics — growth trend')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('vm_data_size_bytes or vector(0)', 'Total'),
    c.vmQ('rate(vm_data_size_bytes[1h]) or vector(0)', 'Growth Rate'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pf_cardinalityTs =
  g.panel.timeSeries.new('Cardinality — Metrics — series growth')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('count({__name__=~".+"}) or vector(0)', 'Total Series'),
    c.vmQ('count(count by (__name__) ({__name__=~".+"})) or vector(0)', 'Unique Metrics'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pf_cpuByServiceTs =
  g.panel.timeSeries.new('CPU Usage by Service (5m avg)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('(100 - avg by (job) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) or vector(0)', '{{job}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local pf_logsPanel = c.serviceLogsPanel('Performance & Error Logs', 'victoriametrics', y=28);

local pf_troubleGuide = c.serviceTroubleshootingGuide('observability', [
  { symptom: 'High Query Latency', runbook: 'performance/query-latency', check: 'Check p50/p99 latency stats and trends' },
  { symptom: 'Cardinality Explosion', runbook: 'performance/cardinality', check: 'Monitor "Total Metrics" and series growth' },
  { symptom: 'Storage Growth Out of Control', runbook: 'performance/storage', check: 'Check storage growth rate and retention policy' },
  { symptom: 'High CPU Utilization', runbook: 'performance/cpu', check: 'Correlate with query latency and cardinality' },
], y=39);

// pf: max y+h = troubleGuide y=39 h=5 → 44
local pf_panels = [
  g.panel.row.new('⚡ Performance & Optimization') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  pf_alertPanel, pf_avgQueryLatencyStat, pf_p99QueryLatencyStat, pf_totalMetricsStat, pf_storageUsedStat,
  g.panel.row.new('📈 Trends & Growth') + c.pos(0, 6, 24, 1),
  pf_queryLatencyTs, pf_storageGrowthTs,
  pf_cardinalityTs, pf_cpuByServiceTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 22, 24, 1),
  pf_logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 33, 24, 1),
  pf_troubleGuide,
];
local pf_height = 44;


// ═══════════════════════════════════════════════════════════════════════════
// § 12 — Dashboard Index (di_)
// ═══════════════════════════════════════════════════════════════════════════

local di_alertPanel = c.alertCountPanel('grafana', col=0);

local di_coreObsText =
  g.panel.text.new('Core Observability — Start Here')
  + c.pos(0, 2, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [Services Health](/d/services-health) | Real-time service status, uptime, error rates | `core`, `health`, `services` |
    | [Homelab System](/d/homelab-system) | Host-level metrics (CPU, memory, disk, network) | `core`, `system`, `infrastructure` |
    | [Observability — Logs](/d/observability-logs) | All-services structured logs with filtering | `core`, `logs`, `troubleshooting` |
    | [Observability — Alerts](/d/alerts-dashboard) | Active alerts, firing rates, alertmanager status | `core`, `alerts`, `incident-response` |
  |||);

local di_perfText =
  g.panel.text.new('Performance & Optimization')
  + c.pos(0, 3, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [Performance & Optimization](/d/performance-optimization) | Query latency, storage growth, cardinality, CPU by service | `performance`, `optimization` |
    | [Metric Discovery](/d/metrics-discovery) | Catalog all metrics, cardinality per job, ingestion rate | `metrics`, `discovery` |
    | [Dashboard Usage](/d/dashboard-usage) | Which dashboards are used most, by whom, when | `analytics`, `meta-observability` |
    | [Cost Tracking](/d/cost-tracking) | Storage costs, data retention, optimization ROI | `cost`, `optimization` |
  |||);

local di_infraText =
  g.panel.text.new('Infrastructure & Databases')
  + c.pos(0, 4, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [PostgreSQL](/d/postgres-db) | Connection count, query latency, replication lag | `database`, `postgresql` |
    | [Redis](/d/redis-db) | Memory usage, hit rate, evictions, command latency | `cache`, `redis` |
    | [ClickHouse](/d/clickhouse-db) | Merges, queries, compression ratio, disk usage | `database`, `clickhouse` |
    | [Redpanda](/d/redpanda-db) | Broker lag, throughput, replication, consumer groups | `streaming`, `kafka` |
  |||);

local di_stackText =
  g.panel.text.new('Observability Stack Components')
  + c.pos(0, 5, 24, 1)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    | Dashboard | Purpose | Tags |
    |-----------|---------|------|
    | [Observability — Grafana](/d/observability-grafana) | Grafana itself: memory, CPU, request latency, errors | `meta`, `grafana` |
    | [Observability — VMAlert](/d/observability-vmalert) | Alert rule evaluation, alert processing latency | `alerts`, `alerting` |
    | [Observability — Alertmanager](/d/observability-alertmanager) | Alert routing, grouping, notification success rate | `alerts`, `routing` |
  |||);

local di_tipsText =
  g.panel.text.new('Tips & Quick Links')
  + c.pos(0, 6, 24, 2)
  + g.panel.text.panelOptions.withTransparent(true)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    ### Quick Access
    - **Search dashboards**: Use Ctrl+K → type dashboard name
    - **Favorite dashboards**: Star any dashboard to pin to top
    - **Filter by tag**: Use the `Tag` filter (top-left) to narrow down
    - **External links**: Click the link icon (top-right corner) for VictoriaMetrics, VictoriaLogs, SkyWalking UIs

    ### For Troubleshooting
    1. **Service not responding?** Start with [Services Health](/d/services-health)
    2. **Slow queries?** Check [Performance & Optimization](/d/performance-optimization)
    3. **Alerts firing?** Look at [Observability — Alerts](/d/alerts-dashboard)
  |||);

local di_troubleGuide = c.serviceTroubleshootingGuide('grafana', [
  { symptom: 'Dashboard Missing', runbook: 'grafana/dashboard-missing', check: 'Use Ctrl+K to find dashboard by name' },
  { symptom: 'Dashboard Not Loading', runbook: 'grafana/dashboard-error', check: 'Check data source status - verify connectivity' },
  { symptom: 'Slow Dashboard', runbook: 'grafana/performance', check: 'Review "Query Performance" dashboard for slow datasources' },
], y=9);

// di: max y+h = troubleGuide y=9 h=5 → 14
local di_panels = [
  g.panel.row.new('🗂️ Dashboard Index — Navigator') + c.pos(0, 0, 24, 1),
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },
  c.externalLinksPanel(y=3),
  di_alertPanel,
  di_coreObsText, di_perfText, di_infraText, di_stackText,
  di_tipsText,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 8, 24, 1),
  di_troubleGuide,
];
local di_height = 14;


// ═══════════════════════════════════════════════════════════════════════════
// § 14 — SkyWalking (sw_)
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// Dashboard Assembly
// ═══════════════════════════════════════════════════════════════════════════

g.dashboard.new('Observability — Meta')
+ g.dashboard.withUid('home-observability')
+ g.dashboard.withDescription('Merged observability meta-dashboard: alertmanager, alerts, vmalert, grafana, logs, metrics discovery, health scoring, query performance, performance, dashboard index.')
+ g.dashboard.withTags(['observability', 'meta', 'alerting'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, c.vmAdhocVar, c.vlogsAdhocVar])
+ g.dashboard.withPanels(
    c.withYOffset(am_panels, 0)
    + c.withYOffset(al_panels, am_height)
    + c.withYOffset(va_panels, am_height + al_height)
    + c.withYOffset(gr_panels, am_height + al_height + va_height)
    + c.withYOffset(lg_panels, am_height + al_height + va_height + gr_height)
    + c.withYOffset(md_panels, am_height + al_height + va_height + gr_height + lg_height)
    + c.withYOffset(hs_panels, am_height + al_height + va_height + gr_height + lg_height + md_height)
    + c.withYOffset(qp_panels, am_height + al_height + va_height + gr_height + lg_height + md_height + hs_height)
    + c.withYOffset(pf_panels, am_height + al_height + va_height + gr_height + lg_height + md_height + hs_height + qp_height)
    + c.withYOffset(di_panels, am_height + al_height + va_height + gr_height + lg_height + md_height + hs_height + qp_height + pf_height)
  )
