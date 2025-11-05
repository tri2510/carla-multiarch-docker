#!/bin/bash
# CARLA Startup Script - Multi-platform support

set -e

echo "========================================="
echo "CARLA Startup Script"
echo "========================================="

# Detect platform
ARCH=$(uname -m)
echo "Platform: $ARCH"

# Detect display server
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Display: Wayland detected ($WAYLAND_DISPLAY)"
    export SDL_VIDEODRIVER=wayland
elif [ -n "$DISPLAY" ]; then
    echo "Display: X11 detected ($DISPLAY)"
    export SDL_VIDEODRIVER=x11
else
    echo "Warning: No display detected, setting DISPLAY=:0"
    export DISPLAY=:0
    export SDL_VIDEODRIVER=x11
fi

# Test display connection
if command -v xdpyinfo &> /dev/null; then
    echo "Testing display connection..."
    if xdpyinfo &>/dev/null; then
        echo "Display connection: OK"
    else
        echo "Warning: Cannot connect to display server"
        echo "Make sure to run: xhost +local:docker"
    fi
fi

# Detect GPU
if [ -f /proc/driver/nvidia/version ]; then
    echo "NVIDIA GPU detected:"
    cat /proc/driver/nvidia/version | head -n1

    # Check if it's Jetson
    if [ -f /etc/nv_tegra_release ]; then
        echo "Jetson device detected:"
        cat /etc/nv_tegra_release
        export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
    fi
else
    echo "Warning: No NVIDIA GPU detected"
fi

# Setup input devices
echo "Setting up input devices..."
sudo chmod -R a+rw /dev/input/* 2>/dev/null || echo "Warning: Could not set input device permissions"

# List available input devices
if command -v ls /dev/input/ &> /dev/null; then
    echo "Available input devices:"
    ls -la /dev/input/
fi

# Load controller configuration if exists
if [ -f /home/carla/configs/controller.conf ]; then
    echo "Loading controller configuration..."
    source /home/carla/configs/controller.conf
fi

# Set CARLA parameters from environment or defaults
CARLA_QUALITY="${CARLA_QUALITY:-Epic}"
CARLA_RES_X="${CARLA_RES_X:-1920}"
CARLA_RES_Y="${CARLA_RES_Y:-1080}"
CARLA_PORT="${CARLA_PORT:-2000}"
CARLA_STREAMING_PORT="${CARLA_STREAMING_PORT:-2001}"
CARLA_OFFSCREEN="${CARLA_OFFSCREEN:-false}"
CARLA_BENCHMARK="${CARLA_BENCHMARK:-false}"
CARLA_OPENGL="${CARLA_OPENGL:-false}"

echo ""
echo "CARLA Configuration:"
echo "  Quality: $CARLA_QUALITY"
echo "  Resolution: ${CARLA_RES_X}x${CARLA_RES_Y}"
echo "  RPC Port: $CARLA_PORT"
echo "  Streaming Port: $CARLA_STREAMING_PORT"
echo "  Offscreen: $CARLA_OFFSCREEN"
echo "  OpenGL Mode: $CARLA_OPENGL"
echo ""

# Build CARLA command
CARLA_HOME="/home/carla"
CARLA_CMD=""

for candidate in CarlaUE5.sh CarlaUE4.sh CarlaUnreal.sh; do
    if [ -f "$CARLA_HOME/$candidate" ]; then
        CARLA_CMD="$CARLA_HOME/$candidate"
        echo "Detected CARLA launcher ($candidate)"
        break
    fi
done

if [ -z "$CARLA_CMD" ]; then
    echo "Error: Could not find CarlaUE5.sh, CarlaUE4.sh, or CarlaUnreal.sh in $CARLA_HOME" >&2
    exit 1
fi

CARLA_ARGS=""

if [ "$CARLA_OFFSCREEN" = "true" ]; then
    CARLA_ARGS="$CARLA_ARGS -RenderOffScreen"
fi

if [ "$CARLA_OPENGL" = "true" ]; then
    CARLA_ARGS="$CARLA_ARGS -opengl"
fi

if [ "$CARLA_BENCHMARK" = "true" ]; then
    CARLA_ARGS="$CARLA_ARGS -benchmark -fps=30"
fi

CARLA_ARGS="$CARLA_ARGS -quality-level=$CARLA_QUALITY"
CARLA_ARGS="$CARLA_ARGS -ResX=$CARLA_RES_X -ResY=$CARLA_RES_Y"
CARLA_ARGS="$CARLA_ARGS -carla-rpc-port=$CARLA_PORT"
CARLA_ARGS="$CARLA_ARGS -carla-streaming-port=$CARLA_STREAMING_PORT"
CARLA_ARGS="$CARLA_ARGS -prefernvidia"

cd "$CARLA_HOME"

echo "Starting CARLA with command:"
echo "$CARLA_CMD $CARLA_ARGS"
echo ""
echo "========================================="

# Start CARLA
exec "$CARLA_CMD" $CARLA_ARGS
