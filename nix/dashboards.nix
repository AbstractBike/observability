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

  # ── Vendor directory ────────────────────────────────────────────────────────
  mkdir -p vendor/github.com/grafana/grafonnet
  mkdir -p vendor/github.com/jsonnet-libs/xtd
  mkdir -p vendor/github.com/jsonnet-libs/docsonnet

  cp -r ${grafonnet}/. vendor/github.com/grafana/grafonnet/
  cp -r ${xtd}/.        vendor/github.com/jsonnet-libs/xtd/
  cp -r ${docsonnet}/.  vendor/github.com/jsonnet-libs/docsonnet/

  # ── Compile Jsonnet → JSON ───────────────────────────────────────────────────
  JPATH="-J $PWD/vendor -J ${observabilityDashboardsPath}"

  mkdir -p $out/heater $out/pipeline $out/overview

  for f in ${observabilityDashboardsPath}/heater/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling heater/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/heater/$name.json"
  done

  for f in ${observabilityDashboardsPath}/pipeline/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling pipeline/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/pipeline/$name.json"
  done

  mkdir -p $out/services

  for f in ${observabilityDashboardsPath}/services/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling services/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/services/$name.json"
  done

  mkdir -p $out/observability

  for f in ${observabilityDashboardsPath}/observability/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling observability/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/observability/$name.json"
  done

  mkdir -p $out/slo

  for f in ${observabilityDashboardsPath}/slo/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling slo/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/slo/$name.json"
  done

  # ── Compile home Jsonnet dashboards ─────────────────────────────────────────
  mkdir -p $out/home

  for f in ${observabilityDashboardsPath}/home/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling home/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/home/$name.json"
  done

  # ── Compile overview Jsonnet dashboards ─────────────────────────────────────
  for f in ${observabilityDashboardsPath}/overview/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling overview/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/overview/$name.json"
  done

  # ── Compile APM Jsonnet dashboards ──────────────────────────────────────────
  mkdir -p $out/apm

  for f in ${observabilityDashboardsPath}/apm/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling apm/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/apm/$name.json"
  done

  # ── Copy static JSON dashboards ──────────────────────────────────────────────
  cp ${observabilityDashboardsPath}/overview/*.json "$out/overview/" 2>/dev/null || true

  mkdir -p $out/claude

  for f in ${observabilityDashboardsPath}/claude/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling claude/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/claude/$name.json"
  done

  cp ${observabilityDashboardsPath}/claude/*.json "$out/claude/" 2>/dev/null || true

  mkdir -p $out/apm
  cp ${observabilityDashboardsPath}/apm/*.json "$out/apm/" 2>/dev/null || true

  mkdir -p $out/claude-chat
  cp ${observabilityDashboardsPath}/claude-chat/*.json "$out/claude-chat/" 2>/dev/null || true

  # ── Auto-include dashboards_new/ (drop zone) ───────────────────────────────
  mkdir -p $out/new
  shopt -s nullglob
  for f in ${observabilityDashboardsPath}/dashboards_new/*.jsonnet; do
    name=$(basename "$f" .jsonnet)
    echo "Compiling new/$name.jsonnet..."
    jsonnet $JPATH "$f" > "$out/new/$name.json"
  done
  for f in ${observabilityDashboardsPath}/dashboards_new/*.json; do
    name=$(basename "$f")
    echo "Copying new/$name..."
    cp "$f" "$out/new/$name"
  done
  shopt -u nullglob

  echo "Done. Dashboards compiled to $out"
''
