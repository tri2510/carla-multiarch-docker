#!/usr/bin/env bash
# Install Python 3.7 for CARLA compatibility
# CARLA Python API requires Python 3.7 specifically

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[install-python37] Please run with sudo (root privileges required)." >&2
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "[install-python37] This script expects apt-based systems (Ubuntu/Debian)." >&2
  exit 1
fi

log() { printf '[install-python37] %s\n' "$*"; }

log "Installing Python 3.7 from deadsnakes PPA..."
log ""

# Add deadsnakes PPA for Python 3.7
if ! grep -R "deadsnakes/ppa" /etc/apt/sources.list /etc/apt/sources.list.d >/dev/null 2>&1; then
  log "Adding deadsnakes PPA"
  add-apt-repository -y ppa:deadsnakes/ppa
else
  log "deadsnakes PPA already present"
fi

log "Updating apt index..."
apt-get update -y

log "Installing Python 3.7 and dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3.7 \
  python3.7-dev \
  python3.7-distutils \
  python3-pip

log ""
log "Verifying Python 3.7 installation..."
if python3.7 --version >/dev/null 2>&1; then
  PYTHON_VERSION=$(python3.7 --version)
  log "✓ $PYTHON_VERSION installed"
else
  log "✗ Python 3.7 installation failed"
  exit 1
fi

log ""
log "Installing pygame for Python 3.7..."
sudo -u "$SUDO_USER" python3.7 -m pip install --user --upgrade pip >/dev/null 2>&1 || true
sudo -u "$SUDO_USER" python3.7 -m pip install --user pygame numpy >/dev/null 2>&1

log ""
log "Testing pygame import..."
if sudo -u "$SUDO_USER" python3.7 -c "import pygame; print('✓ pygame', pygame.__version__)" 2>/dev/null; then
  log "✓ pygame installed successfully"
else
  log "⚠ pygame installation may have issues, but continuing..."
fi

log ""
log "Testing numpy import..."
if sudo -u "$SUDO_USER" python3.7 -c "import numpy; print('✓ numpy', numpy.__version__)" 2>/dev/null; then
  log "✓ numpy installed successfully"
else
  log "⚠ numpy installation may have issues, but continuing..."
fi

log ""
log "All done! Python 3.7 is ready for CARLA."
log "You can now run: scripts/3-carla-helper.sh"
