// Dashboard: Services — Matrix (continuwuity)
// Question:  "Is Matrix healthy? Users, rooms, message RTT, webhook delivery."
//
// Data: matrix_* from matrix-exporter (port 9211, scraped by otelcol → VictoriaMetrics)
// Confirmed metrics:
//   matrix_up                     1 if homeserver is reachable
//   matrix_local_users            registered local user count
//   matrix_rooms_joined           rooms joined by the admin account (server proxy)
//   matrix_probe_send_rtt_seconds end-to-end message round-trip time (seconds)
//   matrix_probe_send_errors_total send/recv probe failures

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local alertPanel = c.alertCountPanel('continuwuity', col=0);

// ── Row 0: Status ─────────────────────────────────────────────────────────────

local upStat =
  g.panel.stat.new('Matrix Up')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('matrix_up or vector(0)')])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red',   value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background');

local usersStat =
  g.panel.stat.new('Local Users')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('matrix_local_users or vector(0)')])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local roomsStat =
  g.panel.stat.new('Rooms')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([c.vmQ('matrix_rooms_joined or vector(0)')])
  + g.panel.stat.standardOptions.withUnit('short')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

// ── Row 1: Probe RTT & Errors ─────────────────────────────────────────────────

local rttTs =
  g.panel.timeSeries.new('Message Round-Trip Time')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('matrix_probe_send_rtt_seconds or vector(0)', 'RTT'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('single')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'green',  value: null },
    { color: 'yellow', value: 1 },
    { color: 'red',    value: 5 },
  ]);

local errorsTs =
  g.panel.timeSeries.new('Probe Errors')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('rate(matrix_probe_send_errors_total[5m]) or vector(0)', 'errors/s'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('single')
  + g.panel.timeSeries.standardOptions.thresholds.withMode('absolute')
  + g.panel.timeSeries.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'red',   value: 0.01 },
  ]);

// ── Row 2: Users & Rooms over Time ────────────────────────────────────────────

local usersTs =
  g.panel.timeSeries.new('Local Users over Time')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('matrix_local_users or vector(0)', 'users'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('single');

local roomsTs =
  g.panel.timeSeries.new('Rooms over Time')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('matrix_rooms_joined or vector(0)', 'rooms'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('single');

// ── Row 3: Logs ───────────────────────────────────────────────────────────────

local logsPanel =
  c.serviceLogsPanel('Matrix Logs', 'matrix-exporter', y=23);

local webhookLogsPanel =
  g.panel.logs.new('Alertmanager Webhook Logs')
  + c.pos(0, 32, 24, 10)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service_name="alertmanager-matrix-webhook"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Row 4: Troubleshooting ────────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('continuwuity', [
  { symptom: 'Matrix Down',        runbook: 'matrix/down',        check: '"Matrix Up" = 0 — check container@continuwuity systemd service' },
  { symptom: 'High RTT',           runbook: 'matrix/high-rtt',    check: '"Message Round-Trip Time" above 1s — check server load and disk I/O' },
  { symptom: 'Probe Errors',       runbook: 'matrix/probe-error', check: '"Probe Errors" > 0 — check matrix-exporter logs and credentials' },
  { symptom: 'Webhook 500 errors', runbook: 'matrix/webhook',     check: 'Check "Alertmanager Webhook Logs" for 401/500 — bot token may have expired' },
], y=45);

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Services — Matrix')
+ g.dashboard.withUid('services-matrix')
+ g.dashboard.withDescription('continuwuity Matrix homeserver: up/down, users, rooms, message RTT, webhook delivery.')
+ g.dashboard.withTags(['services', 'matrix', 'chat', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status')             + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, upStat, usersStat, roomsStat,

  g.panel.row.new('🔁 Probe — RTT & Errors') + c.pos(0, 6, 24, 1),
  rttTs, errorsTs,

  g.panel.row.new('👥 Growth')             + c.pos(0, 15, 24, 1),
  usersTs, roomsTs,

  g.panel.row.new('📝 Logs')               + c.pos(0, 23, 24, 1),
  logsPanel,
  webhookLogsPanel,

  g.panel.row.new('🔧 Troubleshooting')    + c.pos(0, 44, 24, 1),
  troubleGuide,
])
