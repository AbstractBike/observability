local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// nixos-deployer exposes metrics on :9110/metrics (prometheus format).
// Key metrics:
//   nixos_deploy_total{status}           — deploy outcomes (success/failure)
//   nixos_deploy_duration_seconds_bucket{stage} — deploy stage durations
//   nixos_staging_lag_commits             — commits in staging not yet in main
//   nixos_generations_total               — number of NixOS system generations

local deploySuccessRateStat =
  g.panel.stat.new('Deploy Success Rate')
  + c.statPos(0)
  + g.panel.stat.queryOptions.withTargets([
    // "or vector(0)" prevents no_data when the counter has not been emitted yet (fresh restart).
    c.vmQ('rate(nixos_deploy_total{status="success"}[1h]) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('reqps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local stagingLagStat =
  g.panel.stat.new('Staging Lag (commits)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nixos_staging_lag_commits or vector(0)'),
  ])
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 3 },
    { color: 'red', value: 6 },
  ])
  + g.panel.stat.options.withColorMode('background');

local generationsStat =
  g.panel.stat.new('NixOS Generations')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nixos_generations_total or vector(0)'),
  ])
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('none');

local deploysByStatusTs =
  g.panel.timeSeries.new('Deploys by Status')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('increase(nixos_deploy_total[10m])', '{{status}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local deployDurationTs =
  g.panel.timeSeries.new('Deploy Duration p95')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    // Wider rate window (30m) captures infrequent deploys; "or vector(0)" shows 0 when idle.
    c.vmQ(
      'histogram_quantile(0.95, rate(nixos_deploy_duration_seconds_bucket[30m])) or vector(0)',
      'p95 {{stage}}'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('s')
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel =
  c.serviceLogsPanel('nixos-deployer Logs', 'nixos-deployer');

g.dashboard.new('Services — NixOS Deployer')
+ g.dashboard.withUid('services-nixos-deployer')
+ g.dashboard.withDescription('NixOS GitOps deployer: deploy outcomes, duration, staging lag and system generations.')
+ g.dashboard.withTags(['services', 'nixos-deployer', 'gitops'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Status') + c.pos(0, 0, 24, 1),
  deploySuccessRateStat, stagingLagStat, generationsStat,
  g.panel.row.new('Deploy Activity') + c.pos(0, 4, 24, 1),
  deploysByStatusTs, deployDurationTs,
  g.panel.row.new('Logs') + c.pos(0, 20, 24, 1),
  logsPanel,
])
