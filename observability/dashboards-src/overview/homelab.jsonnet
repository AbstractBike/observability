// Dashboard: Homelab — Overview
//
// Command-center home dashboard: host health, service status grid, SLO compliance.
//
// Rows:
//   0  Host vitals — CPU%, RAM%, Disk /, Uptime  (host="homelab" via Vector)
//   1  Services — 12 up{} panels (3 rows × 4 cols)
//   2  SLO Compliance — Host, PostgreSQL, Redis, Grafana
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// ── Host vitals (y=1) ────────────────────────────────────────────────────────

local cpuStat =
  g.panel.stat.new('CPU')
  + c.pos(0, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('100 - avg(rate(host_cpu_seconds_total{mode="idle",host="homelab"}[5m])) * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local ramStat =
  g.panel.stat.new('RAM')
  + c.pos(6, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('host_memory_used_bytes{host="homelab"} / host_memory_total_bytes{host="homelab"} * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('area');

local diskStat =
  g.panel.stat.new('Disk /')
  + c.pos(12, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('host_filesystem_used_ratio{host="homelab",mountpoint="/"} * 100'),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withMax(100)
  + g.panel.stat.standardOptions.withDecimals(1)
  + c.percentThresholds
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none');

local uptimeStat =
  g.panel.stat.new('Uptime')
  + c.pos(18, 1, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('vector_uptime_seconds{host="homelab"}'),
  ])
  + g.panel.stat.standardOptions.withUnit('s')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

// ── Service status helper ─────────────────────────────────────────────────────
// Services grid starts at y=5 (after row separator at y=4).
// Layout: 4 cols x 3 rows, each panel 6w x 3h.

local svcStat(title, upExpr, col, row) =
  g.panel.stat.new(title)
  + c.pos(col * 6, 5 + row * 3, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(upExpr),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'green', value: 1 },
  ])
  + g.panel.stat.options.withColorMode('background')
  + g.panel.stat.options.withGraphMode('none')
  + g.panel.stat.options.withTextMode('name');

// ── Services (y=5..13) ────────────────────────────────────────────────────────

local services = [
  // row 0 (y=5)
  svcStat('PostgreSQL',      'up{job="postgres-exporter"}',                                                           0, 0),
  svcStat('Redis',           'up{job="redis-exporter"}',                                                              1, 0),
  svcStat('Elasticsearch',   'up{job="elasticsearch-exporter"}',                                                      2, 0),
  svcStat('ClickHouse',      'up{job="clickhouse"}',                                                                  3, 0),
  // row 1 (y=8)
  svcStat('Redpanda',        'up{job="redpanda"}',                                                                    0, 1),
  svcStat('Temporal',        'up{job="temporal"}',                                                                    1, 1),
  svcStat('VictoriaMetrics', 'up{job="victoriametrics-self"}',                                                        2, 1),
  svcStat('VictoriaLogs',    'up{job="victorialogs"}',                                                                3, 1),
  // row 2 (y=11)
  svcStat('Grafana',         'up{job="grafana"}',                                                                     0, 2),
  svcStat('Alertmanager',    'up{job="alertmanager"}',                                                                1, 2),
  svcStat('VMAlert',         'up{job="vmalert"}',                                                                     2, 2),
  svcStat('Vector',          'clamp_max(clamp_min(min_over_time(vector_uptime_seconds{host="homelab"}[2m]),0),1)',     3, 2),
];

// ── SLO panels (y=15) ─────────────────────────────────────────────────────────

local sloStat(title, expr, targetPct, col) =
  g.panel.stat.new(title)
  + c.pos(col * 6, 15, 6, 3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ(expr),
  ])
  + g.panel.stat.standardOptions.withUnit('percent')
  + g.panel.stat.standardOptions.withDecimals(2)
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'red', value: null },
    { color: 'yellow', value: targetPct - 0.5 },
    { color: 'green', value: targetPct },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Dashboard assembly ────────────────────────────────────────────────────────

g.dashboard.new('Homelab \u2014 Overview')
+ g.dashboard.withUid('homelab-overview')
+ g.dashboard.withDescription('Command center: host health, service status, SLO compliance.')
+ g.dashboard.withTags(['homelab', 'overview'])
+ c.dashboardDefaults
+ g.dashboard.withPanels(
  [
    g.panel.row.new('Homelab \u2014 Host') + c.pos(0, 0, 24, 1),
    cpuStat,
    ramStat,
    diskStat,
    uptimeStat,

    g.panel.row.new('Services') + c.pos(0, 4, 24, 1),
  ]
  + services
  + [
    g.panel.row.new('SLO Compliance') + c.pos(0, 14, 24, 1),
    sloStat('Host Uptime',  '(1 - slo:host_uptime:error_ratio_30d) * 100',  99.5, 0),
    sloStat('PostgreSQL',   '(1 - slo:postgresql:error_ratio_30d) * 100',   99.9, 1),
    sloStat('Redis',        '(1 - slo:redis:error_ratio_30d) * 100',        99.9, 2),
    sloStat('Grafana',      '(1 - slo:grafana:error_ratio_30d) * 100',      99.0, 3),
  ]
)
