local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// nvidia_gpu_exporter (utkuozdemir/nvidia_gpu_exporter) metric names:
// nvidia_smi_utilization_gpu_ratio, nvidia_smi_utilization_memory_ratio
// nvidia_smi_memory_used_bytes, nvidia_smi_memory_total_bytes
// nvidia_smi_temperature_gpu, nvidia_smi_power_draw_watts
// nvidia_smi_fan_speed_ratio

local gpuUtil =
  g.panel.gauge.new('GPU Utilization')
  + c.statPos(0)
  + g.panel.gauge.queryOptions.withTargets([
    c.vmQ('(nvidia_smi_utilization_gpu_ratio{host="heater"} * 100) or vector(0)', '{{name}}'),
  ])
  + g.panel.gauge.standardOptions.withUnit('percent')
  + g.panel.gauge.standardOptions.withMax(100)
  + g.panel.gauge.standardOptions.withMin(0)
  + g.panel.gauge.standardOptions.thresholds.withMode('absolute')
  + g.panel.gauge.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 70 },
    { color: 'red', value: 90 },
  ]);

local vramUtil =
  g.panel.gauge.new('VRAM Used')
  + c.statPos(1)
  + g.panel.gauge.queryOptions.withTargets([
    c.vmQ('(nvidia_smi_memory_used_bytes{host="heater"} / nvidia_smi_memory_total_bytes{host="heater"} * 100) or vector(0)', '{{name}}'),
  ])
  + g.panel.gauge.standardOptions.withUnit('percent')
  + g.panel.gauge.standardOptions.withMax(100)
  + g.panel.gauge.standardOptions.withMin(0)
  + g.panel.gauge.standardOptions.thresholds.withMode('absolute')
  + g.panel.gauge.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 75 },
    { color: 'red', value: 90 },
  ]);

local tempStat =
  g.panel.stat.new('Temperature')
  + c.statPos(2)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nvidia_smi_temperature_gpu{host="heater"} or vector(0)', '{{name}}'),
  ])
  + g.panel.stat.standardOptions.withUnit('celsius')
  + g.panel.stat.standardOptions.thresholds.withMode('absolute')
  + g.panel.stat.standardOptions.thresholds.withSteps([
    { color: 'green', value: null },
    { color: 'yellow', value: 75 },
    { color: 'red', value: 85 },
  ])
  + g.panel.stat.options.withColorMode('background');

local powerStat =
  g.panel.stat.new('Power Draw')
  + c.statPos(3)
  + g.panel.stat.queryOptions.withTargets([
    c.vmQ('nvidia_smi_power_draw_watts{host="heater"} or vector(0)', '{{name}}'),
  ])
  + g.panel.stat.standardOptions.withUnit('watt')
  + g.panel.stat.options.withColorMode('value')
  + g.panel.stat.options.withGraphMode('area');

local gpuUtilTs =
  g.panel.timeSeries.new('GPU & Memory Utilization')
  + c.tsPos(0, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_utilization_gpu_ratio{host="heater"} * 100', 'GPU {{name}}'),
    c.vmQ('nvidia_smi_utilization_memory_ratio{host="heater"} * 100', 'Memory {{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vramTs =
  g.panel.timeSeries.new('VRAM Used vs Total')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_memory_used_bytes{host="heater"}', 'Used {{name}}'),
    c.vmQ('nvidia_smi_memory_total_bytes{host="heater"}', 'Total {{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tempTs =
  g.panel.timeSeries.new('Temperature & Fan')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_temperature_gpu{host="heater"}', 'Temp °C {{name}}'),
    c.vmQ('nvidia_smi_fan_speed_ratio{host="heater"} * 100', 'Fan % {{name}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local powerTs =
  g.panel.timeSeries.new('Power Draw')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_power_draw_watts{host="heater"} or vector(0)', '{{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('watt')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel =
  g.panel.logs.new('GPU / CUDA Logs')
  + c.logPos(21)
  + g.panel.logs.queryOptions.withTargets([
    // Use stream filter (indexed) first, then message regex for efficiency.
    c.vlogsQ('{host="heater",service="kernel"} | _msg:~"(NVIDIA|nvidia|NVRM|cuda|CUDA|GPU|drm)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

g.dashboard.new('Heater — GPU')
+ g.dashboard.withUid('heater-gpu')
+ g.dashboard.withDescription('NVIDIA GPU utilization, VRAM, temperature, power and GPU-related logs.')
+ g.dashboard.withTags(['heater', 'gpu', 'nvidia'])
+ c.dashboardDefaults
+ g.dashboard.withVariables([c.vmDsVar, c.vlogsDsVar])
+ g.dashboard.withPanels([
  g.panel.row.new('Stats') + c.pos(0, 0, 24, 1),
  c.externalLinksPanel(y=1),
  gpuUtil, vramUtil, tempStat, powerStat,
  g.panel.row.new('Metrics') + c.pos(0, 4, 24, 1),
  gpuUtilTs, vramTs, tempTs, powerTs,
  g.panel.row.new('Logs') + c.pos(0, 20, 24, 1),
  logsPanel,
])
