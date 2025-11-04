# ARM64/Jetson Orin Support Status

⚠️ **Current Status: Work in Progress**

## What Works

✅ **x86_64 (Intel/AMD)**
- Official CARLA 0.9.15 binaries
- Full GPU acceleration
- All features working

## What's Not Ready

❌ **ARM64/Jetson Orin**
- CARLA binaries need to be built from source
- Official CARLA doesn't provide ARM64 pre-built binaries
- Building takes 4-6 hours

## Solutions for Jetson Orin Users

### Option 1: Mount Pre-built CARLA (Recommended)

If you already have CARLA built on your Jetson:

```yaml
# docker-compose.yml
volumes:
  - /path/to/your/carla/build:/home/carla:ro
```

### Option 2: Build CARLA from Source on Jetson

```bash
# On Jetson Orin
git clone --depth 1 -b 0.9.15 https://github.com/carla-simulator/carla.git
cd carla

# Follow official build instructions
# https://carla.readthedocs.io/en/latest/build_linux/

# This takes 4-6 hours
./Update.sh
make PythonAPI
make launch
```

Then mount the built CARLA in docker-compose.yml

### Option 3: Use Lightweight Alternative

For testing/development on Jetson, consider:
- CARLA ROS Bridge with remote x86 CARLA server
- CARLA Python API connecting to remote server
- Lighter simulators like LGSVL

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
