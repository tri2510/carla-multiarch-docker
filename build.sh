#!/bin/bash
# Multi-architecture Docker build script for CARLA
# Supports x86_64 and ARM64 (Jetson Orin)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="${IMAGE_NAME:-carla-multiarch}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
PUSH="${PUSH:-false}"

# Display banner
echo "========================================="
echo "CARLA Multi-Architecture Docker Build"
echo "========================================="
echo ""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORMS="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --platform PLATFORMS  Target platforms (default: linux/amd64,linux/arm64)"
            echo "  --tag TAG            Image tag (default: latest)"
            echo "  --push               Push to registry after build"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Build for both x86 and ARM"
            echo "  $0 --platform linux/amd64             # Build for x86 only"
            echo "  $0 --platform linux/arm64             # Build for ARM only (Jetson)"
            echo "  $0 --tag v1.0 --push                  # Build and push with tag"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check Docker Buildx
if ! docker buildx version &> /dev/null; then
    echo -e "${RED}Error: Docker Buildx is not available${NC}"
    echo "Install with: docker buildx install"
    exit 1
fi

# Setup buildx builder
BUILDER_NAME="carla-multiarch-builder"

if ! docker buildx inspect "$BUILDER_NAME" &> /dev/null; then
    echo -e "${YELLOW}Creating buildx builder: $BUILDER_NAME${NC}"
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
else
    echo -e "${GREEN}Using existing builder: $BUILDER_NAME${NC}"
fi

docker buildx use "$BUILDER_NAME"

echo ""
echo "Build Configuration:"
echo "  Image: $IMAGE_NAME:$IMAGE_TAG"
echo "  Platforms: $PLATFORMS"
echo "  Push: $PUSH"
echo ""

# Build command
BUILD_CMD="docker buildx build"
BUILD_CMD="$BUILD_CMD --builder $BUILDER_NAME"
BUILD_CMD="$BUILD_CMD --platform $PLATFORMS"
BUILD_CMD="$BUILD_CMD --tag $IMAGE_NAME:$IMAGE_TAG"

if [ "$PUSH" = true ]; then
    BUILD_CMD="$BUILD_CMD --push"
else
    BUILD_CMD="$BUILD_CMD --load"
fi

BUILD_CMD="$BUILD_CMD --progress=plain"
BUILD_CMD="$BUILD_CMD ."

echo -e "${GREEN}Starting build...${NC}"
echo "Command: $BUILD_CMD"
echo ""

# Execute build
if eval "$BUILD_CMD"; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Build completed successfully!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "Platforms: $PLATFORMS"

    if [ "$PUSH" = false ]; then
        echo ""
        echo "To run the image:"
        echo "  docker compose up"
    fi
else
    echo ""
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}Build failed!${NC}"
    echo -e "${RED}=========================================${NC}"
    exit 1
fi
