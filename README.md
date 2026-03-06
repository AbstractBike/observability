# Observability Configuration

Complete observability stack configuration for Grafana dashboards, alerts, and metrics.

## 📦 What's Included

- **Dashboards:** 40+ Grafana dashboards for system, application, and APM monitoring
- **Alerts:** vmalert and Alertmanager configuration examples
- **Services:** Service registry and tracing configuration
- **Documentation:** Architecture standards, playbooks, and integration guides

## 🏗️ Architecture

This repository provides NixOS integration for observability configuration. It's designed to be used as a NixOS flake input.

### Integration Pattern

The repo exposes:
- NixOS module for observability configuration
- Compiled dashboards package
- Development tools (validation, dependency analysis)

### Usage as NixOS Flake Input

```nix
{
  description = "My NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    observability.url = "path:/home/digger/git/observability";
  };

  outputs = { self, nixpkgs, observability, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        observability.nixosModules.default
      ];
      specialArgs = { inherit observability; };
    };
  };
}
```

## 📁 Directory Structure

```
observability/
├── dashboards-src/          # Grafana dashboard definitions (jsonnet)
│   ├── heater/              # Heater machine dashboards
│   ├── pipeline/             # Pipeline dashboards
│   ├── services/            # Service-specific dashboards
│   ├── observability/       # Observability infrastructure dashboards
│   ├── slo/                 # SLO monitoring dashboards
│   ├── overview/            # Overview dashboards
│   ├── apm/                 # APM and tracing dashboards
│   ├── claude/              # Claude-related dashboards
│   ├── claude-chat/         # Claude chat monitoring
│   └── dashboards_new/      # Drop zone for new dashboards
├── nix/                     # NixOS integration
│   └── dashboards.nix      # Dashboard compilation logic
├── flake.nix                # NixOS flake configuration
├── *.md                     # Documentation and guides
└── *.yaml                   # Configuration examples
```

## 🔧 Development

### Prerequisites

- NixOS with flakes enabled
- go-jsonnet (for dashboard compilation)
- jq (for JSON validation)

### Building Dashboards

```bash
# Compile all dashboards
nix build .#dashboards

# Validate dashboards compile
nix develop
validate-dashboards

# Analyze dashboard dependencies
nix develop
analyze-dependencies
```

### Development Shell

```bash
nix develop
```

This provides:
- `validate-dashboards` - Compile all dashboards and validate syntax
- `analyze-dependencies` - Extract dashboard dependencies
- Access to go-jsonnet, jq, yq-go tools

## 📚 Documentation

- **ARCHITECTURE-STANDARDS.md** - Dashboard design standards
- **SERVICE-REGISTRY.md** - Registered services and their instrumentation
- **DEVELOPMENT-PLAYBOOK.md** - Development workflows and guidelines
- **DASHBOARD-MAINTENANCE.md** - Dashboard lifecycle management
- **ALERT-INTEGRATION-GUIDE.md** - Alert configuration best practices

## 🔒 Security

- No secrets stored in this repository
- Use SOPS + age for sensitive configuration
- Follow security best practices in dashboards and alerts

## 📊 Dashboard Categories

### Overview
- Home dashboard - System-wide health overview
- Services health - Service dependency map
- Claude Code - AI agent observability

### Infrastructure
- VictoriaMetrics - Metrics storage monitoring
- VictoriaLogs - Log aggregation monitoring
- SkyWalking - APM and tracing
- Alertmanager - Alert management
- vmalert - Alert evaluation

### Services
- PostgreSQL - Database metrics
- Redis - Cache metrics
- Redpanda - Kafka broker metrics
- Temporal - Workflow metrics
- ClickHouse - Analytics DB metrics
- Elasticsearch - Search metrics
- Vector - Log shipping metrics
- Nexus - Artifact repository metrics

### Applications
- Heater - Home automation dashboards
- Arbitraje - Trading bot dashboards
- Scalable Market - Platform dashboards
- Claude Chat - AI assistant monitoring

## 🚀 CI/CD

This repository supports independent CI/CD:

- **Dashboard validation** - Compile all dashboards on every push
- **Syntax checking** - Validate JSON output
- **Quality gates** - Enforce dashboard standards

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch
3. Add or modify dashboards
4. Validate with `validate-dashboards`
5. Submit a pull request

## 📄 License

MIT License - See LICENSE file for details

## 🔗 Links

- Grafana: http://grafana.pin
- VictoriaMetrics: http://192.168.0.4:8428
- VictoriaLogs: http://192.168.0.4:9428
- SkyWalking: http://traces.pin
