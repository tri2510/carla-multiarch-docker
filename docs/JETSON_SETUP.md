# CARLA on Jetson Orin - Complete Setup Guide

This guide covers everything needed to run CARLA on NVIDIA Jetson Orin with direct display support.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Jetson Setup](#initial-jetson-setup)
3. [Docker Setup](#docker-setup)
4. [Display Configuration](#display-configuration)
5. [Building CARLA](#building-carla)
6. [Running CARLA](#running-carla)
7. [Performance Optimization](#performance-optimization)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware
- **NVIDIA Jetson Orin** (AGX Orin, Orin NX, or Orin Nano)
- **RAM**: Minimum 16GB (32GB recommended)
- **Storage**: Minimum 128GB (NVMe SSD recommended)
- **Display**: HDMI/DP connected monitor
- **Controller**: Logitech G27/G29/G920 (optional)

### Software
- **JetPack 5.0+** (Ubuntu 20.04 based)
- **CUDA 11.4+**
- **Docker 20.10+**
- **NVIDIA Container Runtime**

## Initial Jetson Setup

### 1. Check JetPack Version

```bash
# Check Jetson info
cat /etc/nv_tegra_release

# Should show something like:
# R35 (release), REVISION: 1.0, GCID: 12345678, BOARD: t186ref
```

### 2. Update System

```bash
sudo apt update
sudo apt upgrade -y
```

### 3. Set Power Mode to Maximum Performance

```bash
# Show available power modes
sudo nvpmodel -q

# Set to maximum performance (mode 0)
sudo nvpmodel -m 0

# Enable max clocks
sudo jetson_clocks

# Check current status
sudo tegrastats
```

### 4. Install Essential Tools

```bash
sudo apt install -y \
    git \
    curl \
    wget \
    vim \
    htop \
    build-essential \
    python3-pip \
    can-utils \
    usbutils
```

## Docker Setup

### 1. Install Docker

```bash
# Remove old versions
sudo apt remove docker docker-engine docker.io containerd runc

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
```

### 2. Install NVIDIA Container Runtime

```bash
# The runtime should come with JetPack, but verify
docker info | grep -i runtime

# Should show nvidia runtime
# If not, install:
sudo apt install nvidia-container-runtime

# Configure Docker to use nvidia runtime by default
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "default-runtime": "nvidia"
}
EOF

# Restart Docker
sudo systemctl restart docker

# Test GPU access
docker run --rm --runtime=nvidia nvidia/cuda:11.4.3-base-ubuntu20.04 nvidia-smi
```

### 3. Install Docker Compose V2

```bash
# Install Docker Compose plugin
sudo apt install docker-compose-plugin

# Verify installation
docker compose version
```

## Display Configuration

### 1. Check Current Display

```bash
# Check display manager
systemctl status gdm3
# or
systemctl status lightdm

# Check display server (X11 vs Wayland)
echo $XDG_SESSION_TYPE
echo $WAYLAND_DISPLAY
echo $DISPLAY
```

### 2. Switch to X11 (Recommended for CARLA)

If using Wayland, switch to X11:

```bash
# Edit GDM3 config
sudo nano /etc/gdm3/custom.conf

# Uncomment this line:
WaylandEnable=false

# Save and restart display manager
sudo systemctl restart gdm3
```

### 3. Configure X11 for Docker

```bash
# Allow Docker containers to access display
xhost +local:docker

# Make permanent by adding to ~/.bashrc
echo "xhost +local:docker" >> ~/.bashrc

# Verify X11 is working
xdpyinfo | head

# Check OpenGL
glxinfo | grep "OpenGL version"
```

### 4. Test Display with Docker

```bash
# Simple X11 test
docker run --rm \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    --runtime=nvidia \
    jess/glxgears

# Should open a window with spinning gears
```

## Building CARLA

### 1. Clone This Repository

```bash
cd ~/01_SDV
git clone <this-repo> 72_carla_arm
cd 72_carla_arm
```

### 2. Setup Environment

```bash
# Copy environment template
cp .env.example .env

# Edit for Jetson
nano .env

# Set these values:
TARGETPLATFORM=linux/arm64
CARLA_QUALITY=Medium
CARLA_RES_X=1280
CARLA_RES_Y=720
DOCKER_CPUS=8
DOCKER_MEMORY=16G
DOCKER_RUNTIME=nvidia
```

### 3. Run Setup Scripts

```bash
# Setup display
./container_scripts/setup-display.sh

# Setup controller (if you have Logitech wheel)
./container_scripts/setup-controller.sh
```

### 4. Build Docker Image

**Option A: Use Quick Start (Recommended)**

```bash
./quickstart.sh
```

**Option B: Manual Build**

```bash
# Build for ARM64
./build.sh --platform linux/arm64

# This will take 15-30 minutes for downloading
# Building from source would take 4-6 hours
```

## Running CARLA

### 1. Start CARLA

```bash
# Start in detached mode
docker compose up -d

# Watch logs
docker compose logs -f carla

# Wait for "Server listening on port 2000" message
```

### 2. Test with Python API

```bash
# Enter container
docker compose exec carla bash

# Test connection
python3 << EOF
import carla
client = carla.Client('localhost', 2000)
client.set_timeout(10.0)
world = client.get_world()
print(f"Connected! Map: {world.get_map().name}")
EOF
```

### 3. Manual Control with Wheel

```bash
# Connect Logitech wheel to Jetson USB port

# Start manual control
docker compose exec carla python3 /home/carla/scripts/manual_control_wheel.py

# Or use CARLA's example
docker compose exec carla python3 /home/carla/PythonAPI/examples/manual_control.py
```

### 4. Configuration Helper

```bash
# Interactive configuration
docker compose exec carla python3 /home/carla/scripts/carla-config.py --interactive

# Apply Jetson preset
docker compose exec carla python3 /home/carla/scripts/carla-config.py --presets
# Select option 4 (Jetson Optimized)
```

## Performance Optimization

### 1. Graphics Settings

**Low-End Jetson (Orin Nano, NX):**
```bash
# In .env
CARLA_QUALITY=Low
CARLA_RES_X=1280
CARLA_RES_Y=720
```

**High-End Jetson (Orin AGX):**
```bash
# In .env
CARLA_QUALITY=Medium
CARLA_RES_X=1920
CARLA_RES_Y=1080
```

### 2. Reduce Traffic Density

```python
# In your Python script
import carla

client = carla.Client('localhost', 2000)
world = client.get_world()

# Spawn fewer vehicles (max 30-50 on Jetson)
traffic_manager = client.get_trafficmanager(8000)
traffic_manager.set_global_distance_to_leading_vehicle(2.5)

# Generate light traffic
# Use generate_traffic.py with -n 30 instead of default
```

### 3. Enable Synchronous Mode

```python
# Better performance and deterministic simulation
settings = world.get_settings()
settings.synchronous_mode = True
settings.fixed_delta_seconds = 0.05  # 20 FPS
world.apply_settings(settings)
```

### 4. Monitor Performance

```bash
# In one terminal, monitor Jetson stats
sudo tegrastats

# In another, monitor Docker container
docker stats carla-simulator

# Check GPU usage
nvidia-smi -l 1
```

### 5. Optimize Power Settings

```bash
# Show current power mode
sudo nvpmodel -q

# Available modes (AGX Orin):
# - Mode 0: MAXN (maximum performance)
# - Mode 1: 50W
# - Mode 2: 30W
# - Mode 3: 15W

# Set maximum performance
sudo nvpmodel -m 0
sudo jetson_clocks

# Or create a systemd service to apply on boot
sudo tee /etc/systemd/system/jetson-max-perf.service > /dev/null <<EOF
[Unit]
Description=Jetson Maximum Performance

[Service]
Type=oneshot
ExecStart=/usr/sbin/nvpmodel -m 0
ExecStart=/usr/bin/jetson_clocks

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable jetson-max-perf
sudo systemctl start jetson-max-perf
```

## Troubleshooting

### Display Not Working

**Check X11 connection:**
```bash
# From host
xdpyinfo

# Should show display info
# If not, X11 is not running properly
```

**Reset X server:**
```bash
sudo systemctl restart gdm3
xhost +local:docker
```

**Check container display:**
```bash
docker compose exec carla bash
echo $DISPLAY
xdpyinfo
```

### Low FPS / Performance

**Check GPU usage:**
```bash
# Should see GPU utilization
sudo tegrastats

# If GPU is idle, CARLA might not be using it
```

**Reduce quality:**
```bash
# Edit .env
CARLA_QUALITY=Low
CARLA_RES_X=800
CARLA_RES_Y=600

# Restart container
docker compose restart carla
```

### Out of Memory

**Monitor memory:**
```bash
# Check memory usage
free -h
sudo tegrastats

# If swapping heavily, reduce memory in .env
DOCKER_MEMORY=12G

# Or reduce number of vehicles/actors
```

**Enable zram:**
```bash
# Jetson usually has zram enabled by default
# Check with:
zramctl

# If not enabled, create swap file
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Controller Not Detected

**Check USB connection:**
```bash
# List USB devices
lsusb | grep -i logitech

# Check input devices
ls -la /dev/input/

# Test joystick
jstest /dev/input/js0
```

**Fix permissions:**
```bash
# Add user to input group
sudo usermod -aG input $USER

# Or run with privileged mode
# Edit docker-compose.yml:
# privileged: true
```

### Docker Build Fails

**Insufficient disk space:**
```bash
# Check space
df -h

# Clean up Docker
docker system prune -a

# Need at least 50GB free for build
```

**Memory issues during build:**
```bash
# Reduce parallel builds
export MAKEFLAGS="-j2"  # Use only 2 cores

# Or build with swap enabled
```

## Best Practices

### 1. Use SSD Storage

For best performance, install Docker images and containers on NVMe SSD:

```bash
# Move Docker data directory to NVMe
sudo systemctl stop docker
sudo mv /var/lib/docker /mnt/nvme/docker
sudo ln -s /mnt/nvme/docker /var/lib/docker
sudo systemctl start docker
```

### 2. Auto-Start CARLA on Boot

```bash
# Enable docker compose service
sudo tee /etc/systemd/system/carla.service > /dev/null <<EOF
[Unit]
Description=CARLA Simulator
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/$USER/01_SDV/72_carla_arm
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable carla
sudo systemctl start carla
```

### 3. Regular Maintenance

```bash
# Weekly cleanup
docker system prune

# Check for updates
cd ~/01_SDV/72_carla_arm
git pull
./build.sh --platform linux/arm64

# Update system
sudo apt update && sudo apt upgrade
```

## Performance Benchmarks

Approximate FPS on different Jetson models:

| Model | Quality | Resolution | Vehicles | FPS |
|-------|---------|------------|----------|-----|
| Orin Nano | Low | 1280x720 | 20 | 25-30 |
| Orin NX | Medium | 1280x720 | 30 | 25-30 |
| Orin AGX | Medium | 1920x1080 | 50 | 30-40 |
| Orin AGX | High | 1920x1080 | 30 | 25-30 |

## Additional Resources

- [Jetson Orin Documentation](https://developer.nvidia.com/embedded/jetson-orin)
- [JetPack SDK](https://developer.nvidia.com/embedded/jetpack)
- [Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/archives/r35.1/DeveloperGuide/index.html)
- [CARLA on Edge Devices](https://carla.readthedocs.io/en/latest/adv_benchmarking/)

## Next Steps

After successful setup:

1. Explore CARLA Python API examples
2. Create custom scenarios
3. Integrate with ROS2 (via carla-ros-bridge)
4. Develop autonomous driving algorithms
5. Use CARLA for dataset generation

Happy simulating on Jetson! 🚗💨
