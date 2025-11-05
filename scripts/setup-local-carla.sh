#!/usr/bin/env bash
# Download and unpack the CARLA Linux binary into the repo for host execution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CARLA_VERSION="${CARLA_VERSION:-0.9.15}"
DEFAULT_TARBALL="CARLA_${CARLA_VERSION}.tar.gz"
CARLA_TARBALL="${CARLA_TARBALL:-$DEFAULT_TARBALL}"
CARLA_URL="${CARLA_DOWNLOAD_URL:-https://carla-releases.b-cdn.net/Linux/${CARLA_TARBALL}}"
CACHE_DIR="${CARLA_CACHE_DIR:-$HOME/.cache/carla}"
INSTALL_DIR="${LOCAL_CARLA_DIR:-$PROJECT_ROOT/local_carla}"
MARKER_FILE="$INSTALL_DIR/.carla-version"
DEFAULT_TARBALL_PATH="$CACHE_DIR/$CARLA_TARBALL"
TARBALL_PATH="${CARLA_TARBALL_PATH:-$DEFAULT_TARBALL_PATH}"
DEFAULT_STRIP="0"
if [[ "$CARLA_TARBALL" == Carla-*-Linux-Shipping.tar.gz ]]; then
  DEFAULT_STRIP="1"
fi
STRIP_COMPONENTS="${CARLA_STRIP_COMPONENTS:-$DEFAULT_STRIP}"
FORCE_DOWNLOAD=false

log() { printf '[setup-local-carla] %s\n' "$*"; }
err() { printf '[setup-local-carla][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: scripts/setup-local-carla.sh [--force-download] [--tarball PATH]

  --force-download   Always fetch CARLA even if the tarball exists
  --tarball PATH     Use an existing CARLA archive at PATH (skips download)

Environment overrides:
  CARLA_VERSION, CARLA_TARBALL_PATH, CARLA_CACHE_DIR, LOCAL_CARLA_DIR
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-download)
      FORCE_DOWNLOAD=true
      ;;
    --tarball)
      [[ $# -lt 2 ]] && err "--tarball requires a path"
      TARBALL_PATH="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      ;;
  esac
  shift || true
done

download_tarball() {
  mkdir -p "$CACHE_DIR"

  if [ -f "$TARBALL_PATH" ] && [ "$FORCE_DOWNLOAD" = false ]; then
    log "Found existing tarball at $TARBALL_PATH; skipping download"
    return
  fi

  log "Downloading $CARLA_TARBALL (~10GB) to $TARBALL_PATH"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c --console-log-level=warn --summary-interval=15 \
      --max-connection-per-server=16 --split=16 --min-split-size=5M \
      -d "$(dirname "$TARBALL_PATH")" -o "$(basename "$TARBALL_PATH")" "$CARLA_URL"
  elif command -v curl >/dev/null 2>&1; then
    curl -L "$CARLA_URL" -o "$TARBALL_PATH"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$TARBALL_PATH" "$CARLA_URL"
  else
    err "Need aria2c, curl, or wget to download $CARLA_TARBALL"
  fi
}

ensure_tarball_valid() {
  download_tarball
  if tar -tzf "$TARBALL_PATH" >/dev/null 2>&1; then
    return
  fi

  err "Tarball $TARBALL_PATH is corrupted. Replace it (e.g., copy your backup or run with --force-download)."
}

unpack_tarball() {
  [ -f "$TARBALL_PATH" ] || err "Missing tarball $TARBALL_PATH"

  mkdir -p "$INSTALL_DIR"
  if [ -f "$MARKER_FILE" ] && grep -qx "$CARLA_VERSION" "$MARKER_FILE"; then
    log "CARLA $CARLA_VERSION already unpacked in $INSTALL_DIR"
    return
  fi

  log "Extracting to $INSTALL_DIR"
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  TAR_ARGS=(-xzf "$TARBALL_PATH" -C "$INSTALL_DIR")
  if [ "$STRIP_COMPONENTS" -gt 0 ]; then
    TAR_ARGS+=(--strip-components="$STRIP_COMPONENTS")
  fi
  if ! tar "${TAR_ARGS[@]}"; then
    err "Extraction failed. Ensure $TARBALL_PATH is a valid CARLA tarball."
  fi
  printf '%s\n' "$CARLA_VERSION" > "$MARKER_FILE"
}

find_carla_binary() {
  local candidates=(CarlaUE5.sh CarlaUE4.sh CarlaUnreal.sh)
  for candidate in "${candidates[@]}"; do
    if [ -x "$INSTALL_DIR/$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

check_binaries() {
  if BIN_NAME=$(find_carla_binary); then
    log "Found $BIN_NAME"
  else
    err "CARLA launch script not found under $INSTALL_DIR (looked for CarlaUE5.sh/CarlaUE4.sh/CarlaUnreal.sh)"
  fi
}

main() {
  log "Preparing CARLA $CARLA_VERSION in $INSTALL_DIR"
  ensure_tarball_valid
  unpack_tarball
  check_binaries
  log "Done"
}

main "$@"
