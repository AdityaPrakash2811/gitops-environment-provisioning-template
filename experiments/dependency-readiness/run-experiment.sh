#!/usr/bin/env bash
# Renders charts/sample-app with the dependency-readiness guard enabled and
# disabled, and diffs the resulting "app" Deployment manifest. Render-only —
# requires `helm`, does not require a Kubernetes cluster.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHART_DIR="$ROOT_DIR/charts/sample-app"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Rendering with waitForDependency=true ..."
helm template sample-app "$CHART_DIR" \
  --set client.slug=experiment-client \
  --set image.tag=0.1.0 \
  --set app.waitForDependency=true \
  --show-only templates/app.yaml \
  > "$WORK_DIR/guard-enabled.yaml"

echo "Rendering with waitForDependency=false ..."
helm template sample-app "$CHART_DIR" \
  --set client.slug=experiment-client \
  --set image.tag=0.1.0 \
  --set app.waitForDependency=false \
  --show-only templates/app.yaml \
  > "$WORK_DIR/guard-disabled.yaml"

echo
echo "=== Diff: guard disabled -> guard enabled ==="
diff -u "$WORK_DIR/guard-disabled.yaml" "$WORK_DIR/guard-enabled.yaml" || true

echo
echo "Done. See experiments/dependency-readiness/README.md for what this diff"
echo "does and does not demonstrate."
