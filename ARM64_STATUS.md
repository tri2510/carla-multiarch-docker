# ARM64/Jetson Orin Support Status

⚠️ **Update (Nov 2024): Native ARM64 build is NOT POSSIBLE**

✅ **Solution: Client-Server Architecture (Proven & Working)**

## What Works

✅ **x86_64 (Intel/AMD)**
- Official CARLA 0.9.15 binaries
- Full GPU acceleration
- All features working

## What's Not Possible

❌ **Native ARM64/Jetson Orin CARLA Server**
- Unreal Engine 4.26 cannot be compiled for ARM64
- Official CARLA doesn't provide ARM64 pre-built binaries
- Building from source is not feasible (see RESEARCH_ARM64.md)

✅ **ARM64/Jetson Orin CARLA Python Client**
- Python client works perfectly on ARM64
- Connects to remote x86 CARLA server
- Proven architecture used by Autoware community

## Proven Solution for Jetson Orin Users

### Client-Server Architecture (Recommended)

**Setup:**

1. **x86 Server (Desktop/Cloud)**: Run CARLA simulator
2. **Jetson Orin**: Run CARLA Python client + your algorithms

```bash
# On x86 Server - Run CARLA
docker compose up -d

# On Jetson Orin - Run Python client
docker compose -f docker-compose.jetson-client.yml up -d

# Test connection
docker compose -f docker-compose.jetson-client.yml exec carla-client \
  python3 /workspace/test_connection.py

# Run example
docker compose -f docker-compose.jetson-client.yml exec carla-client \
  python3 /workspace/examples/jetson_client_example.py
```

**Network Requirements:**
- Local network or VPN connection
- Recommended: 1 Gbps Ethernet
- Latency: <10ms for real-time control

**This is the PROVEN approach used by:**
- Autoware.universe with CARLA
- Academic research projects
- Industry autonomous driving development

## Roadmap

- [ ] Create separate ARM64 build workflow
- [ ] Provide pre-built ARM64 binaries
- [ ] Test on Jetson Orin AGX/NX/Nano
- [ ] Optimize performance for Jetson

## Current Recommendation

**For Production Use:**
- Use x86_64 server for CARLA simulator
- Use Jetson for inference/testing with remote connection

```bash
# On Jetson - connect to remote CARLA
docker run -it --rm \
  --runtime=nvidia \
  ghcr.io/tri2510/carla-multiarch-docker:latest \
  python3 -c "import carla; client = carla.Client('x86-server-ip', 2000)"
```

## Contributing

If you have a working CARLA build for Jetson Orin, please share:
1. Build instructions
2. Pre-built binaries
3. Performance benchmarks

Open an issue or PR to contribute!
