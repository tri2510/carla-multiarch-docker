# CARLA Multi-Arch - Quick Start Guide

Get CARLA running in 5 minutes!

## TL;DR

```bash
# One command to rule them all
./quickstart.sh
```

## For x86_64 (Desktop/Laptop)

### Prerequisites
- Docker with NVIDIA Container Toolkit
- NVIDIA GPU with drivers

### Quick Setup

```bash
# 1. Clone and enter directory
cd /home/htr1hc/01_SDV/72_carla_arm

# 2. Run quick start
./quickstart.sh

# 3. Wait for build and startup
# CARLA will start automatically

# 4. Test with manual control
docker compose exec carla python3 /home/carla/scripts/manual_control_wheel.py
```

## For Jetson Orin (ARM64)

### Prerequisites
- JetPack 5.0+
- NVIDIA Container Runtime
- Connected display (HDMI/DP)

### Quick Setup

```bash
# 1. Set maximum performance
sudo nvpmodel -m 0
sudo jetson_clocks

# 2. Clone and enter directory
cd /home/htr1hc/01_SDV/72_carla_arm

# 3. Run quick start
./quickstart.sh

# 4. Select Jetson-optimized settings when prompted

# 5. Wait for build (15-30 minutes first time)

# 6. Test connection
docker compose exec carla python3 -c "import carla; print('CARLA ready!')"
```

## Common Commands

### Start/Stop CARLA

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# View logs
docker compose logs -f carla
```

### Configuration

```bash
# Interactive config
docker compose exec carla python3 /home/carla/scripts/carla-config.py

# Quick presets
docker compose exec carla python3 /home/carla/scripts/carla-config.py --presets
```

### Manual Control

```bash
# With Logitech wheel
docker compose exec carla python3 /home/carla/scripts/manual_control_wheel.py

# With keyboard
docker compose exec carla python3 /home/carla/PythonAPI/examples/manual_control.py
```

### Python Examples

```bash
# Enter container
docker compose exec carla bash

# Run examples
cd /home/carla/PythonAPI/examples

# Generate traffic
python3 generate_traffic.py -n 50

# Spawn NPCs
python3 spawn_npc.py --number-of-vehicles 50 --number-of-walkers 50

# Dynamic weather
python3 dynamic_weather.py
```

## Performance Settings

### High Quality (Powerful x86 GPU)
```bash
# In .env
CARLA_QUALITY=Epic
CARLA_RES_X=1920
CARLA_RES_Y=1080
```

### Balanced (Medium GPU / Jetson AGX)
```bash
# In .env
CARLA_QUALITY=Medium
CARLA_RES_X=1280
CARLA_RES_Y=720
```

### Performance (Jetson Nano/NX / Low-end GPU)
```bash
# In .env
CARLA_QUALITY=Low
CARLA_RES_X=1280
CARLA_RES_Y=720
```

## Troubleshooting

### Display not working?
```bash
xhost +local:docker
./container_scripts/setup-display.sh
```

### Controller not detected?
```bash
./container_scripts/setup-controller.sh
sudo chmod a+rw /dev/input/*
```

### Low FPS?
```bash
# Reduce quality in .env
CARLA_QUALITY=Low

# Restart
docker compose restart carla
```

### Out of memory?
```bash
# Reduce memory limit in .env
DOCKER_MEMORY=12G

# Reduce vehicles in your scripts
# python3 generate_traffic.py -n 20  # Instead of 50
```

## What's Included

- ✅ CARLA 0.10.0 simulator
- ✅ Python API and examples
- ✅ Logitech wheel support (G27/G29/G920)
- ✅ Direct display output (X11/Wayland)
- ✅ GPU acceleration (NVIDIA)
- ✅ Configuration helper
- ✅ Manual control scripts

## Next Steps

1. **Learn the basics**: [README.md](README.md)
2. **Jetson setup**: [JETSON_SETUP.md](JETSON_SETUP.md)
3. **CARLA documentation**: https://carla.readthedocs.io/
4. **Python API**: https://carla.readthedocs.io/en/latest/python_api/

## Need Help?

Check the full documentation:
- **README.md** - Complete guide
- **JETSON_SETUP.md** - Jetson-specific setup
- **Docker logs** - `docker compose logs -f carla`

## File Structure

```
72_carla_arm/
├── Dockerfile                 # Multi-arch build
├── docker-compose.yml         # Container config
├── .env.example              # Settings template
├── quickstart.sh             # This quick start
├── build.sh                  # Build script
├── scripts/
│   └── run-local-carla.sh    # Local control wrapper
├── container_scripts/
│   ├── start-carla.sh        # Startup script
│   ├── setup-display.sh      # Display setup
│   ├── setup-controller.sh   # Controller setup
│   ├── carla-config.py       # Config helper
│   └── manual_control_wheel.py
├── configs/                  # Your configs
├── data/                     # Persistent data
└── logs/                     # Log files
```

Happy simulating! 🚗💨
