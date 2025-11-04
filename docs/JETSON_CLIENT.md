# CARLA Client for Jetson Orin

Run CARLA Python client on Jetson Orin, connecting to a remote x86 CARLA server.

## Architecture

```
┌──────────────────────────┐           ┌──────────────────────────┐
│  x86 Server              │           │  Jetson Orin             │
│  ┌────────────────────┐  │  Network  │  ┌────────────────────┐  │
│  │ CARLA Simulator    │  │◄─────────►│  │ Python Client      │  │
│  │ - Rendering        │  │  1Gbps    │  │ - Control          │  │
│  │ - Physics          │  │           │  │ - Perception       │  │
│  │ - Sensors          │  │           │  │ - Planning         │  │
│  └────────────────────┘  │           │  └────────────────────┘  │
│  GPU: RTX 2070+          │           │  GPU: Jetson Orin        │
└──────────────────────────┘           └──────────────────────────┘
```

## Quick Start

### Prerequisites

**On x86 Server:**
- Docker with NVIDIA runtime
- NVIDIA GPU (RTX 2070 or better)
- This repository

**On Jetson Orin:**
- JetPack 5.0+
- Docker with NVIDIA runtime
- Network connection to x86 server

### Step 1: Start CARLA Server (x86)

```bash
# On x86 server
cd carla-multiarch-docker

# Setup environment
cp .env.example .env
nano .env  # Configure as needed

# Start CARLA server
docker compose up -d

# Check logs
docker compose logs -f carla
```

Wait for: "Server listening on port 2000"

### Step 2: Configure Jetson Client

```bash
# On Jetson Orin
cd carla-multiarch-docker

# Configure server connection
cp examples/.env.jetson .env.jetson
nano .env.jetson  # Set CARLA_SERVER_HOST to x86 server IP
```

Edit `.env.jetson`:
```bash
CARLA_SERVER_HOST=192.168.1.100  # Your x86 server IP
CARLA_SERVER_PORT=2000
```

### Step 3: Build Jetson Client Image

```bash
# On Jetson Orin
docker build -f Dockerfile.jetson-client -t carla-jetson-client:latest .
```

This takes 10-15 minutes (downloads PyTorch for Jetson).

> **Note:** CARLA 0.10.x binaries are only published for x86_64 at the
> moment. The Jetson client layer therefore installs the latest ARM64 Python
> wheel available on PyPI (0.9.16) which remains wire-compatible with the
> 0.10.x server RPC API.

### Step 4: Start Client Container

```bash
# Start container
docker compose -f docker-compose.jetson-client.yml up -d

# Test connection
docker compose -f docker-compose.jetson-client.yml exec carla-client \
  python3 /workspace/test_connection.py
```

Expected output:
```
Testing connection to CARLA server at 192.168.1.100:2000...
✅ Connected successfully!
   Map: Town03
   Server version: 0.10.0
```

### Step 5: Run Example

```bash
docker compose -f docker-compose.jetson-client.yml exec carla-client \
  python3 /workspace/examples/jetson_client_example.py
```

## Usage Examples

### Interactive Shell

```bash
docker compose -f docker-compose.jetson-client.yml exec carla-client bash

# Inside container
python3
>>> import carla
>>> client = carla.Client('192.168.1.100', 2000)
>>> world = client.get_world()
>>> print(world.get_map().name)
```

### Run Your Own Scripts

```bash
# Mount your scripts directory
# Edit docker-compose.jetson-client.yml:
volumes:
  - ./your_scripts:/workspace/custom:rw

# Run your script
docker compose -f docker-compose.jetson-client.yml exec carla-client \
  python3 /workspace/custom/your_script.py
```

### Example: Spawn Vehicle and Drive

```python
import carla
import os

# Connect to server
host = os.getenv('CARLA_SERVER_HOST')
client = carla.Client(host, 2000)
world = client.get_world()

# Spawn vehicle
bp = world.get_blueprint_library().filter('vehicle.tesla.model3')[0]
spawn_point = world.get_map().get_spawn_points()[0]
vehicle = world.spawn_actor(bp, spawn_point)

# Enable autopilot
vehicle.set_autopilot(True)

# Or manual control
vehicle.apply_control(carla.VehicleControl(
    throttle=0.5,
    steer=0.0
))
```

## Network Configuration

