{
  description = "Observability Configuration - Dashboards, Alerts, and Metrics for Grafana";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # NixOS module for observability configuration
      nixosModules.default = { config, pkgs, ... }:
        let
          # Define dashboards path for external consumption
          observabilityDashboardsPath = ./dashboards-src;
        in
        {
          # Expose observability configuration to external modules
          options.services.observability = {
            enable = pkgs.lib.mkEnableOption "Enable observability configuration";

            dashboardsPath = pkgs.lib.mkOption {
              type = pkgs.lib.types.path;
              default = observabilityDashboardsPath;
              description = "Path to observability dashboards directory";
            };

            dashboards = pkgs.lib.mkOption {
              type = pkgs.lib.types.package;
              default = pkgs.emptyDirectory;
              description = "Compiled Grafana dashboards package";
            };
          };

          # Set defaults
          config.services.observability.dashboardsPath = observabilityDashboardsPath;
        };

      # Packages
      packages.${system} = {
        # Compiled dashboards package
        dashboards = pkgs.callPackage ./nix/dashboards.nix {
          observabilityDashboardsPath = ./dashboards-src;
        };

        # Dashboard validator script
        validate-dashboards = pkgs.writeShellScriptBin "validate-dashboards" ''
          set -euo pipefail
          echo "Validating observability dashboards..."

          # Check that jsonnet compiles all dashboards
          if command -v go-jsonnet &> /dev/null; then
            echo "Checking jsonnet compilation..."
            cd ${./dashboards-src}
            for dir in */; do
              if [ -f "$dir"*.jsonnet ]; then
                echo "  Validating $dir dashboards..."
                find "$dir" -name "*.jsonnet" -exec go-jsonnet {} \; > /dev/null
              fi
            done
            echo "✅ All dashboards validated successfully"
          else
            echo "⚠️  go-jsonnet not found - skipping validation"
          fi
        '';

        # Dashboard dependency analyzer
        analyze-dependencies = pkgs.writeShellScriptBin "analyze-dashboard-dependencies" ''
          set -euo pipefail
          echo "Analyzing dashboard dependencies..."

          find ${./dashboards-src} -name "*.jsonnet" -exec grep -h "import\|local\|importstr" {} \; | sort -u

          echo "✅ Dependencies analyzed"
        '';
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          go-jsonnet
          jq
          yq-go
        ];

        shellHook = ''
          echo "🎯 Observability Development Environment"
          echo ""
          echo "Available commands:"
          echo "  validate-dashboards  - Validate all dashboards compile correctly"
          echo "  analyze-dependencies  - Analyze dashboard dependencies"
          echo ""
          echo "Dashboards location: ${./dashboards-src}"
        '';
      };
    };
}
