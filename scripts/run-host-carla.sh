#!/usr/bin/env bash
# Launch the locally unpacked CARLA simulator without Docker for quick testing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
LOCAL_CARLA_DIR="${LOCAL_CARLA_DIR:-$PROJECT_ROOT/local_carla}"
CARLA_VERSION="${CARLA_VERSION:-0.9.15}"

usage() {
  cat <<'USAGE'
Usage: scripts/run-host-carla.sh [options] [-- extra Unreal args]

Options:
  -q, --quality LEVEL      Low|Medium|High|Epic (default from .env or Epic)
  -r, --resolution WxH     Resolution override (e.g. 1920x1080)
      --rpc-port PORT      RPC port (default 2000)
      --stream-port PORT   Streaming port (default 2001)
      --offscreen          Enable off-screen rendering
      --onscreen           Disable off-screen rendering
      --opengl             Force OpenGL renderer
      --vulkan             Force Vulkan renderer
      --benchmark          Enable UE benchmark mode at 30 FPS
      --carla-dir PATH     Alternate CARLA install directory
      --env-file FILE      Source env file before running
      --preset NAME        Apply a preset (safe)
  -h, --help               Show this help

Any arguments after "--" are passed directly to CarlaUE{4,5}.sh.
USAGE
}

error() { printf '[run-host-carla][ERROR] %s\n' "$*" >&2; exit 1; }
info() { printf '[run-host-carla] %s\n' "$*"; }

source_env() {
  if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    set -a; source "$ENV_FILE"; set +a
  fi
}

LOCAL_ARGS=()
EXTRA_ARGS=()
PARSING=true
PRESET_SAFE=false

while [[ $# -gt 0 ]]; do
  if $PARSING; then
    case "$1" in
      -q|--quality)
        [[ $# -lt 2 ]] && error "--quality needs a value"
        LOCAL_ARGS+=("CARLA_QUALITY=$2")
        shift;;
      -r|--resolution)
        [[ $# -lt 2 ]] && error "--resolution needs WxH"
        if [[ "$2" =~ ^([0-9]+)x([0-9]+)$ ]]; then
          LOCAL_ARGS+=("CARLA_RES_X=${BASH_REMATCH[1]}")
          LOCAL_ARGS+=("CARLA_RES_Y=${BASH_REMATCH[2]}")
        else
          error "Resolution must be WxH"
        fi
        shift;;
      --rpc-port)
        [[ $# -lt 2 ]] && error "--rpc-port needs a value"
        LOCAL_ARGS+=("CARLA_PORT=$2")
        shift;;
      --stream-port)
        [[ $# -lt 2 ]] && error "--stream-port needs a value"
        LOCAL_ARGS+=("CARLA_STREAMING_PORT=$2")
        shift;;
      --offscreen)
        LOCAL_ARGS+=("CARLA_OFFSCREEN=true");;
      --onscreen)
        LOCAL_ARGS+=("CARLA_OFFSCREEN=false");;
      --opengl)
        LOCAL_ARGS+=("CARLA_OPENGL=true");;
      --vulkan)
        LOCAL_ARGS+=("CARLA_OPENGL=false");;
      --benchmark)
        LOCAL_ARGS+=("CARLA_BENCHMARK=true");;
      --carla-dir)
        [[ $# -lt 2 ]] && error "--carla-dir needs a path"
        LOCAL_CARLA_DIR="$2"
        shift;;
      --env-file)
        [[ $# -lt 2 ]] && error "--env-file needs a path"
        ENV_FILE="$2"
        shift;;
      --preset)
        [[ $# -lt 2 ]] && error "--preset requires a value"
        case "$2" in
          safe|SAFE)
            PRESET_SAFE=true
            ;;
          *)
            error "Unknown preset $2"
            ;;
        esac
        shift;;
      -h|--help)
        usage; exit 0;;
      --)
        PARSING=false;;
      *)
        error "Unknown option $1";;
    esac
  else
    EXTRA_ARGS+=("$1")
  fi
  shift || true
done

if command -v xhost >/dev/null 2>&1; then
  xhost +local:"$USER" >/dev/null 2>&1 || true
fi

export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json

source_env
for kv in "${LOCAL_ARGS[@]}"; do
  export "$kv"
