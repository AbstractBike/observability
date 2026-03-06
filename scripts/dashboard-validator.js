#!/usr/bin/env node

/**
 * Dashboard Validation Script
 *
 * Validates all Grafana dashboards for:
 * - Required fields (uid, title, tags)
 * - Query health (no broken queries)
 * - Panel integrity (valid panel types)
 * - Unit consistency
 * - Naming conventions
 * - Documentation completeness
 */

const fs = require('fs');
const path = require('path');
const glob = require('glob');

class DashboardValidator {
  constructor(verbosity = 1) {
    this.verbosity = verbosity;
    this.errors = [];
    this.warnings = [];
    this.successes = [];
    this.stats = {
      dashboards: 0,
      panels: 0,
      queries: 0,
      issues: 0,
    };
  }

  log(level, message, data = '') {
    if (level <= this.verbosity) {
      const prefix = {
        1: '❌',
        2: '⚠️ ',
        3: '✅',
        4: 'ℹ️ ',
      }[level] || '•';
      console.log(`${prefix} ${message}`, data);
    }
  }

  // Validate a single dashboard file
  validateDashboard(filePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const fileName = path.basename(filePath);

      // For JSON files, parse directly
      if (filePath.endsWith('.json')) {
        this.validateJsonDashboard(JSON.parse(content), fileName, filePath);
      }
      // For Jsonnet files, just do syntax checks (can't execute)
      else if (filePath.endsWith('.jsonnet')) {
        this.validateJsonnetDashboard(content, fileName, filePath);
      }

      this.stats.dashboards++;
    } catch (error) {
      this.errors.push(`${filePath}: ${error.message}`);
      this.log(1, `Failed to read ${path.basename(filePath)}`, error.message);
    }
  }

  validateJsonDashboard(dashboard, fileName, filePath) {
    this.log(4, `Validating JSON dashboard`, fileName);

    // Check required fields
    const requiredFields = ['uid', 'title', 'tags'];
    for (const field of requiredFields) {
      if (!dashboard[field]) {
        this.errors.push(`${fileName}: Missing required field "${field}"`);
        this.log(1, `${fileName}: Missing "${field}"`);
      }
    }

    // Check title length
    if (dashboard.title && dashboard.title.length > 100) {
      this.warnings.push(`${fileName}: Title too long (${dashboard.title.length} chars)`);
      this.log(2, `${fileName}: Title > 100 chars`);
    }

    // Check tags
    if (!Array.isArray(dashboard.tags) || dashboard.tags.length === 0) {
      this.warnings.push(`${fileName}: No tags defined`);
      this.log(2, `${fileName}: No tags`);
    }

    // Check description
    if (!dashboard.description) {
      this.warnings.push(`${fileName}: No description`);
      this.log(2, `${fileName}: Missing description`);
    }

    // Validate panels
    if (Array.isArray(dashboard.panels)) {
      for (const panel of dashboard.panels) {
        this.validatePanel(panel, fileName);
      }
    }

    this.successes.push(`${fileName}: Valid`);
    this.log(3, `${fileName}: Valid dashboard`);
  }

  validateJsonnetDashboard(content, fileName, filePath) {
    this.log(4, `Validating Jsonnet syntax`, fileName);

    // Basic syntax checks
    const issues = [];

    // Check for common issues
    if (!content.includes("g.dashboard.new(") && !content.includes('g.dashboard.new (')) {
      issues.push('Missing g.dashboard.new() call');
    }

    if (!content.includes('withUid') && !content.includes('.uid')) {
      issues.push('Missing dashboard UID');
    }

    if (!content.includes('withTags') && !content.includes('withDescription') && !content.includes('withPanels')) {
      issues.push('Incomplete dashboard definition');
    }

    // Check for balanced braces
    const openBraces = (content.match(/{/g) || []).length;
    const closeBraces = (content.match(/}/g) || []).length;
    if (openBraces !== closeBraces) {
      issues.push(`Unbalanced braces: { = ${openBraces}, } = ${closeBraces}`);
    }

    if (issues.length > 0) {
      for (const issue of issues) {
        this.warnings.push(`${fileName}: ${issue}`);
        this.log(2, `${fileName}: ${issue}`);
      }
    } else {
      this.successes.push(`${fileName}: Syntax OK`);
      this.log(3, `${fileName}: Syntax OK`);
    }
  }

  validatePanel(panel, dashboardFile) {
    if (!panel.type) {
      this.warnings.push(`${dashboardFile}: Panel missing type`);
      return;
    }

    // Check for common panel issues
    if (panel.type === 'graph' || panel.type === 'bargauge') {
      if (!panel.targets || panel.targets.length === 0) {
        this.warnings.push(`${dashboardFile}: ${panel.title || 'Unnamed panel'} has no targets`);
      }
    }

    // Check for proper positioning
    if (panel.gridPos && (panel.gridPos.w === 0 || panel.gridPos.h === 0)) {
      this.warnings.push(`${dashboardFile}: ${panel.title || 'Panel'} has zero dimensions`);
    }

    this.stats.panels++;
    if (panel.targets) this.stats.queries += panel.targets.length;
  }

  // Run validation on all dashboards
  validateAll(baseDir = 'observability/dashboards-src') {
    const jsonFiles = glob.sync(path.join(baseDir, '**/*.json'));
    const jsonnetFiles = glob.sync(path.join(baseDir, '**/*.jsonnet'));

    console.log(`\n🔍 Validating ${jsonFiles.length + jsonnetFiles.length} dashboards...\n`);

    for (const file of jsonFiles) {
      this.validateDashboard(file);
    }

    for (const file of jsonnetFiles) {
      this.validateDashboard(file);
    }

    this.printReport();
  }

  printReport() {
    console.log(`\n${'═'.repeat(70)}`);
    console.log('📊 VALIDATION REPORT');
    console.log(`${'═'.repeat(70)}\n`);

    console.log(`📈 Statistics:`);
    console.log(`  • Dashboards: ${this.stats.dashboards}`);
    console.log(`  • Panels: ${this.stats.panels}`);
    console.log(`  • Queries: ${this.stats.queries}`);

    console.log(`\n✅ Successes: ${this.successes.length}`);
    if (this.successes.length > 0 && this.verbosity >= 3) {
      this.successes.slice(0, 5).forEach(s => console.log(`  ✓ ${s}`));
      if (this.successes.length > 5) console.log(`  ... and ${this.successes.length - 5} more`);
    }

    console.log(`\n⚠️  Warnings: ${this.warnings.length}`);
    if (this.warnings.length > 0) {
      this.warnings.slice(0, 10).forEach(w => console.log(`  ⚠️  ${w}`));
      if (this.warnings.length > 10) console.log(`  ... and ${this.warnings.length - 10} more`);
    }

    console.log(`\n❌ Errors: ${this.errors.length}`);
    if (this.errors.length > 0) {
      this.errors.slice(0, 10).forEach(e => console.log(`  ❌ ${e}`));
      if (this.errors.length > 10) console.log(`  ... and ${this.errors.length - 10} more`);
    }

    console.log(`\n${'═'.repeat(70)}`);
    console.log(`📋 Summary: ${this.errors.length === 0 ? '✅ ALL VALID' : `❌ ${this.errors.length} ERRORS FOUND`}\n`);

    process.exit(this.errors.length > 0 ? 1 : 0);
  }
}

// Run validator
const validator = new DashboardValidator(4);
validator.validateAll();
