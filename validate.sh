#!/usr/bin/env bash
# Quick jsonnet syntax validation — runs in ~2s vs 4min for nix build
# Usage: ./validate.sh [file.jsonnet ...]  (no arg = validate all)
# Vendor: homelab repo at ../homelab/vendor (grafonnet + xtd)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSONNET=$(which go-jsonnet 2>/dev/null || \
  ls /nix/store/*go-jsonnet*/bin/jsonnet 2>/dev/null | tail -1 || \
  echo "jsonnet")
JPATH="-J ${SCRIPT_DIR}/../homelab/vendor -J ${SCRIPT_DIR}/dashboards-src"
ok=0; fail=0

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  mapfile -t files < <(find "${SCRIPT_DIR}/dashboards-src" -name "*.jsonnet")
fi

for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  if "$JSONNET" $JPATH "$f" > /dev/null 2>&1; then
    echo "  ✓ $f"; ((ok++)) || true
  else
    echo "  ✗ $f"
    "$JSONNET" $JPATH "$f" 2>&1 | head -5
    ((fail++)) || true
  fi
done
echo ""; echo "Results: $ok OK, $fail FAILED"
[[ $fail -eq 0 ]]
