#!/usr/bin/env bash
# Static validation only: no Kubernetes cluster is used or required.
# - helm lint / helm template against charts/sample-app for every client
# - YAML syntax check across the whole repository
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="$ROOT_DIR/charts/sample-app"
FAIL=0

echo "=== helm lint ==="
if ! helm lint "$CHART_DIR" --set client.slug=lint-check --set image.tag=0.1.0; then
  FAIL=1
fi

echo
echo "=== helm template per client ==="
for client_dir in "$ROOT_DIR"/clients/*/; do
  slug="$(basename "$client_dir")"
  echo "--- $slug ---"
  if ! helm template "$slug" "$CHART_DIR" -f "$client_dir/values.yaml" > /dev/null; then
    echo "error: helm template failed for $slug" >&2
    FAIL=1
  fi
done

echo
echo "=== YAML syntax check ==="
if command -v python3 >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do
    if ! python3 -c "import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1])))" "$f" 2>/tmp/yaml_err; then
      echo "error: invalid YAML in $f" >&2
      cat /tmp/yaml_err >&2
      FAIL=1
    fi
  done < <(find "$ROOT_DIR" -name '*.yaml' -not -path '*/node_modules/*' -print0)
else
  echo "python3 not found; skipping YAML syntax check" >&2
fi

echo
if [ "$FAIL" -ne 0 ]; then
  echo "Validation FAILED." >&2
  exit 1
fi
echo "Validation passed."
