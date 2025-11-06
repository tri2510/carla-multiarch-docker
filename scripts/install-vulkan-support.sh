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
  vulkan-tools \
  dkms \
  mokutil \
  openssl

DEFAULT_ICD="/usr/share/vulkan/icd.d/nvidia_icd.json"
if [[ -f "$DEFAULT_ICD" ]]; then
  log "Vulkan ICD found: $DEFAULT_ICD"
else
  log "WARNING: Vulkan ICD not found at $DEFAULT_ICD"
fi

log ""
log "Checking Secure Boot status..."
if command -v mokutil >/dev/null 2>&1; then
  if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
    log "Secure Boot is ENABLED"
    log ""
    log "Setting up MOK (Machine Owner Key) for NVIDIA driver signing..."

    MOK_DIR="/var/lib/shim-signed/mok"
    MOK_KEY="$MOK_DIR/MOK.priv"
    MOK_CERT="$MOK_DIR/MOK.der"

    # Generate MOK key if it doesn't exist
    if [[ ! -f "$MOK_KEY" ]] || [[ ! -f "$MOK_CERT" ]]; then
      log "Generating MOK key pair..."
      mkdir -p "$MOK_DIR"
      openssl req -new -x509 -newkey rsa:2048 \
        -keyout "$MOK_KEY" -outform DER -out "$MOK_CERT" \
        -nodes -days 36500 -subj "/CN=$(hostname) Secure Boot Module Signature key"
      chmod 600 "$MOK_KEY"
      log "✓ MOK key generated"
    else
      log "✓ MOK key already exists"
    fi

    # Check if MOK is already enrolled
    if mokutil --list-enrolled 2>/dev/null | grep -q "$(hostname)"; then
      log "✓ MOK key already enrolled"
    else
      log ""
      log "Enrolling MOK key for next reboot..."
      log "You will be prompted to create a password."
      log "Remember this password - you'll need it during reboot!"
      log ""

      if mokutil --import "$MOK_CERT"; then
        log ""
        log "=========================================="
        log "  MOK Enrollment Prepared"
        log "=========================================="
        log ""
        log "Next steps:"
        log "1. Reboot your computer: sudo reboot"
        log "2. A blue 'MOK Manager' screen will appear"
        log "3. Select 'Enroll MOK'"
        log "4. Select 'Continue'"
        log "5. Select 'Yes'"
        log "6. Enter the password you just created"
        log "7. Select 'Reboot'"
        log ""
        log "After reboot, the NVIDIA driver will work with Secure Boot."
        log ""
      else
        log "WARNING: MOK enrollment preparation failed"
      fi
    fi
  else
    log "Secure Boot is DISABLED - driver will load without signing"
  fi
else
  log "Cannot determine Secure Boot status (mokutil not available)"
fi

log ""
log "Testing nvidia-smi..."
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

log ""
log "All done. Reboot if the driver was updated, then run scripts/2-start-carla.sh"
