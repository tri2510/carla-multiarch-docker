# CARLA Multi-Architecture Docker

Plug-and-play CARLA simulator for x86_64 and ARM64 (Jetson Orin) with direct display support and Logitech wheel controller integration.

[![Build Multi-Arch Docker Images](https://github.com/tri2510/carla-multiarch-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/tri2510/carla-multiarch-docker/actions/workflows/docker-build.yml)
[![Release](https://github.com/tri2510/carla-multiarch-docker/actions/workflows/release.yml/badge.svg)](https://github.com/tri2510/carla-multiarch-docker/actions/workflows/release.yml)

## Features

- **Multi-Architecture**: Runs on x86_64 and ARM64 (Jetson Orin)
- **Direct Display**: Native X11/Wayland support (no remote desktop)
- **GPU Accelerated**: NVIDIA GPU support on both platforms
- **Controller Support**: Logitech G27/G29/G920 wheels out-of-the-box
- **Easy Configuration**: Interactive configuration helper
- **GitHub Actions**: Automated multi-arch builds

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose v2+
- NVIDIA GPU with drivers
- NVIDIA Container Toolkit

**For Jetson Orin:**
- JetPack 5.0+
- NVIDIA Container Runtime

### Using Docker Compose (Recommended)

```bash
# Clone repository
git clone https://github.com/tri2510/carla-multiarch-docker.git
cd carla-multiarch-docker

# Setup environment
cp .env.example .env
# Edit .env for your platform

# Allow Docker to access display
xhost +local:docker

# Start CARLA
docker compose up -d

# View logs
docker compose logs -f carla
```

### Using Pre-built Images

```bash
# Pull image from GitHub Container Registry
docker pull ghcr.io/tri2510/carla-multiarch-docker:latest

# Run with display and GPU support
docker run --rm -it \
  --runtime=nvidia \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /dev/input:/dev/input:rw \
  -p 2000:2000 \
  ghcr.io/tri2510/carla-multiarch-docker:latest
```

## Configuration

### Environment Variables

Edit `.env` file to configure CARLA:

```bash
# Display
DISPLAY=:0

# Platform (auto-detected)
TARGETPLATFORM=linux/amd64  # or linux/arm64

# Graphics Quality
CARLA_QUALITY=Epic          # Low, Medium, High, Epic
CARLA_RES_X=1920
CARLA_RES_Y=1080

# Ports
CARLA_PORT=2000
CARLA_STREAMING_PORT=2001

# Controller
CONTROLLER_TYPE=g29         # g27, g29, g920, driving_force_gt
FORCE_FEEDBACK=true
```

### Recommended Settings

**x86_64 Desktop (High-end GPU):**
```bash
CARLA_QUALITY=Epic
CARLA_RES_X=1920
CARLA_RES_Y=1080
```

**Jetson Orin AGX:**
```bash
CARLA_QUALITY=Medium
CARLA_RES_X=1280
CARLA_RES_Y=720
```

**Jetson Orin Nano/NX:**
```bash
CARLA_QUALITY=Low
CARLA_RES_X=1280
CARLA_RES_Y=720
```

## Usage Examples

### Manual Control with Wheel

```bash
# Start manual control with Logitech wheel
docker compose exec carla python3 /home/carla/scripts/manual_control_wheel.py
```

**Controls:**
- Steering Wheel → Steer
- Right Pedal → Throttle
- Middle Pedal → Brake
- Left Pedal → Clutch
- Button 6 → Reverse
- Button 7 → Handbrake

### Python API

```bash
# Enter container
docker compose exec carla bash

# Run examples
cd /home/carla/PythonAPI/examples

# Generate traffic
python3 generate_traffic.py -n 50

# Dynamic weather
python3 dynamic_weather.py
```

### Custom Script

```python
import carla

# Connect to CARLA
client = carla.Client('localhost', 2000)
client.set_timeout(10.0)
world = client.get_world()

# Spawn vehicle
blueprint_library = world.get_blueprint_library()
vehicle_bp = blueprint_library.filter('vehicle.tesla.model3')[0]
spawn_point = world.get_map().get_spawn_points()[0]
vehicle = world.spawn_actor(vehicle_bp, spawn_point)

print(f"Spawned {vehicle.type_id}")
```

## Jetson Orin Setup

### Initial Setup

```bash
# Set maximum performance mode
sudo nvpmodel -m 0
sudo jetson_clocks

# Verify GPU
nvidia-smi

# Check Jetson info
cat /etc/nv_tegra_release
```

### Display Configuration

For best results, use X11 instead of Wayland:

```bash
# Edit GDM3 config
sudo nano /etc/gdm3/custom.conf

# Uncomment:
# WaylandEnable=false

# Restart display manager
sudo systemctl restart gdm3
```

See [JETSON_SETUP.md](JETSON_SETUP.md) for detailed setup guide.

## Building from Source

### Local Build

```bash
# Build for current platform
./build.sh --platform linux/amd64

# Build for ARM64
./build.sh --platform linux/arm64

# Build for both platforms
./build.sh
```

### GitHub Actions

Images are automatically built on:
- Push to `main` or `develop` branches
- Pull requests
- Release tags (`v*.*.*`)

Built images are available at:
```
ghcr.io/tri2510/carla-multiarch-docker:latest
ghcr.io/tri2510/carla-multiarch-docker:v1.0.0
```

## Troubleshooting

### Display Issues

```bash
# Allow Docker to access display
xhost +local:docker

# Check display variable
echo $DISPLAY

# Verify X11 is running
ps aux | grep X
```

### Controller Not Detected

```bash
# Check USB devices
lsusb | grep -i logitech

# List input devices
ls -la /dev/input/

# Set permissions
sudo chmod a+rw /dev/input/*
```

### GPU Not Working

```bash
# Verify NVIDIA driver
nvidia-smi

# Check Docker runtime
docker info | grep -i runtime

# Test GPU in container
docker compose exec carla nvidia-smi
```

### Low Performance

```bash
# Reduce quality in .env
CARLA_QUALITY=Low
CARLA_RES_X=1280
CARLA_RES_Y=720

# For Jetson, enable max performance
sudo nvpmodel -m 0
sudo jetson_clocks

# Restart container
docker compose restart carla
```

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── docker-build.yml    # Multi-arch build workflow
│       └── release.yml         # Release workflow
├── scripts/
│   ├── start-carla.sh          # CARLA startup script
│   ├── setup-display.sh        # Display configuration
│   ├── setup-controller.sh     # Controller setup
│   ├── carla-config.py         # Configuration helper
│   └── manual_control_wheel.py # Wheel control example
├── Dockerfile                  # Multi-arch Dockerfile
├── docker-compose.yml          # Docker Compose config
├── .env.example                # Environment template
├── build.sh                    # Build script
├── quickstart.sh               # Quick start script
└── README.md                   # This file
```

## Architecture

The Dockerfile uses multi-stage builds:

1. **Base stage**: Common dependencies for all platforms
2. **Platform-specific stages**:
   - `carla-amd64`: x86_64 with official CARLA binaries
   - `carla-arm64`: ARM64 optimized for Jetson Orin
3. **Final stage**: Selected based on target platform

GitHub Actions automatically builds both architectures and pushes to container registry.

## Supported CARLA Version

- CARLA 0.9.15 (x86_64)
- CARLA 0.9.15 compatible (ARM64)

## License

This project follows CARLA's MIT License.

## Contributing

Issues and pull requests are welcome!

## Resources

- [CARLA Documentation](https://carla.readthedocs.io/)
- [CARLA Python API](https://carla.readthedocs.io/en/latest/python_api/)
- [Jetson Developer Zone](https://developer.nvidia.com/embedded/jetson-orin)
- [JETSON_SETUP.md](JETSON_SETUP.md) - Detailed Jetson setup guide
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide

## Support

For issues, please open a GitHub issue with:
- Platform (x86_64 or Jetson Orin model)
- Docker version
- GPU information
- Error logs

---

Built with multi-architecture support for autonomous driving development.