done

if [ -f "$LOCAL_CARLA_DIR/.carla-version" ]; then
  CARLA_VERSION="$(<"$LOCAL_CARLA_DIR/.carla-version")"
fi

if $PRESET_SAFE; then
  CARLA_QUALITY="Medium"
  CARLA_RES_X="1280"
  CARLA_RES_Y="720"
  CARLA_OFFSCREEN="false"
  CARLA_OPENGL="true"
fi

CARLA_QUALITY="${CARLA_QUALITY:-Epic}"
CARLA_RES_X="${CARLA_RES_X:-1920}"
CARLA_RES_Y="${CARLA_RES_Y:-1080}"
CARLA_PORT="${CARLA_PORT:-2000}"
CARLA_STREAMING_PORT="${CARLA_STREAMING_PORT:-2001}"
CARLA_OFFSCREEN="${CARLA_OFFSCREEN:-false}"
CARLA_OPENGL="${CARLA_OPENGL:-false}"
CARLA_BENCHMARK="${CARLA_BENCHMARK:-false}"

[ -d "$LOCAL_CARLA_DIR" ] || error "Run scripts/setup-local-carla.sh first (missing $LOCAL_CARLA_DIR)"

CARLA_LIB_DIRS=()
for libdir in \
  "$LOCAL_CARLA_DIR/CarlaUnreal/Binaries/Linux" \
  "$LOCAL_CARLA_DIR/CarlaUE5/Binaries/Linux" \
  "$LOCAL_CARLA_DIR/CarlaUE4/Binaries/Linux" \
  "$LOCAL_CARLA_DIR/Engine/Binaries/Linux"; do
  [ -d "$libdir" ] && CARLA_LIB_DIRS+=("$libdir")
done

if [ ${#CARLA_LIB_DIRS[@]} -gt 0 ]; then
  LIB_JOIN=$(IFS=:; echo "${CARLA_LIB_DIRS[*]}")
  if [ -n "${LD_LIBRARY_PATH:-}" ]; then
    export LD_LIBRARY_PATH="$LIB_JOIN:$LD_LIBRARY_PATH"
  else
    export LD_LIBRARY_PATH="$LIB_JOIN"
  fi
fi

CARLA_CMD=""
for candidate in CarlaUE5.sh CarlaUE4.sh CarlaUnreal.sh; do
  if [ -x "$LOCAL_CARLA_DIR/$candidate" ]; then
    CARLA_CMD="$LOCAL_CARLA_DIR/$candidate"
    break
  fi
done
[ -n "$CARLA_CMD" ] || error "Could not find CarlaUE5.sh, CarlaUE4.sh, or CarlaUnreal.sh under $LOCAL_CARLA_DIR"

if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  export SDL_VIDEODRIVER=wayland
elif [ -n "${DISPLAY:-}" ]; then
  export SDL_VIDEODRIVER=x11
else
  export DISPLAY=:0
  export SDL_VIDEODRIVER=x11
fi

CARLA_ARGS=()
[[ "$CARLA_OFFSCREEN" == "true" ]] && CARLA_ARGS+=("-RenderOffScreen")
[[ "$CARLA_OPENGL" == "true" ]] && CARLA_ARGS+=("-opengl")
[[ "$CARLA_BENCHMARK" == "true" ]] && CARLA_ARGS+=("-benchmark" "-fps=30")
CARLA_ARGS+=("-quality-level=$CARLA_QUALITY")
CARLA_ARGS+=("-ResX=$CARLA_RES_X" "-ResY=$CARLA_RES_Y")
CARLA_ARGS+=("-carla-rpc-port=$CARLA_PORT" "-carla-streaming-port=$CARLA_STREAMING_PORT")
CARLA_ARGS+=("-prefernvidia")
if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
  CARLA_ARGS+=("${EXTRA_ARGS[@]}")
fi

info "Using CARLA install: $LOCAL_CARLA_DIR (version $CARLA_VERSION)"
info "Command: $CARLA_CMD ${CARLA_ARGS[*]}"
info "Press Ctrl+C to stop the simulator"

cd "$LOCAL_CARLA_DIR"
exec "$CARLA_CMD" "${CARLA_ARGS[@]}"
