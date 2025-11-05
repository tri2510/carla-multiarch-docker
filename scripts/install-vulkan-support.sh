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

replace_broken_mirrors() {
  local bad_mirror="https://cesium.di.uminho.pt/pub/ubuntu-archive"
  local fallback="http://archive.ubuntu.com/ubuntu"
  if grep -R "$bad_mirror" /etc/apt/sources.list /etc/apt/sources.list.d  >/dev/null 2>&1; then
    log "Detected unsupported mirror ($bad_mirror); switching to $fallback"
    grep -Rl "$bad_mirror" /etc/apt/sources.list /etc/apt/sources.list.d \
      | while read -r file; do
          sed -i "s|$bad_mirror|$fallback|g" "$file"
        done
  fi
}

prepare_apt_sources() {
  replace_broken_mirrors
}

BASE_PACKAGES=(software-properties-common ubuntu-drivers-common)

prepare_apt_sources

log "Installing base packages: ${BASE_PACKAGES[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y "${BASE_PACKAGES[@]}"

if ! grep -R "graphics-drivers/ppa" /etc/apt/sources.list /etc/apt/sources.list.d >/dev/null 2>&1; then
  log "Adding graphics-drivers PPA"
  add-apt-repository -y ppa:graphics-drivers/ppa
else
  log "graphics-drivers PPA already present"
fi

log "Updating apt index..."
apt-get update -y

log "Upgrading existing packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

recommend_driver() {
  ubuntu-drivers devices 2>/dev/null | awk '/recommended/ {print $3; exit}'
}

install_driver() {
  local pkg="$(recommend_driver)"
  if [[ -z "$pkg" ]]; then
    pkg="nvidia-driver-535"
    log "Falling back to $pkg"
  else
    log "Recommended driver: $pkg"
  fi
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    log "Driver $pkg already installed"
  else
    log "Installing $pkg"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  fi
}

install_driver

log "Installing Vulkan packages (nvidia-settings vulkan vulkan-utils mesa-vulkan-drivers{,:i386})"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nvidia-settings \
  vulkan \
  vulkan-utils \
  mesa-vulkan-drivers \
  mesa-vulkan-drivers:i386

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
