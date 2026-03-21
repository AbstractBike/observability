{ pkgs, observabilityDashboardsPath }:

let
  grafonnet = pkgs.fetchFromGitHub {
    owner = "grafana";
    repo  = "grafonnet";
    rev   = "7380c9c64fb973f34c3ec46265621a2b0dee0058";
    hash  = "sha256-WS3Z/k9fDSleK6RVPTFQ9Um26GRFv/kxZhARXpGkS10=";
  };

  xtd = pkgs.fetchFromGitHub {
    owner = "jsonnet-libs";
    repo  = "xtd";
    rev   = "4d7f8cb24d613430799f9d56809cc6964f35cea9";
    hash  = "sha256-MWinI7gX39UIDVh9kzkHFH6jsKZoI294paQUWd/4+ag=";
  };

  docsonnet = pkgs.fetchFromGitHub {
    owner = "jsonnet-libs";
    repo  = "docsonnet";
    rev   = "6ac6c69685b8c29c54515448eaca583da2d88150";
    hash  = "sha256-Uy86lIQbFjebNiAAp0dJ8rAtv16j4V4pXMPcl+llwBA=";
  };
in
pkgs.runCommand "grafana-dashboards" {
  nativeBuildInputs = [ pkgs.go-jsonnet ];
} ''
  set -euo pipefail

  mkdir -p vendor/github.com/grafana/grafonnet
  mkdir -p vendor/github.com/jsonnet-libs/xtd
  mkdir -p vendor/github.com/jsonnet-libs/docsonnet

  cp -r ${grafonnet}/. vendor/github.com/grafana/grafonnet/
  cp -r ${xtd}/.        vendor/github.com/jsonnet-libs/xtd/
  cp -r ${docsonnet}/.  vendor/github.com/jsonnet-libs/docsonnet/

  JPATH="-J $PWD/vendor -J ${observabilityDashboardsPath}"

  mkdir -p $out/home

  for f in ${observabilityDashboardsPath}/home/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling home/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/home/$name.json"
  done

  echo "Done. Dashboards compiled to $out"
''
