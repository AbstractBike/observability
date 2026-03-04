local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Variables ───────────────────────────────────────────────────────────────

local serviceVar =
  g.dashboard.variable.custom.new('service', [
    { key: 'All', value: '.*' },
    { key: 'postgresql.service', value: 'postgresql.service' },
    { key: 'nginx.service', value: 'nginx.service' },
    { key: 'grafana.service', value: 'grafana.service' },
    { key: 'vector.service', value: 'vector.service' },
    { key: 'redis.service', value: 'redis.service' },
    { key: 'clickhouse-server.service', value: 'clickhouse-server.service' },
    { key: 'elasticsearch.service', value: 'elasticsearch.service' },
    { key: 'matrix-synapse.service', value: 'matrix-synapse.service' },
    { key: 'temporal.service', value: 'temporal.service' },
    { key: 'coredns.service', value: 'coredns.service' },
    { key: 'victoriametrics.service', value: 'victoriametrics.service' },
    { key: 'victorialogs.service', value: 'victorialogs.service' },
    { key: 'skywalking-oap.service', value: 'skywalking-oap.service' },
    { key: 'adguardhome.service', value: 'adguardhome.service' },
    { key: 'arbitraje', value: 'arbitraje' },
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
  + c.pos(0, 0, 24, 6)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"$service",level=~"$level"} | stats by (level) count() as logs'),
  ])
  + g.panel.timeSeries.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
  + g.panel.timeSeries.fieldConfig.defaults.custom.withDrawStyle('bars')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(80)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local liveLogsPanel =
  g.panel.logs.new('Live Logs')
  + c.pos(0, 7, 24, 18)
  + g.panel.logs.queryOptions.withTargets([
    c.vlogsQ('{host="homelab",service=~"$service",level=~"$level"}'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withEnableLogDetails(true)
  + g.panel.logs.options.withShowTime(true);

// ── Dashboard ───────────────────────────────────────────────────────────────

g.dashboard.new('Observability — Logs')
+ g.dashboard.withUid('observability-logs')
+ g.dashboard.withDescription('All-services structured log viewer with level filtering and live tail.')
+ g.dashboard.withTags(['observability', 'logs'])
+ g.dashboard.withRefresh('5s')
+ g.dashboard.time.withFrom('now-15m')
+ g.dashboard.time.withTo('now')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar, serviceVar, levelVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Log Volume') + c.pos(0, 0, 24, 1),
  logVolumePanel,
  g.panel.row.new('Logs') + c.pos(0, 6, 24, 1),
  liveLogsPanel,
])
