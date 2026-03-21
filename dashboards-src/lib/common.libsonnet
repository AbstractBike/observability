local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';

// ── Global Configuration ───────────────────────────────────────────────────

local config = {
  // External service URLs
  tempo_explore_url: '/a/grafana-exploretraces-app/explore',
  victoriametrics_url: 'http://192.168.0.4:8428',
  victorialogs_ui_url: 'http://192.168.0.4:9428/select/vmui',
};

{
  // ── Datasource helpers ─────────────────────────────────────────────────────

  // Dashboard-level template variable that lets the user pick a VM datasource.
  vmDsVar:
    g.dashboard.variable.datasource.new('datasource', 'victoriametrics-metrics-datasource')
    + g.dashboard.variable.datasource.generalOptions.withLabel('Metrics')
    + g.dashboard.variable.datasource.withRegex('^VictoriaMetrics$'),

  // Dashboard-level template variable for VictoriaLogs datasource.
  vlogsDsVar:
    g.dashboard.variable.datasource.new('vlogs', 'victoriametrics-logs-datasource')
    + g.dashboard.variable.datasource.generalOptions.withLabel('Logs'),

  // Dashboard-level template variable for Elasticsearch datasource.
  esDsVar:
    g.dashboard.variable.datasource.new('esdatasource', 'elasticsearch')
    + g.dashboard.variable.datasource.generalOptions.withLabel('Elasticsearch'),

  // Dashboard-level template variable for Grafana Tempo tracing datasource.
  tempoDsVar:
    g.dashboard.variable.datasource.new('tempodatasource', 'tempo')
    + g.dashboard.variable.datasource.generalOptions.withLabel('Traces'),

  // Kept for backward compat — dashboards that still reference swDsVar compile cleanly.
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

  // Elasticsearch query for Grafana ES datasource.
  esQ(query, metrics, bucketAggs, alias='', timeField='@timestamp'):
    g.query.elasticsearch.new('$esdatasource', query)
    + g.query.elasticsearch.withMetrics(metrics)
    + g.query.elasticsearch.withBucketAggs(bucketAggs)
    + (if alias != '' then g.query.elasticsearch.withAlias(alias) else {})
    + g.query.elasticsearch.withTimeField(timeField),

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
  //   Stats row:     4 panels × 6 wide × 3 tall at y=3 (y=1,2 reserved for spacer below sticky bar)
  //   Metrics row:   2×2 panels × 12 wide × 8 tall starting y=7
  //   Logs row:      1 panel full width at y=23
  statPos(col):  self.pos(col * 6, 3, 6, 3),   // col 0-3
  tsPos(col, row): self.pos(col * 12, 7 + row * 8, 12, 8), // col 0-1, row 0-1
  logPos(y):     self.pos(0, y, 24, 10),

  // Shift all panels' y-coordinate by offset.
  // Use when assembling multiple source dashboards into one.
  // Example: c.withYOffset(gpuPanels, systemHeight)
  withYOffset(panels, offset)::
    std.map(function(p)
      p + { gridPos+: { y+: offset } },
      panels
    ),

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

  // Unit definitions for consistency across dashboards
  units: {
    // Time
    latency_ms: { unit: 'ms', decimals: 1 },
    latency_s: { unit: 's', decimals: 2 },
    duration_s: { unit: 's', decimals: 0 },
    uptime: { unit: 's', decimals: 0 },

    // Data
    bytes: { unit: 'bytes', decimals: 1 },
    megabytes: { unit: 'MB', decimals: 1 },
    gigabytes: { unit: 'GB', decimals: 1 },

    // Rates
    rate_per_sec: { unit: 'reqps', decimals: 0 },
    rate_per_min: { unit: 'reqpm', decimals: 0 },
    rate_per_hour: { unit: 'short', decimals: 0 },

    // Percentages
    percent: { unit: 'percent', decimals: 0 },
    percent_decimal: { unit: 'percentunit', decimals: 2 },

    // Counts
    count: { unit: 'short', decimals: 0 },
    count_decimal: { unit: 'short', decimals: 1 },

    // Performance
    cpu_percent: { unit: 'percent', decimals: 1 },
    memory_percent: { unit: 'percent', decimals: 1 },
    disk_percent: { unit: 'percent', decimals: 0 },

    // Errors
    errors: { unit: 'short', decimals: 0 },
    error_rate: { unit: 'percentunit', decimals: 4 },
  },

  // Standard percentage thresholds: green < 70% < yellow < 90% < red.
  percentThresholds:
    g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: 'yellow', value: 70 },
      { color: 'red', value: 90 },
    ]),

  // Latency thresholds: green < 100ms < yellow < 500ms < red
  latencyThresholds:
    g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: 'yellow', value: 100 },
      { color: 'red', value: 500 },
    ]),

  // Flip thresholds for metrics where high = good (e.g. free space).
  freeThresholds:
    g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'red', value: null },
      { color: 'yellow', value: 20 },
      { color: 'green', value: 50 },
    ]),

  // Error count thresholds: green < 5 < yellow < 20 < red
  errorThresholds:
    g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: 'yellow', value: 5 },
      { color: 'red', value: 20 },
    ]),

  // ── Threshold Context (Historical Reference Lines) ────────────────────────
  // Add historical context to thresholds by showing reference lines
  // Usage: Add to timeSeries panel to show p95 baseline
  // + self.withReferenceLines([
  //     { value: 100, label: 'p95 baseline', color: '#FFB31A' },
  //     { value: 50, label: 'p50 baseline', color: '#1A9850' }
  //   ])

  withReferenceLines(lines=[]):
    {
      fieldConfig: {
        defaults: {
          custom: {
            lineWidth: 1,
            fillOpacity: 0,
            showPoints: 'never',
          },
        },
        overrides: [
          {
            matcher: { id: 'byName', options: line.label },
            properties: [
              { id: 'color', value: { mode: 'fixed', fixedColor: line.color } },
              { id: 'custom.lineWidth', value: 2 },
              { id: 'custom.lineStyle', value: 'dash' },
            ],
          }
          for line in lines
        ],
      },
    },

  // ── External links panel ──────────────────────────────────────────────────

  // Small external links button in top-right corner (2 cells wide, 1 tall)
  externalLinksPanel(y=0, x=22):
    local linkHtml = |||
      <style>
        .ext-link-btn {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          width: 24px;
          height: 24px;
          background: #2563eb;
          color: white;
          text-decoration: none;
          border-radius: 4px;
          font-size: 12px;
          font-weight: bold;
          cursor: pointer;
          margin: 2px;
          transition: all 0.2s;
          border: 1px solid #1d4ed8;
        }
        .ext-link-btn:hover {
          background: #1d4ed8;
          transform: scale(1.1);
          box-shadow: 0 2px 6px rgba(37, 99, 235, 0.4);
        }
        .ext-links-container { display: flex; gap: 4px; }
      </style>
      <div class="ext-links-container">
        <a class="ext-link-btn" href="http://192.168.0.4:8428" target="_blank" title="VictoriaMetrics Metrics">📊</a>
        <a class="ext-link-btn" href="http://192.168.0.4:9428/select/vmui" target="_blank" title="VictoriaLogs UI">📝</a>
        <a class="ext-link-btn" href="/a/grafana-exploretraces-app/explore" target="_blank" title="Tempo Traces">🔍</a>
      </div>
    |||;
    g.panel.text.new('')
    + self.pos(x, y, 2, 1)
    + g.panel.text.panelOptions.withTransparent(true)
    + g.panel.text.options.withMode('html')
    + g.panel.text.options.withContent(linkHtml),

  // Custom external links with service-specific URLs
  // Usage: c.customExternalLinksPanel([
  //   { icon: '🗄️', title: 'pgAdmin', url: 'http://pgadmin.pin' },
  //   { icon: '📊', title: 'Metrics', url: 'http://192.168.0.4:8428' },
  // ])
  customExternalLinksPanel(links=[], y=0, x=22):
    local linkStyle = |||
      <style>
        .ext-link-btn {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          width: 24px;
          height: 24px;
          background: #2563eb;
          color: white;
          text-decoration: none;
          border-radius: 4px;
          font-size: 12px;
          font-weight: bold;
          cursor: pointer;
          margin: 2px;
          transition: all 0.2s;
          border: 1px solid #1d4ed8;
        }
        .ext-link-btn:hover {
          background: #1d4ed8;
          transform: scale(1.1);
          box-shadow: 0 2px 6px rgba(37, 99, 235, 0.4);
        }
        .ext-links-container { display: flex; gap: 4px; }
      </style>
    |||;
    local linkHtml = linkStyle + '<div class="ext-links-container">' +
      std.join('', [
        '<a class="ext-link-btn" href="' + link.url + '" target="_blank" title="' + link.title + '">' + link.icon + '</a>'
        for link in links
      ]) + '</div>';
    g.panel.text.new('')
    + self.pos(x, y, 2, 1)
    + g.panel.text.panelOptions.withTransparent(true)
    + g.panel.text.options.withMode('html')
    + g.panel.text.options.withContent(linkHtml),

  // ── Alert Panel Helpers ───────────────────────────────────────────────────

  // Alert count stat panel (colored by alert state)
  // Usage: c.alertCountPanel('postgresql', col=0)
  // Returns a stat panel showing count of ALERTS{service="<service>", alertstate="firing"}
  alertCountPanel(serviceName, col=0):
    g.panel.stat.new('🚨 Active Alerts')
    + self.statPos(col)
    + g.panel.stat.queryOptions.withTargets([
      self.vmQ('count(ALERTS{service="' + serviceName + '",alertstate="firing"}) or vector(0)'),
    ])
    + g.panel.stat.standardOptions.withUnit('short')
    + g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: 'yellow', value: 1 },
      { color: 'red', value: 3 },
    ])
    + g.panel.stat.options.withColorMode('background')
    + g.panel.stat.options.withGraphMode('none'),

  // Service troubleshooting guide panel
  // Usage: c.serviceTroubleshootingGuide('postgresql', [
  //   { symptom: 'High CPU', runbook: 'postgresql/high-cpu', check: 'Check CPU graph' },
  //   { symptom: 'Slow Queries', runbook: 'postgresql/slow-queries', check: 'Check latency' },
  // ], y=24)
  serviceTroubleshootingGuide(serviceName, items=[], y=0):
    local tableHeader = '| Symptom | Runbook | Quick Check |\n|---------|---------|------------|';
    local tableRows = std.join('\n', [
      '| **' + item.symptom + '** | [Runbook](https://wiki.pin/runbooks/' + item.runbook + ') | ' + item.check + ' |'
      for item in items
    ]);
    local workflowGuide = |||

      **On-Call Workflow:**
      1. Click alert notification → opens this dashboard
      2. Check "Active Alerts" panel (top-left)
      3. Find matching symptom in table above
      4. Click runbook link to follow resolution steps
      5. Monitor metrics improve in real-time
    |||;
    g.panel.text.new('🔧 Troubleshooting Guide')
    + self.pos(0, y, 24, 5)
    + g.panel.text.panelOptions.withTransparent(false)
    + g.panel.text.options.withMode('markdown')
    + g.panel.text.options.withContent(tableHeader + '\n' + tableRows + workflowGuide),

  // ── Runbook helpers ──────────────────────────────────────────────────────

  // Create a markdown runbook link helper
  // Usage: c.runbookLink('High CPU Usage', 'troubleshooting/cpu')
  runbookLink(title, path):
    '[📖 ' + title + ' Runbook](https://wiki.pin/runbooks/' + path + ')',

  // ── Panel naming conventions ──────────────────────────────────────────────
  // Standard format: {MetricType} — {Service} — {Context}
  // Examples:
  //   "Latency — API Gateway — p99"
  //   "Error Rate — PostgreSQL — 5m avg"
  //   "CPU Usage — VictoriaMetrics — peak"

  // Helper to create standard panel title
  panelTitle(metricType, service='', context=''):
    local parts = [metricType] + (if service != '' then [service] else []) + (if context != '' then [context] else []);
    std.join(' — ', parts),

  // ── Error handling & fallbacks ─────────────────────────────────────────────

  // Create an error panel when datasource is unavailable
  errorPanel(title, message, y=0):
    g.panel.text.new(title)
    + self.pos(0, y, 24, 3)
    + g.panel.text.panelOptions.withTransparent(false)
    + g.panel.text.options.withMode('markdown')
    + g.panel.text.options.withContent('⚠️ **' + message + '**'),

  // Datasource availability check helper
  // Returns either the target or an error panel
  withFallback(normalTarget, fallbackTitle, fallbackMessage, y=0):
    [
      normalTarget,
      self.errorPanel(fallbackTitle, fallbackMessage, y),
    ],

  // ── Row styling helpers (P5 - Aesthetics) ──────────────────────────────────

  // Standardized row headers with consistent iconography
  // Usage: g.panel.row.new(c.rowTitle('📊 Status', 'core')) + c.pos(...)
  rowTitle(emoji_and_title, category=''):
    emoji_and_title,

  // Row styling function
  styledRow(title, category='observability'):
    local colors = {
      status: '#1f77b4',        // Blue
      trends: '#ff7f0e',        // Orange
      errors: '#d62728',        // Red
      performance: '#2ca02c',   // Green
      info: '#9467bd',          // Purple
      logs: '#8c564b',          // Brown
      core: '#1f77b4',          // Blue
    };
    g.panel.row.new(title)
    + {
      collapsed: false,
      datasource: null,
      fieldConfig: { defaults: {}, overrides: [] },
      gridPos: { h: 1, w: 24, x: 0, y: 0 },
      id: 1,
      options: { foldedObject: {} },
      targets: [],
      type: 'row',
    },

  // ── Configuration access ──────────────────────────────────────────────────

  config: config,

  // ── Common dashboard setup ─────────────────────────────────────────────────

  // Apply to every dashboard: refresh 30s, last 1h, both datasource vars.
  dashboardDefaults:
    g.dashboard.withRefresh('30s')
    + g.dashboard.time.withFrom('now-1h')
    + g.dashboard.time.withTo('now')
    + g.dashboard.graphTooltip.withSharedCrosshair()
    + g.dashboard.withVariables([self.vmDsVar, self.vlogsDsVar]),
}
