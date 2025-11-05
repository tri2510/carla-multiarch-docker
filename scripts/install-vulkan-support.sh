#!/usr/bin/env bash
# Install/verify NVIDIA driver + Vulkan ICDs on Ubuntu to satisfy CARLA/UE

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

APT_PACKAGES=(
  ubuntu-drivers-common
  vulkan-utils
  mesa-vulkan-drivers
  mesa-vulkan-drivers:i386
)

log "Updating apt index..."
apt-get update -y >/dev/null

log "Installing Vulkan prerequisites: ${APT_PACKAGES[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}"

recommend_driver() {
  if ! command -v ubuntu-drivers >/dev/null 2>&1; then
    return 1
  fi
  ubuntu-drivers devices 2>/dev/null | awk '/recommended/ {print $3; exit}'
}

CURRENT_DRIVER="$(command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || true)"
RECOMMENDED_DRIVER="$(recommend_driver || true)"

if [[ -n "$RECOMMENDED_DRIVER" ]]; then
  if dpkg -s "$RECOMMENDED_DRIVER" >/dev/null 2>&1; then
    log "Recommended driver $RECOMMENDED_DRIVER already installed (nvidia-smi reports version ${CURRENT_DRIVER:-unknown})."
  else
    log "Installing recommended NVIDIA driver: $RECOMMENDED_DRIVER"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$RECOMMENDED_DRIVER"
    log "Driver installed. Reboot is recommended before running CARLA."
  fi
else
  log "Could not auto-detect a recommended driver. Skipping driver install (ensure NVIDIA drivers are present)."
fi

# Ensure NVIDIA ICD JSON exists for Vulkan
DEFAULT_ICD="/usr/share/vulkan/icd.d/nvidia_icd.json"
if [[ -f "$DEFAULT_ICD" ]]; then
  log "Found Vulkan ICD: $DEFAULT_ICD"
else
  log "WARNING: NVIDIA Vulkan ICD ($DEFAULT_ICD) not found. Check that the driver installed correctly."
fi

log "Testing nvidia-smi and vulkaninfo --summary"
if command -v nvidia-smi >/dev/null 2>&1; then
  if ! nvidia-smi >/dev/null 2>&1; then
    log "WARNING: nvidia-smi failed; a reboot may be required."
  fi
else
  log "WARNING: nvidia-smi missing; install NVIDIA drivers manually."
fi

if command -v vulkaninfo >/dev/null 2>&1; then
  if ! vulkaninfo --summary >/dev/null 2>&1; then
    log "WARNING: vulkaninfo failed. Check driver/ICD installation."
  fi
else
  log "WARNING: vulkaninfo missing despite vulkan-utils install."
fi

log "All done. If drivers were installed/updated, reboot before launching CARLA."
