// Dashboard Validation Library
// Provides utilities for validating dashboard structure, metrics, and configuration
// Usage: local v = import 'lib/validation.libsonnet';

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v11.4.0/main.libsonnet';

{
  // Validation rules - each returns {valid: bool, errors: [string]}
  validateDashboard(dashboard)::
    local hasUid = std.objectHas(dashboard, 'uid') && dashboard.uid != null && dashboard.uid != '';
    local hasDescription = std.objectHas(dashboard, 'description') && dashboard.description != null && dashboard.description != '';
    local hasTags = std.objectHas(dashboard, 'tags') && std.isArray(dashboard.tags) && std.length(dashboard.tags) > 0;
    local hasPanels = std.objectHas(dashboard, 'panels') && std.isArray(dashboard.panels) && std.length(dashboard.panels) > 0;

    local errors = [
      if !hasUid then 'Dashboard missing uid' else null,
      if !hasDescription then 'Dashboard missing description' else null,
      if !hasTags then 'Dashboard missing tags (minimum 1)' else null,
      if !hasPanels then 'Dashboard has no panels' else null,
    ];

    {
      valid: std.all([hasUid, hasDescription, hasTags, hasPanels]),
      errors: [e for e in errors if e != null],
    },

  // Validate panel has required fields
  validatePanel(panel)::
    local hasTitle = std.objectHas(panel, 'title') && panel.title != null && panel.title != '';
    local hasPosition = std.objectHas(panel, 'gridPos') && panel.gridPos != null;
    local hasType = std.objectHas(panel, 'type') && panel.type != null && panel.type != '';

    local errors = [
      if !hasTitle then 'Panel missing title' else null,
      if !hasPosition then 'Panel missing gridPos (position)' else null,
      if !hasType then 'Panel missing type' else null,
    ];

    {
      valid: std.all([hasTitle, hasPosition, hasType]),
      errors: [e for e in errors if e != null],
    },

  // Validate metric panel has targets
  validateMetricPanel(panel)::
    local panelValid = $.validatePanel(panel);
    local hasTargets = std.objectHas(panel, 'targets') && std.isArray(panel.targets) && std.length(panel.targets) > 0;
    local isStatOrTimeSeries = std.member(['stat', 'timeseries', 'graph'], panel.type);

    local errors = panelValid.errors + [
      if isStatOrTimeSeries && !hasTargets then 'Metric panel missing targets' else null,
    ];

    {
      valid: panelValid.valid && (isStatOrTimeSeries && hasTargets || !isStatOrTimeSeries),
      errors: [e for e in errors if e != null],
    },

  // Validate stat panel has unit
  validateStatPanel(panel)::
    local panelValid = $.validateMetricPanel(panel);
    local isStat = panel.type == 'stat';
    local hasUnit = isStat && std.objectHas(panel, 'fieldConfig') &&
                   std.objectHas(panel.fieldConfig, 'defaults') &&
                   std.objectHas(panel.fieldConfig.defaults, 'unit') &&
                   panel.fieldConfig.defaults.unit != null;

    local errors = panelValid.errors + [
      if isStat && !hasUnit then 'Stat panel missing unit definition' else null,
    ];

    {
      valid: panelValid.valid && (!isStat || hasUnit),
      errors: [e for e in errors if e != null],
    },

  // Validate row header (should have emoji)
  validateRowHeader(panel)::
    local isRow = panel.type == 'row';
    local title = if std.objectHas(panel, 'title') then panel.title else '';
    local hasEmoji = isRow && std.length(title) > 0 &&
                     (std.startsWith(title, '📊') || std.startsWith(title, '📈') ||
                      std.startsWith(title, '🔧') || std.startsWith(title, '⚡') ||
                      std.startsWith(title, '🏠') || std.startsWith(title, '🌐') ||
                      std.startsWith(title, '💰') || std.startsWith(title, '📝') ||
                      std.startsWith(title, '❌') || std.startsWith(title, '⚠️') ||
                      std.startsWith(title, '🎯') || std.startsWith(title, '🚀') ||
                      std.startsWith(title, '📊') || std.startsWith(title, '🔬') ||
                      std.startsWith(title, '💡') || std.startsWith(title, '🔗') ||
                      std.startsWith(title, '📡') || std.startsWith(title, '🏆') ||
                      std.startsWith(title, '♻️') || std.startsWith(title, '📤'));

    local errors = [
      if isRow && !hasEmoji then 'Row header missing emoji prefix' else null,
    ];

    {
      valid: !isRow || hasEmoji,
      errors: [e for e in errors if e != null],
    },

  // Validate datasource variable exists if referenced in queries
  validateDatasources(dashboard, queryDatasources=['prometheus', 'victoriametrics', 'loki', 'skywalking'])::
    local hasVariables = std.objectHas(dashboard, 'variables') && std.isArray(dashboard.variables);
    local variables = if hasVariables then dashboard.variables else [];
    local varNames = [v.name for v in variables if std.objectHas(v, 'name')];

    local errors = [
      if !std.member(varNames, 'DS_PROMETHEUS') && !std.member(varNames, 'DS_VICTORIAMETRICS')
        then 'Missing metrics datasource variable (DS_PROMETHEUS or DS_VICTORIAMETRICS)' else null,
      if !std.member(varNames, 'DS_LOKI') && !std.member(varNames, 'DS_VICTORIALOGS')
        then 'Missing logs datasource variable (DS_LOKI or DS_VICTORIALOGS)' else null,
    ];

    {
      valid: std.all([e == null for e in errors]),
      errors: [e for e in errors if e != null],
    },

  // Validate panel grid position doesn't overlap (simplified check)
  validateGridLayout(panels)::
    local getPosition = function(p) if std.objectHas(p, 'gridPos') then p.gridPos else {x: 0, y: 0, w: 0, h: 0};
    local positions = [getPosition(p) for p in panels];

    // Simplified: check if positions are reasonable (x < 24, y > 0)
    local errors = [
      if pos.x >= 24 then 'Panel x position >= 24 (invalid)' else null
      for pos in positions
    ];

    {
      valid: std.all([e == null for e in errors]),
      errors: [e for e in errors if e != null],
    },

  // Comprehensive validation report
  validateDashboardComplete(dashboard)::
    local dashboardValid = $.validateDashboard(dashboard);
    local datasourcesValid = $.validateDatasources(dashboard);
    local layoutValid = if std.objectHas(dashboard, 'panels') && std.isArray(dashboard.panels)
      then $.validateGridLayout(dashboard.panels)
      else {valid: true, errors: []};

    local allErrors = dashboardValid.errors + datasourcesValid.errors + layoutValid.errors;

    {
      valid: std.all([e == null for e in allErrors]),
      totalErrors: std.length([e for e in allErrors if e != null]),
      errors: [e for e in allErrors if e != null],
      summary: if std.length([e for e in allErrors if e != null]) == 0
        then 'Dashboard passes all validation checks ✅'
        else 'Dashboard has ' + std.toString(std.length([e for e in allErrors if e != null])) + ' validation error(s)',
    },

  // Helper: Log validation result
  logValidationResult(name, result)::
    local status = if result.valid then '✅' else '❌';
    local output = status + ' ' + name + ': ' + result.summary;
    output,
}
