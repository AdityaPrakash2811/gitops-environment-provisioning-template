#!/usr/bin/env bash
# Removes clients/<slug>. Does not touch the cluster directly — committing
# and pushing the deletion is what causes Argo CD's prune:true to remove the
# generated Application, its namespace, and everything in it.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <client-slug>" >&2
  exit 1
fi

SLUG="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="$ROOT_DIR/clients/$SLUG"

if [ ! -d "$CLIENT_DIR" ]; then
  echo "error: $CLIENT_DIR does not exist" >&2
  exit 1
fi

read -r -p "This will delete $CLIENT_DIR. Continue? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

rm -rf "$CLIENT_DIR"
echo "Removed $CLIENT_DIR"
echo "Next: commit and push this deletion. Argo CD's pruning will remove the"
echo "generated Application '$SLUG' and its namespace once it reconciles."
