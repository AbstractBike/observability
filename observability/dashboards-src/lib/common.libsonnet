local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';

{
  // ── Datasource helpers ─────────────────────────────────────────────────────

  // Dashboard-level template variable that lets the user pick a VM datasource.
  vmDsVar:
    g.dashboard.variable.datasource.new('datasource', 'victoriametrics-metrics-datasource')
    + g.dashboard.variable.datasource.generalOptions.withLabel('Metrics'),

  // Dashboard-level template variable for VictoriaLogs datasource.
  vlogsDsVar:
    g.dashboard.variable.datasource.new('vlogs', 'victoriametrics-logs-datasource')
    + g.dashboard.variable.datasource.generalOptions.withLabel('Logs'),

  // Dashboard-level template variable for SkyWalking PromQL datasource.
  // Regex filters to show only the "SkyWalking-PromQL" datasource.
  swDsVar:
    g.dashboard.variable.datasource.new('swdatasource', 'prometheus')
    + g.dashboard.variable.datasource.generalOptions.withLabel('SkyWalking')
    + g.dashboard.variable.datasource.withRegex('SkyWalking.*'),

  // ── Query helpers ──────────────────────────────────────────────────────────

  // Prometheus-compatible query against VictoriaMetrics.
  vmQ(expr, legend=''):
    g.query.prometheus.new('$datasource', expr)
    + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {}),

  // PromQL query against SkyWalking OAP PromQL endpoint (port 9090).
  swQ(expr, legend=''):
    g.query.prometheus.new('$swdatasource', expr)
    + (if legend != '' then g.query.prometheus.withLegendFormat(legend) else {}),

  // VictoriaLogs query (uses Loki query model with VM logs datasource).
  vlogsQ(expr): {
    datasource: {
      type: 'victoriametrics-logs-datasource',
      uid: '${vlogs}',
    },
    expr: expr,
    refId: 'A',
    queryType: 'range',
    legendFormat: '',
    editorMode: 'code',
  },

  // VictoriaLogs stats-range query — for TimeSeries panels showing log volume over time.
  // queryType "statsRange" uses the plugin's native histogram path that returns numeric values.
  vlogsStatsQ(expr, step=''): {
    datasource: {
      type: 'victoriametrics-logs-datasource',
      uid: '${vlogs}',
    },
    expr: expr,
    refId: 'A',
    queryType: 'statsRange',
    legendFormat: '{{level}}',
    editorMode: 'code',
  } + (if step != '' then { step: step } else {}),

  // ── Layout helpers ─────────────────────────────────────────────────────────

  // Set absolute grid position on any panel.
  pos(x, y, w, h):
    { gridPos: { x: x, y: y, w: w, h: h } },

  // Standard grid positions used across dashboards.
  //   Stats row:     4 panels × 6 wide × 3 tall at y=1
  //   Metrics row:   2×2 panels × 12 wide × 8 tall starting y=5
  //   Logs row:      1 panel full width at y=21
  statPos(col):  self.pos(col * 6, 1, 6, 3),   // col 0-3
  tsPos(col, row): self.pos(col * 12, 5 + row * 8, 12, 8), // col 0-1, row 0-1
  logPos(y):     self.pos(0, y, 24, 10),

  // Standard logs panel for service dashboards.
  // host defaults to "homelab"; pass host="heater" for developer-machine services.
  serviceLogsPanel(title, service, y=21, host='homelab'):
    g.panel.logs.new(title)
    + self.logPos(y)
    + g.panel.logs.queryOptions.withTargets([
      self.vlogsQ('{host="' + host + '",service="' + service + '"}'),
    ])
    + g.panel.logs.options.withWrapLogMessage(true)
    + g.panel.logs.options.withSortOrder('Descending')
    + g.panel.logs.options.withEnableLogDetails(true)
    + g.panel.logs.options.withShowTime(true),

  // ── Standard panel decorations ─────────────────────────────────────────────

  // Standard percentage thresholds: green < 70% < yellow < 90% < red.
  percentThresholds:
    g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: 'yellow', value: 70 },
      { color: 'red', value: 90 },
    ]),

  // Flip thresholds for metrics where high = good (e.g. free space).
  freeThresholds:
    g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'red', value: null },
      { color: 'yellow', value: 20 },
      { color: 'green', value: 50 },
    ]),

  // ── Common dashboard setup ─────────────────────────────────────────────────

  // Apply to every dashboard: refresh 30s, last 1h, both datasource vars.
  dashboardDefaults:
    g.dashboard.withRefresh('30s')
    + g.dashboard.time.withFrom('now-1h')
    + g.dashboard.time.withTo('now')
    + g.dashboard.graphTooltip.withSharedCrosshair()
    + g.dashboard.withVariables([self.vmDsVar, self.vlogsDsVar]),
}