### Local Network (Recommended)

Connect both machines to the same local network:

```bash
# Check connectivity from Jetson
ping 192.168.1.100  # x86 server IP

# Test CARLA port
nc -zv 192.168.1.100 2000
```

### Port Forwarding

If machines are on different networks, use SSH tunneling:

```bash
# On Jetson
ssh -L 2000:localhost:2000 user@x86-server-ip

# Then connect to localhost
CARLA_SERVER_HOST=localhost
```

### Firewall Rules

On x86 server, allow CARLA ports:

```bash
# Ubuntu
sudo ufw allow 2000/tcp
sudo ufw allow 2001/tcp
sudo ufw reload
```

## Performance Tips

### Jetson Orin Settings

```bash
# Set maximum performance
sudo nvpmodel -m 0
sudo jetson_clocks

# Check current mode
sudo nvpmodel -q
```

### Network Optimization

```bash
# Check network latency
ping 192.168.1.100

# Monitor bandwidth
iftop -i eth0
```

### CARLA Server Settings

For better network performance, on x86 server `.env`:

```bash
# Reduce rendering quality (server-side)
CARLA_QUALITY=Medium
CARLA_RES_X=1280
CARLA_RES_Y=720

# Enable synchronous mode (better for control)
# In Python:
# settings = world.get_settings()
# settings.synchronous_mode = True
# settings.fixed_delta_seconds = 0.05
# world.apply_settings(settings)
```

## Troubleshooting

### Cannot Connect to Server

```bash
# Check network connectivity
ping 192.168.1.100

# Check CARLA server is running
docker compose logs carla | grep "listening"

# Check firewall
sudo ufw status

# Test port
telnet 192.168.1.100 2000
```

### High Latency

```bash
# Check network latency
ping 192.168.1.100

# Should be < 10ms for local network
# Use wired connection, not WiFi
```

### Out of Memory on Jetson

```bash
# Reduce Docker memory limit
# Edit docker-compose.jetson-client.yml
memory: 4G  # Instead of 8G

# Check current usage
docker stats
```

### Python Import Errors

```bash
# Rebuild image
docker compose -f docker-compose.jetson-client.yml build --no-cache

# Or manually install (latest PyPI build for ARM64)
docker compose -f docker-compose.jetson-client.yml exec carla-client \
  pip3 install carla==0.9.16
```

## Development Workflow

### 1. Develop on x86 Desktop

```bash
# Test with local CARLA
python3 your_script.py
```

### 2. Deploy to Jetson

```bash
# Copy script
scp your_script.py jetson@jetson-ip:/path/to/carla-multiarch-docker/examples/

# Run on Jetson
ssh jetson@jetson-ip
docker compose -f docker-compose.jetson-client.yml exec carla-client \
  python3 /workspace/examples/your_script.py
```

### 3. Debug

```bash
# Interactive debugging
docker compose -f docker-compose.jetson-client.yml exec carla-client bash

# Install ipdb for debugging
pip3 install ipdb

# Use in your script
import ipdb; ipdb.set_trace()
```

## Real-World Use Cases

### Autonomous Driving Development

- **Jetson**: Run perception, planning, control algorithms
- **x86 Server**: Provide simulated sensor data and environment

### Algorithm Testing

- **Jetson**: Test ML models for inference
- **x86 Server**: Generate diverse scenarios

### Hardware-in-the-Loop (HIL)

- **Jetson**: Interface with real vehicle controllers
- **x86 Server**: Provide simulation environment

## Resources

- [CARLA Python API](https://carla.readthedocs.io/en/latest/python_api/)
- [RESEARCH_ARM64.md](RESEARCH_ARM64.md) - Why native build doesn't work
- [ARM64_STATUS.md](ARM64_STATUS.md) - Current status and alternatives
- [Autoware + CARLA Example](https://github.com/LiZheng1997/Autoware.universe-with-carla-0.9.15)

## Next Steps

1. ✅ Set up client-server connection
2. ✅ Test basic vehicle control
3. 🎯 Integrate with your autonomous driving stack
4. 🎯 Deploy perception models on Jetson
5. 🎯 Implement closed-loop control

---

**Architecture**: Client-Server
**Jetson Role**: Python Client + Inference
**x86 Role**: CARLA Simulator
**Status**: Production Ready ✅
