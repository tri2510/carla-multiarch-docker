#!/bin/bash
# Quick Start Script for CARLA Multi-Arch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "CARLA Multi-Arch Quick Start"
echo "========================================="
echo ""

# Detect platform
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    PLATFORM="linux/amd64"
    echo -e "${GREEN}Detected platform: x86_64${NC}"
elif [ "$ARCH" = "aarch64" ]; then
    PLATFORM="linux/arm64"
    echo -e "${GREEN}Detected platform: ARM64 (Jetson)${NC}"

    # Check if Jetson
    if [ -f /etc/nv_tegra_release ]; then
        echo -e "${BLUE}Jetson device detected!${NC}"
        cat /etc/nv_tegra_release
    fi
else
    echo -e "${YELLOW}Warning: Unknown architecture: $ARCH${NC}"
    PLATFORM="linux/amd64"
fi

echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    echo "Install from: https://docs.docker.com/engine/install/"
    exit 1
fi
echo "  ✓ Docker installed"

# Docker Compose
if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not installed"
    echo "Install from: https://docs.docker.com/compose/install/"
    exit 1
fi
echo "  ✓ Docker Compose installed"

# NVIDIA Docker Runtime (for GPU support)
if docker info 2>/dev/null | grep -q nvidia; then
    echo "  ✓ NVIDIA Docker Runtime available"
elif [ -f /etc/nv_tegra_release ]; then
    echo "  ✓ Jetson NVIDIA Runtime available"
else
    echo -e "${YELLOW}  ! NVIDIA Docker Runtime not detected${NC}"
    echo "    GPU acceleration may not work"
    echo "    Install from: https://github.com/NVIDIA/nvidia-docker"
fi

echo ""

# Setup environment
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.example .env

    # Set platform in .env
    if [ "$PLATFORM" = "linux/arm64" ]; then
        sed -i 's/TARGETPLATFORM=linux\/amd64/TARGETPLATFORM=linux\/arm64/' .env
        sed -i 's/CARLA_QUALITY=Epic/CARLA_QUALITY=Medium/' .env
        sed -i 's/CARLA_RES_X=1920/CARLA_RES_X=1280/' .env
        sed -i 's/CARLA_RES_Y=1080/CARLA_RES_Y=720/' .env
        echo "  ✓ .env configured for Jetson ARM64"
    else
        echo "  ✓ .env configured for x86_64"
    fi
else
    echo "  ✓ .env file already exists"
fi

# Setup display
echo ""
echo "Setting up display..."
./scripts/setup-display.sh

# Setup controller (optional)
echo ""
read -p "Do you want to setup Logitech wheel controller? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/setup-controller.sh
fi

# Build option
echo ""
echo "========================================="
echo "Build Options"
echo "========================================="
echo "1. Build locally (recommended for first time)"
echo "2. Use pre-built image (if available)"
echo "3. Skip build (already built)"
echo ""
read -p "Select option [1-3]: " -n 1 -r BUILD_OPTION
echo ""

case $BUILD_OPTION in
    1)
        echo "Building Docker image for $PLATFORM..."
        echo "This may take 15-30 minutes depending on your internet connection"
        echo ""
        ./build.sh --platform "$PLATFORM"
        ;;
    2)
        echo "Pulling pre-built image..."
        docker pull carla-multiarch:latest || echo "Warning: Could not pull image, may need to build locally"
        ;;
    3)
        echo "Skipping build..."
        ;;
    *)
        echo "Invalid option, skipping build"
        ;;
esac

# Start CARLA
echo ""
echo "========================================="
echo "Starting CARLA"
echo "========================================="
echo ""
read -p "Start CARLA now? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Starting CARLA with docker compose..."
    echo ""

    docker compose up -d

    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}CARLA is starting!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "Monitor logs with:"
    echo "  docker compose logs -f carla"
    echo ""
    echo "Open CARLA configuration helper:"
    echo "  docker compose exec carla python3 /home/carla/scripts/carla-config.py"
    echo ""
    echo "Test manual control with wheel:"
    echo "  docker compose exec carla python3 /home/carla/scripts/manual_control_wheel.py"
    echo ""
    echo "Stop CARLA:"
    echo "  docker compose down"
    echo ""
else
    echo ""
    echo "To start CARLA later, run:"
    echo "  docker compose up -d"
    echo ""
fi

echo "========================================="
echo "Quick Start Complete!"
echo "========================================="
