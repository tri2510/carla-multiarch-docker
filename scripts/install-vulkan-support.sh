#!/usr/bin/env bash
# Install NVIDIA graphics-drivers PPA + driver + Vulkan tooling on Ubuntu

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[install-vulkan-support] Please run with sudo (root privileges required)." >&2
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "[install-vulkan-support] This script expects apt-based systems (Ubuntu/Debian)." >&2
  exit 1
fi

log() { printf '[install-vulkan-support] %s\n' "$*"; }

log "Adding graphics-drivers PPA"
add-apt-repository -y ppa:graphics-drivers/ppa

log "Upgrading existing packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

log "Installing NVIDIA driver 570, nvidia-settings, libvulkan1, and vulkan-tools"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nvidia-driver-570 \
  nvidia-settings \
  libvulkan1 \
  vulkan-tools

DEFAULT_ICD="/usr/share/vulkan/icd.d/nvidia_icd.json"
if [[ -f "$DEFAULT_ICD" ]]; then
  log "Vulkan ICD found: $DEFAULT_ICD"
else
  log "WARNING: Vulkan ICD not found at $DEFAULT_ICD"
fi

log "Testing nvidia-smi"
if ! nvidia-smi >/dev/null 2>&1; then
  log "WARNING: nvidia-smi failed (reboot may be required)."
fi

if command -v vulkaninfo >/dev/null 2>&1; then
  if ! vulkaninfo --summary >/dev/null 2>&1; then
    log "WARNING: vulkaninfo failed."
  fi
else
  log "WARNING: vulkaninfo missing."
fi

log "All done. Reboot if the driver was updated, then run scripts/2-start-carla.sh"
