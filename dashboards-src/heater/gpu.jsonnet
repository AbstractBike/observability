local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';
local c = import 'lib/common.libsonnet';

// nvidia_gpu_exporter (utkuozdemir/nvidia_gpu_exporter) metric names:
// nvidia_smi_utilization_gpu_ratio, nvidia_smi_utilization_memory_ratio
// nvidia_smi_memory_used_bytes, nvidia_smi_memory_total_bytes
// nvidia_smi_temperature_gpu, nvidia_smi_power_draw_watts
// nvidia_smi_fan_speed_ratio

local alertPanel = c.alertCountPanel('heater-gpu', col=0);

// 5-stat layout: alert(6) + gpuUtil(4) + vram(4) + temp(5) + power(5) = 24
local gpuUtil =
  g.panel.gauge.new('GPU Utilization')
  + c.pos(6, 1, 4, 3)
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
  + c.pos(10, 1, 4, 3)
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
  + c.pos(14, 1, 5, 3)
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
  + c.pos(19, 1, 5, 3)
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
    c.vmQ('(nvidia_smi_utilization_gpu_ratio{host="heater"} * 100) or vector(0)', 'GPU {{name}}'),
    c.vmQ('(nvidia_smi_utilization_memory_ratio{host="heater"} * 100) or vector(0)', 'Memory {{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('percent')
  + g.panel.timeSeries.standardOptions.withMax(100)
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local vramTs =
  g.panel.timeSeries.new('VRAM Used vs Total')
  + c.tsPos(1, 0)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_memory_used_bytes{host="heater"} or vector(0)', 'Used {{name}}'),
    c.vmQ('nvidia_smi_memory_total_bytes{host="heater"} or vector(0)', 'Total {{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('bytes')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local tempTs =
  g.panel.timeSeries.new('Temperature & Fan')
  + c.tsPos(0, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_temperature_gpu{host="heater"} or vector(0)', 'Temp °C {{name}}'),
    c.vmQ('(nvidia_smi_fan_speed_ratio{host="heater"} * 100) or vector(0)', 'Fan % {{name}}'),
  ])
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local powerTs =
  g.panel.timeSeries.new('Power Draw — History')
  + c.tsPos(1, 1)
  + g.panel.timeSeries.queryOptions.withTargets([
    c.vmQ('nvidia_smi_power_draw_watts{host="heater"} or vector(0)', '{{name}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('watt')
  + g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + g.panel.timeSeries.options.tooltip.withMode('multi');

local logsPanel =
  g.panel.logs.new('GPU / CUDA Logs')
  + c.logPos(22)
  + g.panel.logs.queryOptions.withTargets([
    // Use stream filter (indexed) first, then message regex for efficiency.
    c.vlogsQ('{host="heater",service="kernel"} | _msg:~"(NVIDIA|nvidia|NVRM|cuda|CUDA|GPU|drm)"'),
  ])
  + g.panel.logs.options.withWrapLogMessage(true)
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.options.withShowTime(true);

// ── Troubleshooting Guide ──────────────────────────────────────────────────

local troubleGuide = c.serviceTroubleshootingGuide('gpu', [
  { symptom: 'GPU Utilization High', runbook: 'gpu/high-utilization', check: 'Monitor GPU Utilization gauge and check active CUDA processes in logs' },
  { symptom: 'VRAM Exhausted', runbook: 'gpu/memory-pressure', check: 'Review VRAM Used gauge and clear GPU memory cache if needed' },
  { symptom: 'Temperature High', runbook: 'gpu/thermal-throttle', check: 'Check Temperature & Fan trend panel and improve cooling' },
  { symptom: 'Power Spike', runbook: 'gpu/power-anomaly', check: 'Review Power Draw trends and adjust workloads' },
], y=35);

g.dashboard.new('Heater — GPU')
+ g.dashboard.withUid('heater-gpu')
+ g.dashboard.withDescription('NVIDIA GPU utilization, VRAM, temperature, power and GPU-related logs.')
+ g.dashboard.withTags(['heater', 'gpu', 'nvidia', 'critical'])
+ c.dashboardDefaults
+ g.dashboard.withPanels([
  g.panel.row.new('📊 Status') + c.pos(0, 0, 24, 1),
  // Transparent spacer — gap below sticky variable bar
  g.panel.text.new('') + c.pos(0, 1, 24, 2) + { transparent: true, options: { content: '', mode: 'html' } },

  c.externalLinksPanel(y=3),
  alertPanel, gpuUtil, vramUtil, tempStat, powerStat,
  g.panel.row.new('⚡ Metrics') + c.pos(0, 6, 24, 1),
  gpuUtilTs, vramTs, tempTs, powerTs,
  g.panel.row.new('📝 Logs') + c.pos(0, 23, 24, 1),
  logsPanel,
  g.panel.row.new('🔧 Troubleshooting') + c.pos(0, 34, 24, 1),
  troubleGuide,
])
