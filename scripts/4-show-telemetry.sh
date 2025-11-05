#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
if ! ss -tlnp 2>/dev/null | grep -q ":2000 "; then
  echo "CARLA not detected on port 2000. Start it with scripts/2-start-carla.sh first." >&2
  exit 1
fi
exec "$SCRIPT_DIR/4-telemetry-demo.py"
