# CARLA Local Setup

Simple 3-step workflow to run CARLA simulator locally on your Linux machine.

## What This Provides

- **CARLA 0.9.15** simulator running directly on your host
- GPU acceleration with NVIDIA runtime
- Interactive helper for managing maps, vehicles, and weather
- Manual control for keyboard/wheel driving

## Requirements

- Ubuntu 20.04/22.04 or compatible Linux
- NVIDIA GPU (GTX 1060 or better recommended)
- 16GB+ RAM
- NVIDIA drivers installed
- ~10GB disk space for CARLA

## Quick Start

### 🚀 Simple 3-Step Workflow

```bash
# Clone repository
git clone https://github.com/tri2510/carla-multiarch-docker.git
cd carla-multiarch-docker

# Step 1: Download and setup CARLA (run once, ~10GB download)
scripts/1-setup-carla.sh

# Step 2: Start CARLA simulator (runs in background)
scripts/2-start-carla.sh

# Step 3: Use interactive helper (same terminal)
scripts/3-carla-helper.sh
```

That's it! The interactive helper provides a menu for:
- Spawning vehicles
- Changing maps
- Adjusting weather
- Manual driving control

### Using the Helper

The helper can be used interactively (menu-driven) or with direct commands:

```bash
# Interactive menu (easiest)
scripts/3-carla-helper.sh

# Or use direct commands:
scripts/3-carla-helper.sh --list-maps
scripts/3-carla-helper.sh --set-map Town04
scripts/3-carla-helper.sh --spawn vehicle.tesla.model3 --view chase
scripts/3-carla-helper.sh --weather HardRainSunset
scripts/3-carla-helper.sh --manual  # Drive with keyboard/wheel

Need wheel support? Menu option 7 (or `scripts/3-carla-helper.sh --manual-wheel`)
uses the Logitech profile described in [docs/LOGITECH_WHEEL.md](docs/LOGITECH_WHEEL.md),
including optional mappings for the H-pattern shifter. Manual control defaults
to the Cybertruck (`vehicle.tesla.cybertruck`); override it by exporting
`CARLA_MANUAL_FILTER=vehicle.some_model`. While driving, press `T` to respawn the
Tesla instantly.
```

### Customizing Startup

You can customize quality and resolution when starting CARLA:

```bash
# Start with different quality/resolution
scripts/2-start-carla.sh --quality Medium --resolution 1280x720
scripts/2-start-carla.sh --quality High --resolution 1920x1080

# Use safe preset (Medium quality, OpenGL, 1280x720)
scripts/2-start-carla.sh --preset safe

# Get help
scripts/1-setup-carla.sh --help
scripts/2-start-carla.sh --help
scripts/3-carla-helper.sh --help
```

## Configuration

Default settings work out of the box, but you can customize via command-line flags or environment variables:

### Startup Options (2-start-carla.sh)

- `--quality` - Low, Medium, High, Epic (default: Medium)
- `--resolution` - e.g., 1920x1080 (default: 800x600)
- `--opengl` - Force OpenGL renderer (default: Vulkan)
- `--offscreen` - Run without window (headless)
- `--rpc-port` - Change RPC port (default: 2000)
- `--stream-port` - Change streaming port (default: 2001)

### Setup Options (1-setup-carla.sh)

- `--tarball PATH` - Use existing CARLA tarball instead of downloading
- `--force-download` - Re-download even if cached

### Environment Variables

```bash
# Override CARLA version
export CARLA_VERSION=0.9.15

# Use custom cache directory
export CARLA_CACHE_DIR=/path/to/cache

# Use custom install directory
export LOCAL_CARLA_DIR=/path/to/install
```

## Troubleshooting

### CARLA Window Not Appearing

If you see CARLA starting but no window appears:

```bash
# Grant display access
xhost +local:$USER

# Check your DISPLAY variable
echo $DISPLAY

# Try with safe preset
scripts/2-start-carla.sh --preset safe
```

### Low Performance

```bash
# Reduce quality and resolution
scripts/2-start-carla.sh --quality Low --resolution 800x600

# Use offscreen mode (no rendering)
scripts/2-start-carla.sh --offscreen
```

### GPU Not Working

```bash
# Check NVIDIA driver
nvidia-smi

# Check Vulkan support
vulkaninfo --summary
```

### Port Already in Use

```bash
# Use different ports
scripts/2-start-carla.sh --rpc-port 2002 --stream-port 2003

# Then connect helper to custom port
scripts/3-carla-helper.sh --port 2002
```

## Project Structure

```
.
├── scripts/
│   ├── 1-setup-carla.sh      # Step 1: Download/setup CARLA (~10GB)
│   ├── 2-start-carla.sh      # Step 2: Start CARLA simulator
│   ├── 3-carla-helper.sh     # Step 3: Interactive helper (menu-driven)
│   └── 3-carla-helper.py     # Python helper (called by .sh wrapper)
├── local_carla/              # CARLA installation (created by setup)
├── docs/
│   └── QUICKSTART.md         # Quick start guide
└── README.md                 # This file
```

## Documentation

- [docs/QUICKSTART.md](docs/QUICKSTART.md) - Detailed quick start guide

## Python API Examples

Once CARLA is running, you can use the Python API:

```python
import sys
sys.path.append('local_carla/PythonAPI/carla/dist/carla-0.9.15-py3.7-linux-x86_64.egg')
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

## Supported Versions

- **CARLA:** 0.9.15 (default)
- **Python:** 3.7+ for API
- **OS:** Ubuntu 20.04/22.04, most Linux distributions
- **NVIDIA Driver:** 470+ recommended

## License

MIT License - Same as CARLA simulator

## Contributing

Issues and pull requests welcome!

## Resources

- [CARLA Documentation](https://carla.readthedocs.io/)
- [CARLA Python API](https://carla.readthedocs.io/en/latest/python_api/)
- [CARLA Releases](https://github.com/carla-simulator/carla/releases)

---

**Simple. Local. No Docker required.**
