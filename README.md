# CARLA Docker for x86_64 and Jetson Orin

Docker setup for CARLA simulator with display support and Logitech wheel integration.

[![Validation](https://github.com/tri2510/carla-multiarch-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/tri2510/carla-multiarch-docker/actions/workflows/docker-build.yml)
[![Release](https://github.com/tri2510/carla-multiarch-docker/actions/workflows/release.yml/badge.svg)](https://github.com/tri2510/carla-multiarch-docker/actions/workflows/release.yml)

> **Note:** Pre-built Docker images are not provided due to CARLA's large size (~10GB). Build locally using the instructions below.

## What This Project Provides

### ✅ For x86_64 (Desktop/Server)
- **CARLA 0.10.0 (UE5)** full simulator in Docker
- Direct display support (X11/Wayland)
- GPU acceleration with NVIDIA runtime
- Logitech wheel support (G27/G29/G920)
- Easy deployment with docker-compose

### ✅ For Jetson Orin (ARM64)
- **CARLA Python client** in Docker
- Connects to x86 CARLA server over network
- Run perception/planning algorithms
- Proven client-server architecture

> **Note:** Jetson cannot run full CARLA simulator (Unreal Engine not available for ARM64). Use client-server setup instead. See [Why ARM64 Native Build Doesn't Work](#why-arm64-native-build-doesnt-work).

## Quick Start

### 🚀 Simple 3-Step Workflow (Recommended)

Run CARLA directly on your host machine with these 3 simple scripts:

```bash
# Clone repository
git clone https://github.com/tri2510/carla-multiarch-docker.git
cd carla-multiarch-docker

# Step 1: Download and setup CARLA (run once, ~10GB download)
scripts/1-setup-carla.sh

# Step 2: Start CARLA simulator
scripts/2-start-carla.sh

# Step 3: In another terminal, use interactive helper
scripts/3-carla-helper.sh                                                # Interactive menu

# Or use directly with arguments:
scripts/3-carla-helper.sh --list-maps                                    # List available maps
scripts/3-carla-helper.sh --set-map Town04                               # Switch to Town04
scripts/3-carla-helper.sh --spawn vehicle.tesla.model3 --view chase      # Spawn vehicle
scripts/3-carla-helper.sh --weather HardRainSunset                       # Change weather
scripts/3-carla-helper.sh --manual                                       # Drive with keyboard/wheel
```

**Common Options:**
```bash
# Start with safe settings (Medium quality, OpenGL, 1280x720)
scripts/2-start-carla.sh --preset safe

# Start with custom quality and resolution
scripts/2-start-carla.sh --quality High --resolution 1920x1080

# Use OpenGL instead of Vulkan (better compatibility)
scripts/2-start-carla.sh --opengl

# Get help for any script
scripts/1-setup-carla.sh --help
scripts/2-start-carla.sh --help
scripts/3-carla-helper.sh --help
```

### Alternative: Docker Compose (x86_64)

If you prefer containerized deployment:

```bash
# Clone repository
git clone https://github.com/tri2510/carla-multiarch-docker.git
cd carla-multiarch-docker

# Setup environment
cp .env.example .env

# Allow Docker to access display
xhost +local:docker

# Start CARLA
docker compose up -d

# View logs
docker compose logs -f carla
```

> **Tip:** The first build downloads a ~10 GB CARLA archive. Docker BuildKit
> caches this file automatically (via `docker buildx` / compose v2), so future
> builds reuse the cached tarball instead of re-downloading it. If you use the
> legacy Docker CLI, export `DOCKER_BUILDKIT=1` before building to enable the
> cache.

### Alternative: Docker Helper Wrapper

For Docker workflow with command-line overrides:

```bash
# Launch CARLA with ad-hoc overrides
scripts/run-local-carla.sh --quality High --resolution 2560x1440 --offscreen

# Other actions
scripts/run-local-carla.sh --stop        # stop service
scripts/run-local-carla.sh --status      # show status
scripts/run-local-carla.sh --logs        # tail logs
```

The wrapper sources `.env` (if present) and lets you override CARLA quality,
resolution, offscreen/OpenGL modes, ports, controller type, DISPLAY, and GPU
visibility via CLI flags. It automatically builds the image the first time it runs
and then skips rebuilds (`docker compose up --no-build`) so subsequent launches
are instant; use `--build` to force a rebuild when you change the Dockerfile.

### Jetson Orin (Client Mode)

**Requirements:** x86 server running CARLA (see above)

```bash
# Clone on Jetson
git clone https://github.com/tri2510/carla-multiarch-docker.git
cd carla-multiarch-docker

# Configure server connection
cp examples/.env.jetson .env.jetson
nano .env.jetson  # Set CARLA_SERVER_HOST to x86 IP

# Build and start client
docker build -f Dockerfile.jetson-client -t carla-jetson-client:latest .
docker compose -f docker-compose.jetson-client.yml up -d

# Test connection
docker compose -f docker-compose.jetson-client.yml exec carla-client \
  python3 /workspace/test_connection.py
```

> **Note:** CARLA 0.10.x binaries are currently published for x86_64 only. The
> Jetson client container therefore pins the latest ARM64-compatible Python API
> wheel from PyPI (0.9.16) which is wire-compatible with the 0.10.x server.

See [docs/JETSON_CLIENT.md](docs/JETSON_CLIENT.md) for complete Jetson setup guide.

## Configuration

Edit `.env` file:

```bash
# Display
DISPLAY=:0

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

## Usage Examples

### Manual Control with Logitech Wheel

```bash
docker compose exec carla python3 /home/carla/scripts/manual_control_wheel.py
```

**Controls:**
- Steering Wheel → Steer
- Right Pedal → Throttle
- Middle Pedal → Brake
- Left Pedal → Clutch
- ESC/Q → Quit

### Wheel Detection / Calibration

```bash
# Run inside the container to verify Logitech wheel axes/buttons
docker compose exec carla python3 /home/carla/scripts/wheel_detection.py
```

The helper prints live axis/button values so you can confirm the wheel is visible
to CARLA before launching the manual control script.

### Stream Speed/RPM to KUKSA VSS

Run the bridge inside the CARLA container to forward telemetry to a local KUKSA
databroker (default `Vehicle.Speed` and
`Vehicle.Powertrain.CombustionEngine.Speed`):

```bash
docker compose exec carla python3 /home/carla/scripts/carla_vss_bridge.py \
  --kuksa-host 172.17.0.1 --kuksa-port 55555 --vehicle-role-name hero
```

- Adjust `--kuksa-host` to the address reachable from inside the container
  (`172.17.0.1` corresponds to the Linux host; use `host.docker.internal` on
  macOS/Windows Docker).
- `--max-speed-kmh`, `--rpm-idle`, and `--rpm-max` shape the linear mapping from
  vehicle speed to RPM.

Use `--vehicle-id` if you want to pin to a specific CARLA actor id instead of a
`role_name`.

### Python API Examples

```bash
# Enter container
docker compose exec carla bash

# Run examples
cd /home/carla/PythonAPI/examples
python3 generate_traffic.py -n 50
python3 dynamic_weather.py
```

### Custom Python Script

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

## Architecture

### x86_64 Standalone

```
┌────────────────────────┐
│   x86_64 Desktop       │
│   ┌──────────────────┐ │
│   │ CARLA Simulator  │ │
│   │ - Full features  │ │
│   │ - Direct display │ │
│   │ - GPU rendering  │ │
│   └──────────────────┘ │
└────────────────────────┘
```

### Client-Server (with Jetson)

```
┌─────────────────────┐         ┌──────────────────┐
│  x86_64 Server      │ Network │  Jetson Orin     │
│  ┌───────────────┐  │◄───────►│  ┌────────────┐  │
│  │ CARLA Server  │  │ 1Gbps   │  │   Client   │  │
│  │ - Rendering   │  │         │  │ - Control  │  │
│  │ - Physics     │  │         │  │ - Sensors  │  │
│  │ - Simulation  │  │         │  │ - Planning │  │
│  └───────────────┘  │         │  └────────────┘  │
│  GPU: RTX 2070+     │         │  GPU: Jetson     │
└─────────────────────┘         └──────────────────┘
```

## Troubleshooting

### Display Issues

```bash
# Allow Docker to access display
xhost +local:docker

# Check display
echo $DISPLAY

# Verify X11
ps aux | grep X
```

### Controller Not Detected

```bash
# Check USB devices
lsusb | grep -i logitech

# Set permissions
sudo chmod a+rw /dev/input/*
```

### GPU Not Working

```bash
# Check NVIDIA driver
nvidia-smi

# Check Docker runtime
docker info | grep -i runtime

# Test in container
docker compose exec carla nvidia-smi
```

### Low Performance

```bash
# Reduce quality in .env
CARLA_QUALITY=Low
CARLA_RES_X=1280
CARLA_RES_Y=720

# Restart
docker compose restart carla
```

## Why ARM64 Native Build Doesn't Work

**CARLA cannot run natively on Jetson Orin because:**

1. **Unreal Engine 4.26** - Cannot be compiled for ARM64
2. **No ARM64 binaries** - CARLA doesn't provide ARM builds
3. **Community attempts failed** - See [docs/RESEARCH_ARM64.md](docs/RESEARCH_ARM64.md)

**Solution:** Use client-server architecture (proven by Autoware community)

## Project Structure

```
.
├── Dockerfile                      # x86_64 CARLA server
├── Dockerfile.jetson-client        # ARM64 Python client
├── docker-compose.yml              # x86 deployment
├── docker-compose.jetson-client.yml# Jetson deployment
├── scripts/
│   ├── 1-setup-carla.sh            # Step 1: Download/setup CARLA (~10GB)
│   ├── 2-start-carla.sh            # Step 2: Start CARLA simulator
│   ├── 3-carla-helper.sh           # Step 3: Interactive helper (maps/vehicles/weather)
│   ├── 3-carla-helper.py           # Python helper (called by .sh wrapper)
│   └── run-local-carla.sh          # Docker compose wrapper (alternative)
├── container_scripts/
│   ├── start-carla.sh              # Container startup script
│   ├── setup-display.sh            # Display setup
│   ├── setup-controller.sh         # Controller setup
│   ├── carla-config.py             # Config helper
│   ├── manual_control_wheel.py     # Wheel control
│   ├── wheel_detection.py          # Wheel detection helper
│   └── carla_vss_bridge.py         # CARLA → KUKSA bridge
├── examples/
│   └── jetson_client_example.py    # Jetson example
└── README.md                       # This file
```

## Documentation

- [docs/QUICKSTART.md](docs/QUICKSTART.md) - Quick start guide
- [docs/JETSON_CLIENT.md](docs/JETSON_CLIENT.md) - Complete Jetson setup
- [docs/JETSON_SETUP.md](docs/JETSON_SETUP.md) - Jetson Orin configuration
- [docs/RESEARCH_ARM64.md](docs/RESEARCH_ARM64.md) - Why ARM64 native build doesn't work
- [docs/ARM64_STATUS.md](docs/ARM64_STATUS.md) - Current ARM64 status

## Supported Versions

- **CARLA:** 0.10.0
- **Python:** 3.8+
- **Docker:** 20.10+
- **NVIDIA Driver:** 470+

## Requirements

### x86_64
- Ubuntu 20.04/22.04
- NVIDIA GPU (GTX 1060 or better)
- 16GB+ RAM
- NVIDIA Container Toolkit

### Jetson Orin
- JetPack 5.0+
- Network connection to x86 CARLA server
- 8GB+ RAM

## License

MIT License - Same as CARLA simulator

## Contributing

Issues and pull requests welcome!

## Resources

- [CARLA Documentation](https://carla.readthedocs.io/)
- [CARLA Python API](https://carla.readthedocs.io/en/latest/python_api/)
- [Docker Multi-Platform](https://docs.docker.com/build/building/multi-platform/)

---

**Built for autonomous driving development**
