#!/usr/bin/env bash
# Scaffolds clients/<slug>/values.yaml for a new client. Does not deploy
# anything — committing and pushing the new directory is what triggers
# Argo CD's ApplicationSet to generate the corresponding Application.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <client-slug>" >&2
  exit 1
fi

SLUG="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="$ROOT_DIR/clients/$SLUG"

if [[ ! "$SLUG" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
  echo "error: slug must be a valid Kubernetes namespace name (lowercase alphanumeric and '-')" >&2
  exit 1
fi

if [ -d "$CLIENT_DIR" ]; then
  echo "error: $CLIENT_DIR already exists" >&2
  exit 1
fi

mkdir -p "$CLIENT_DIR"
cat > "$CLIENT_DIR/values.yaml" <<EOF
# Overrides only — unset fields fall back to charts/sample-app/values.yaml.
client:
  slug: $SLUG

image:
  tag: "0.1.0"
EOF

echo "Created $CLIENT_DIR/values.yaml"
echo "Next: review the file, then commit and push to trigger provisioning."
echo
echo "A real deployment of this pattern should also seal any per-client"
echo "secrets here (e.g. with Sealed Secrets or External Secrets Operator) —"
echo "this template intentionally does not include that tooling. See"
echo "docs/ARCHITECTURE.md."
