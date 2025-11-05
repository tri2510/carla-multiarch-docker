#!/usr/bin/env bash
# Helper wrapper to run the CARLA container locally with convenient overrides.
# Inspired by the simplified flow in 49_HPC_Farm/projects/carla-streaming but
# tailored for this repo (no streaming stack management).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
SERVICE_NAME="carla"
ENV_FILE="$PROJECT_ROOT/.env"
IMAGE_NAME="${IMAGE_NAME:-carla-multiarch:latest}"

ACTION="start"
DETACH=true
BUILD=false
FOLLOW_LOGS=false
AUTO_IMAGE_CHECK=true

QUALITY_OVERRIDE=""
RES_X_OVERRIDE=""
RES_Y_OVERRIDE=""
OFFSCREEN_OVERRIDE=""
OPENGL_OVERRIDE=""
RPC_PORT_OVERRIDE=""
STREAM_PORT_OVERRIDE=""
DISPLAY_OVERRIDE=""
GPU_OVERRIDE=""
PRIVILEGED_OVERRIDE=""
CONTROLLER_OVERRIDE=""
FORCE_FEEDBACK_OVERRIDE=""
SDL_OVERRIDE=""

print_usage() {
  cat <<'USAGE'
Usage: scripts/run-local-carla.sh [options]

Convenience wrapper around "docker compose" for quickly launching the CARLA
simulator with ad-hoc overrides (similar to the direct-run helper in
carla-streaming).

Actions (default: start):
  --start              Start the CARLA container (default action)
  --stop               Stop the CARLA container
  --down               docker compose down (removes container)
  --restart            Stop then start the CARLA container
  --status             Show docker compose ps for the CARLA service
  --logs               Tail the CARLA logs (implies --start is not run)

Common overrides:
  -q, --quality LEVEL          Set CARLA_QUALITY (Low|Medium|High|Epic)
  -r, --resolution WxH         Set CARLA_RES_X / CARLA_RES_Y (e.g. 1920x1080)
      --rpc-port PORT          Override CARLA_PORT (default 2000)
      --stream-port PORT       Override CARLA_STREAMING_PORT (default 2001)
      --offscreen / --onscreen Toggle CARLA_OFFSCREEN flag
      --opengl / --vulkan      Toggle CARLA_OPENGL flag
      --display VALUE          Override DISPLAY env for docker compose
      --gpu VALUE              Set NVIDIA_VISIBLE_DEVICES value
      --controller TYPE        Override CONTROLLER_TYPE (g27/g29/etc.)
      --force-feedback BOOL    Override FORCE_FEEDBACK (true/false)
      --privileged BOOL        Override DOCKER_PRIVILEGED (true/false)
      --sdl-driver VALUE       Set SDL_VIDEODRIVER (x11/wayland)

Execution control:
      --compose-file PATH      Use a different docker compose file
      --service NAME           Override service name (default: carla)
      --image NAME             Override image name (default: carla-multiarch:latest)
      --build                  Run docker compose build before start
      --no-auto-build          Skip automatic image existence check
  -a, --attach                 Run in the foreground (no -d)
  -d, --detach                 Run in detached mode (default)
      --env-file PATH          Source an alternative .env before running
  -h, --help                   Show this help text

Examples:
  scripts/run-local-carla.sh --quality High --resolution 2560x1440 --offscreen
  scripts/run-local-carla.sh --start --attach --opengl
  scripts/run-local-carla.sh --stop
USAGE
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

info() {
  echo "[INFO] $1"
}

parse_resolution() {
  local res="$1"
  if [[ ! $res =~ ^([0-9]+)x([0-9]+)$ ]]; then
    error "Resolution must be in WxH format (e.g. 1920x1080)"
  fi
  RES_X_OVERRIDE="${BASH_REMATCH[1]}"
  RES_Y_OVERRIDE="${BASH_REMATCH[2]}"
}

normalize_bool() {
  local value="$1"
  case "${value,,}" in
    true|1|yes|on) echo "true" ;;
    false|0|no|off) echo "false" ;;
    *) error "Invalid boolean value: $value" ;;
  esac
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --start)
      ACTION="start"
      ;;
    --stop)
      ACTION="stop"
      ;;
    --down)
      ACTION="down"
      ;;
    --restart)
      ACTION="restart"
      ;;
    --status)
      ACTION="status"
      ;;
    --logs)
      ACTION="logs"
      ;;
    --build)
      BUILD=true
      ;;
    -a|--attach)
      DETACH=false
      ;;
    -d|--detach)
      DETACH=true
      ;;
    -q|--quality)
      [[ $# -lt 2 ]] && error "--quality requires a value"
      QUALITY_OVERRIDE="$2"
      shift
      ;;
    -r|--resolution)
      [[ $# -lt 2 ]] && error "--resolution requires a value"
      parse_resolution "$2"
      shift
      ;;
    --rpc-port)
      [[ $# -lt 2 ]] && error "--rpc-port requires a value"
      RPC_PORT_OVERRIDE="$2"
      shift
      ;;
    --stream-port)
      [[ $# -lt 2 ]] && error "--stream-port requires a value"
      STREAM_PORT_OVERRIDE="$2"
      shift
      ;;
    --offscreen)
      OFFSCREEN_OVERRIDE="true"
      ;;
    --onscreen)
      OFFSCREEN_OVERRIDE="false"
      ;;
    --opengl)
      OPENGL_OVERRIDE="true"
      ;;
    --vulkan)
      OPENGL_OVERRIDE="false"
      ;;
    --display)
      [[ $# -lt 2 ]] && error "--display requires a value"
      DISPLAY_OVERRIDE="$2"
      shift
      ;;
    --gpu)
      [[ $# -lt 2 ]] && error "--gpu requires a value"
      GPU_OVERRIDE="$2"
      shift
      ;;
    --controller)
      [[ $# -lt 2 ]] && error "--controller requires a value"
      CONTROLLER_OVERRIDE="$2"
      shift
      ;;
    --force-feedback)
      [[ $# -lt 2 ]] && error "--force-feedback requires a value"
      FORCE_FEEDBACK_OVERRIDE="$(normalize_bool "$2")"
      shift
      ;;
    --privileged)
      [[ $# -lt 2 ]] && error "--privileged requires a value"
      PRIVILEGED_OVERRIDE="$(normalize_bool "$2")"
      shift
      ;;
    --sdl-driver)
      [[ $# -lt 2 ]] && error "--sdl-driver requires a value"
      SDL_OVERRIDE="$2"
      shift
      ;;
    --compose-file)
      [[ $# -lt 2 ]] && error "--compose-file requires a path"
      COMPOSE_FILE="$2"
      shift
      ;;
    --service)
      [[ $# -lt 2 ]] && error "--service requires a name"
      SERVICE_NAME="$2"
      shift
      ;;
    --image)
      [[ $# -lt 2 ]] && error "--image requires a name"
      IMAGE_NAME="$2"
      shift
      ;;
    --env-file)
      [[ $# -lt 2 ]] && error "--env-file requires a path"
      ENV_FILE="$2"
      shift
      ;;
    --no-auto-build)
      AUTO_IMAGE_CHECK=false
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
  shift
done

if [[ ! -f "$COMPOSE_FILE" ]]; then
  error "Compose file not found: $COMPOSE_FILE"
fi

if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  info "Loaded environment overrides from $ENV_FILE"
fi

declare -a ENV_OVERRIDES=()
add_override() {
  local key="$1"
  local value="$2"
  ENV_OVERRIDES+=("$key=$value")
}

[[ -n "$QUALITY_OVERRIDE" ]] && add_override CARLA_QUALITY "$QUALITY_OVERRIDE"
[[ -n "$RES_X_OVERRIDE" ]] && add_override CARLA_RES_X "$RES_X_OVERRIDE"
[[ -n "$RES_Y_OVERRIDE" ]] && add_override CARLA_RES_Y "$RES_Y_OVERRIDE"
[[ -n "$OFFSCREEN_OVERRIDE" ]] && add_override CARLA_OFFSCREEN "$OFFSCREEN_OVERRIDE"
[[ -n "$OPENGL_OVERRIDE" ]] && add_override CARLA_OPENGL "$OPENGL_OVERRIDE"
[[ -n "$RPC_PORT_OVERRIDE" ]] && add_override CARLA_PORT "$RPC_PORT_OVERRIDE"
[[ -n "$STREAM_PORT_OVERRIDE" ]] && add_override CARLA_STREAMING_PORT "$STREAM_PORT_OVERRIDE"
[[ -n "$DISPLAY_OVERRIDE" ]] && add_override DISPLAY "$DISPLAY_OVERRIDE"
[[ -n "$GPU_OVERRIDE" ]] && add_override NVIDIA_VISIBLE_DEVICES "$GPU_OVERRIDE"
[[ -n "$PRIVILEGED_OVERRIDE" ]] && add_override DOCKER_PRIVILEGED "$PRIVILEGED_OVERRIDE"
[[ -n "$CONTROLLER_OVERRIDE" ]] && add_override CONTROLLER_TYPE "$CONTROLLER_OVERRIDE"
[[ -n "$FORCE_FEEDBACK_OVERRIDE" ]] && add_override FORCE_FEEDBACK "$FORCE_FEEDBACK_OVERRIDE"
[[ -n "$SDL_OVERRIDE" ]] && add_override SDL_VIDEODRIVER "$SDL_OVERRIDE"

run_compose() {
  local subcommand="$1"
  shift
  local cmd=(docker compose -f "$COMPOSE_FILE" "$subcommand" "$@")
  if [[ ${#ENV_OVERRIDES[@]} -gt 0 ]]; then
    env "${ENV_OVERRIDES[@]}" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
}

image_exists() {
  docker image inspect "$IMAGE_NAME" >/dev/null 2>&1
}

start_service() {
  local up_args=()

  if [[ "$BUILD" == true ]]; then
    info "Building $SERVICE_NAME image..."
    run_compose build "$SERVICE_NAME"
  elif [[ "$AUTO_IMAGE_CHECK" == true ]]; then
    if image_exists; then
      info "Image $IMAGE_NAME found locally; skipping build"
      up_args+=(--no-build)
    else
      info "Image $IMAGE_NAME not found; building before start"
      run_compose build "$SERVICE_NAME"
    fi
  fi

  if [[ "$DETACH" == true ]]; then
    up_args+=(-d)
  fi

  up_args+=("$SERVICE_NAME")

  info "Starting $SERVICE_NAME via docker compose"
  run_compose up "${up_args[@]}"
}

case "$ACTION" in
  start)
    start_service
    ;;
  stop)
    info "Stopping $SERVICE_NAME"
    run_compose stop "$SERVICE_NAME"
    ;;
  down)
    info "Running docker compose down"
    run_compose down
    ;;
  restart)
    info "Restarting $SERVICE_NAME"
    run_compose stop "$SERVICE_NAME" || true
    start_service
    ;;
  status)
    run_compose ps "$SERVICE_NAME"
    ;;
  logs)
    run_compose logs -f "$SERVICE_NAME"
    ;;
  *)
    error "Unsupported action: $ACTION"
    ;;
esac
