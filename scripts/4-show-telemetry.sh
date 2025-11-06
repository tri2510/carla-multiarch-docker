#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check for Python 3.7
PYTHON_CMD=""
for py in python3.7 python37 python3; do
  if command -v "$py" >/dev/null 2>&1; then
    PYTHON_CMD="$py"
    break
  fi
done

if [[ -z "$PYTHON_CMD" ]]; then
  echo "Error: Python 3 not found. Please install python3.7" >&2
  exit 1
fi

if ! ss -tlnp 2>/dev/null | grep -q ":2000 "; then
  echo "CARLA not detected on port 2000. Start it with scripts/2-start-carla.sh first." >&2
  exit 1
fi

exec "$PYTHON_CMD" "$SCRIPT_DIR/4-telemetry-demo.py"
