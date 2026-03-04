local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Variables ───────────────────────────────────────────────────────────────

local serviceVar =
  g.dashboard.variable.custom.new('service', [
    { key: 'All', value: '.*' },
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
    { key: 'claude-code', value: 'claude-code' },
    { key: 'kernel', value: 'kernel' },
    { key: 'systemd', value: 'systemd' },
    { key: 'k3s', value: 'k3s' },
    { key: 'python', value: 'python' },
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
    // queryType "statsRange" uses the VictoriaLogs plugin's native histogram path,
    // which returns numeric values directly (no type-conversion transformation needed).
    c.vlogsStatsQ('{host="homelab",service=~"$service",level=~"$level"} | stats by (level) count() as logs'),
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
