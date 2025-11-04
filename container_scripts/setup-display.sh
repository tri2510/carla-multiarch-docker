#!/bin/bash
# Display Setup Script for Jetson and x86

set -e

echo "========================================="
echo "Display Setup for CARLA"
echo "========================================="

# Detect platform
ARCH=$(uname -m)
IS_JETSON=false

if [ -f /etc/nv_tegra_release ]; then
    IS_JETSON=true
    echo "Platform: Jetson (ARM64)"
else
    echo "Platform: x86_64"
fi

# Allow Docker containers to connect to X server
echo "Allowing Docker to connect to display..."
xhost +local:docker

# Check if running on Wayland
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Wayland display detected: $WAYLAND_DISPLAY"
    echo "Setting up Wayland passthrough..."

    # Export Wayland socket
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        echo "Wayland socket found: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    else
        echo "Warning: Wayland socket not found"
    fi
fi

# Check X11 display
if [ -n "$DISPLAY" ]; then
    echo "X11 display: $DISPLAY"

    if command -v xdpyinfo &> /dev/null; then
        echo "Display info:"
        xdpyinfo | grep -A 2 "screen #0"
    fi
else
    echo "Setting DISPLAY=:0"
    export DISPLAY=:0
fi

# Jetson-specific setup
if [ "$IS_JETSON" = true ]; then
    echo ""
    echo "Jetson-specific setup:"

    # Check nvpmodel
    if command -v nvpmodel &> /dev/null; then
        echo "Current power mode:"
        sudo nvpmodel -q
    fi

    # Check jetson_clocks
    if command -v jetson_clocks &> /dev/null; then
        echo "Enabling maximum performance..."
        sudo jetson_clocks
    fi

    # Check display manager
    if systemctl is-active --quiet gdm3; then
        echo "Display manager: GDM3 (active)"
    elif systemctl is-active --quiet lightdm; then
        echo "Display manager: LightDM (active)"
    else
        echo "Warning: No display manager detected"
    fi
fi

# Test GPU access
echo ""
echo "GPU Information:"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
elif [ -f /sys/class/hwmon/hwmon0/name ]; then
    echo "Tegra SoC detected:"
    cat /sys/class/hwmon/hwmon*/name 2>/dev/null | head -n1
fi

# Check Vulkan support
echo ""
if command -v vulkaninfo &> /dev/null; then
    echo "Vulkan support: Available"
    vulkaninfo --summary 2>/dev/null | head -n 10 || echo "Vulkan info not available"
else
    echo "Vulkan support: Not installed"
fi

# Export environment
echo ""
echo "Environment variables for docker compose:"
echo "export DISPLAY=$DISPLAY"
echo "export XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}"

if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "export WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    echo "export XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
fi

echo ""
echo "========================================="
echo "Display setup complete!"
echo "You can now run: docker compose up"
echo "========================================="
