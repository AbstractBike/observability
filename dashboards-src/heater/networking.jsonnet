// Dashboard: Networking — Heater
// Question:  "How much traffic is the homelab network carrying? Are there errors?"
//
// Shows network bandwidth and health for the heater machine (physical host, 192.168.0.3).
// Key interfaces:
//   eno1np0   — primary LAN (10GbE, main internet + LAN traffic)
//   eno2np1   — secondary LAN
//   br0       — main bridge (VM LAN access)
//   macvtap4  — macvtap bridge for homelab VM (192.168.0.4)
//   wlan0     — WiFi
//   br-k8s    — k3s cluster bridge
//
// Data: node_network_* from heater node_exporter (host="heater")

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

local host = 'host="heater"';

// Key interface regexes
local physIfaces = 'eno1np0|eno2np1';
local vmIfaces = 'br0|macvtap4|macvlan0';
local allIfaces = '!lo';  // exclude loopback

local alertPanel = c.alertCountPanel('heater-network', col=0);

// ── Row 0: Key Stats ──────────────────────────────────────────────────────────

local rxBwStat =
  g.panel.stat.new('LAN RX (eno1)')
  + c.statPos(1)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(node_network_receive_bytes_total{' + host + ',device="eno1np0"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local txBwStat =
  g.panel.stat.new('LAN TX (eno1)')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(node_network_transmit_bytes_total{' + host + ',device="eno1np0"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('Bps')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local dropRateStat =
  g.panel.stat.new('Drop Rate (all ifaces)')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('sum(rate(node_network_receive_drop_total{' + host + ',device!="lo"}[5m])) or vector(0)'),
  ])
  + g.panel.stat.standardOptions.withUnit('pps')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 10 },
    { color: 'red', value: 100 },
  ])
  + g.panel.stat.options.withColorMode('background');

// ── Row 1: Physical Interface Bandwidth ───────────────────────────────────────

local physRxTs =
  g.panel.timeSeries.new('Physical Interface — Receive')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(node_network_receive_bytes_total{' + host + ',device=~"' + physIfaces + '"}[5m]) or vector(0)',
      '{{device}} rx'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local physTxTs =
  g.panel.timeSeries.new('Physical Interface — Transmit')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(node_network_transmit_bytes_total{' + host + ',device=~"' + physIfaces + '"}[5m]) or vector(0)',
      '{{device}} tx'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 2: VM Bridge + All Interfaces ────────────────────────────────────────

local vmRxTs =
  g.panel.timeSeries.new('VM Bridge — Receive (br0 / macvtap)')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(node_network_receive_bytes_total{' + host + ',device=~"' + vmIfaces + '"}[5m]) or vector(0)',
      '{{device}} rx'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vmTxTs =
  g.panel.timeSeries.new('VM Bridge — Transmit (br0 / macvtap)')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'rate(node_network_transmit_bytes_total{' + host + ',device=~"' + vmIfaces + '"}[5m]) or vector(0)',
      '{{device}} tx'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('Bps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Row 3: Top Interfaces by Traffic ─────────────────────────────────────────

local topIfacesTable =
  g.panel.table.new('Top Interfaces by Bandwidth (5m avg)')
  + c.pos(0, 21, 24, 7)
  + g.panel.table.queryOptions.withTargets([
    c.vmQ(
      'topk(10, sum by(device) (rate(node_network_receive_bytes_total{' + host + ',device!="lo"}[5m]) or vector(0)))',
      '{{device}}'
    ) + { refId: 'rx' },
    c.vmQ(
      'topk(10, sum by(device) (rate(node_network_transmit_bytes_total{' + host + ',device!="lo"}[5m]) or vector(0)))',
      '{{device}}'
    ) + { refId: 'tx' },
  ])
  + g.panel.table.queryOptions.withTransformations([
    {
      id: 'joinByField',
      options: { byField: 'device', mode: 'outer' },
    },
    {
      id: 'organize',
      options: {
        renameByName: { 'Value #rx': 'RX (bytes/s)', 'Value #tx': 'TX (bytes/s)' },
        excludeByName: { Time: true, 'Time 1': true, 'Time 2': true },
      },
    },
  ])
  + {
    fieldConfig+: {
      overrides: [
        {
          matcher: { id: 'byName', options: 'RX (bytes/s)' },
          properties: [{ id: 'unit', value: 'Bps' }],
        },
        {
          matcher: { id: 'byName', options: 'TX (bytes/s)' },
          properties: [{ id: 'unit', value: 'Bps' }],
        },
      ],
    },
  };

// ── Row 4: Errors & Drops ────────────────────────────────────────────────────

local errorsTs =
  g.panel.timeSeries.new('Receive Errors & Drops')
  + c.pos(0, 28, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'sum by(device) (rate(node_network_receive_errs_total{' + host + ',device!="lo"}[5m]) or vector(0))',
      '{{device}} errors'
    ),
    c.vmQ(
      'sum by(device) (rate(node_network_receive_drop_total{' + host + ',device!="lo"}[5m]) or vector(0))',
      '{{device}} drops'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('pps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local txErrTs =
  g.panel.timeSeries.new('Transmit Errors & Drops')
  + c.pos(12, 28, 12, 8)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ(
      'sum by(device) (rate(node_network_transmit_errs_total{' + host + ',device!="lo"}[5m]) or vector(0))',
      '{{device}} errors'
    ),
    c.vmQ(
      'sum by(device) (rate(node_network_transmit_drop_total{' + host + ',device!="lo"}[5m]) or vector(0))',
      '{{device}} drops'
    ),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('pps')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(5)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

// ── Dashboard ─────────────────────────────────────────────────────────────────

g.dashboard.new('Networking — Heater')
+ g.dashboard.withUid('heater-networking')
+ g.dashboard.withDescription('Network bandwidth and health for the heater host (192.168.0.3): physical interfaces, VM bridge, error rates.')
+ g.dashboard.withTags(['networking', 'heater', 'infrastructure', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  alertPanel, rxBwStat, txBwStat, dropRateStat,

  g.panel.row.new('🔌 Physical Interfaces') + c.pos(0, 4, 24, 1),
  physRxTs, physTxTs,

  g.panel.row.new('🖥️ VM Bridges') + c.pos(0, 13, 24, 1),
  vmRxTs, vmTxTs,

  g.panel.row.new('📋 Interface Summary') + c.pos(0, 22, 24, 1),
  topIfacesTable,

  g.panel.row.new('⚠️ Errors & Drops') + c.pos(0, 29, 24, 1),
  errorsTs, txErrTs,
])
