local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Variables ───────────────────────────────────────────────────────────────

local hostVar =
  g.dashboard.variable.custom.new('host', [
    { key: 'All', value: '.*' },
    { key: 'homelab', value: 'homelab' },
    { key: 'heater', value: 'heater' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Host')
  + g.dashboard.variable.custom.generalOptions.withCurrent('homelab', 'homelab');

local serviceVar =
  g.dashboard.variable.custom.new('service', [
    { key: 'All', value: '.*' },
    // ── homelab services ──────────────────────────────────────────
    { key: 'postgres', value: 'postgres' },
    { key: 'nginx', value: 'nginx' },
    { key: 'grafana-start', value: 'grafana-start' },
    { key: 'vector', value: 'vector' },
    { key: 'redis', value: 'redis' },
    { key: 'clickhouse-server', value: 'clickhouse-server' },
    { key: 'elasticsearch', value: 'elasticsearch' },
    { key: 'synapse', value: 'synapse' },
    { key: 'temporal', value: 'temporal' },
    { key: 'temporal-ui', value: 'temporal-ui' },
    { key: 'cloudflared', value: 'cloudflared' },
    { key: 'victoria-metrics', value: 'victoria-metrics' },
    { key: 'victorialogs', value: 'victorialogs' },
    { key: 'skywalking-oap', value: 'skywalking-oap' },
    { key: 'AdGuardHome', value: 'AdGuardHome' },
    { key: 'redpanda', value: 'redpanda' },
    { key: 'alertmanager', value: 'alertmanager' },
    { key: 'vmalert', value: 'vmalert' },
    { key: 'firecrawl-api', value: 'firecrawl-api' },
    { key: 'firecrawl-rabbitmq', value: 'firecrawl-rabbitmq' },
    { key: 'nexus', value: 'nexus' },
    { key: 'serena', value: 'serena' },
    { key: 'arbitraje', value: 'arbitraje' },
    { key: 'nixos-deployer', value: 'nixos-deployer' },
    { key: 'banyandb', value: 'banyandb' },
    { key: 'skywalking-ui', value: 'skywalking-ui' },
    { key: 'superset', value: 'superset' },
    { key: 'k3s', value: 'k3s' },
    { key: 'python', value: 'python' },
    // ── both hosts ───────────────────────────────────────────────
    { key: 'claude-code', value: 'claude-code' },
    { key: 'kernel', value: 'kernel' },
    { key: 'systemd', value: 'systemd' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Service')
  + g.dashboard.variable.custom.generalOptions.withCurrent('All', '.*');

local levelVar =
  g.dashboard.variable.custom.new('level', [
    { key: 'All', value: '.*' },
    { key: 'critical', value: 'critical' },
    { key: 'error', value: 'error' },
    { key: 'warning', value: 'warning' },
    { key: 'info', value: 'info' },
    { key: 'debug', value: 'debug' },
  ])
  + g.dashboard.variable.custom.generalOptions.withLabel('Level')
  + g.dashboard.variable.custom.generalOptions.withCurrent('All', '.*');

// ── Panels ──────────────────────────────────────────────────────────────────

local logVolumePanel =
  g.panel.timeSeries.new('Log Volume by Level')
  + c.pos(0, 0, 12, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vlogsStatsQ('{host=~"$host",service=~"$service",level=~"$level"} | stats by (level) count() as logs'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local errorRatePanel =
  g.panel.timeSeries.new('Error Rate (errors/min)')
  + c.pos(12, 0, 12, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vlogsStatsQ('{host=~"$host",service=~"$service",level=~"error|critical"} | stats by () count() as errors'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local liveLogsPanel =
  g.panel.logs.new('Live Logs')
  + c.pos(0, 7, 24, 16)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host=~"$host",service=~"$service",level=~"$level"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true)
  + g.panel.logs.fieldConfig.defaults.custom.withLogLevel('trace')
  + {
    fieldConfig: {
      overrides: [
        {
          matcher: { id: 'byValue', options: 'error' },
          properties: [
            { id: 'color', value: { mode: 'fixed', fixedColor: 'red' } },
            { id: 'custom.hideFrom', value: { tooltip: false, viz: false, legend: false } },
          ],
        },
        {
          matcher: { id: 'byValue', options: 'critical' },
          properties: [
            { id: 'color', value: { mode: 'fixed', fixedColor: 'dark-red' } },
            { id: 'custom.hideFrom', value: { tooltip: false, viz: false, legend: false } },
          ],
        },
        {
          matcher: { id: 'byValue', options: 'warning' },
          properties: [
            { id: 'color', value: { mode: 'fixed', fixedColor: 'orange' } },
            { id: 'custom.hideFrom', value: { tooltip: false, viz: false, legend: false } },
          ],
        },
      ],
    },
  };

local errorAnalysisPanel =
  g.panel.text.new('📊 Error Analysis & Related Dashboards')
  + c.pos(0, 23, 24, 2)
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    **Related**: [Services Health](/d/services-health) — View service context | [Alerts](/d/alerts-dashboard) — Check triggered alerts

    **Top error patterns detected in logs.** Filter by service/host above to diagnose issues.
    Use **Live Logs** panel to search by keyword, trace_id, or error message.
  |||);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Logs')
+ g.dashboard.withUid('observability-logs')
+ g.dashboard.withDescription('All-services structured log viewer with level filtering and live tail.')
+ g.dashboard.withTags(['observability', 'logs'])
+ g.dashboard.withRefresh('5s')
+ g.dashboard.time.withFrom('now-15m')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, hostVar, serviceVar, levelVar])
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Analysis') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  logVolumePanel, errorRatePanel,

  g.panel.row.new('📝 Logs') + c.pos(0, 6, 24, 1),
  liveLogsPanel,

  g.panel.row.new('⚠️ Error Analysis') + c.pos(0, 22, 24, 1),
  errorAnalysisPanel,
])
