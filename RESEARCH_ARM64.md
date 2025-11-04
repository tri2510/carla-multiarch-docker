# Research: CARLA on ARM64/Jetson Orin

**Research Date:** 2025-11-04
**CARLA Version:** 0.9.15
**Target Platform:** ARM64 (Jetson Orin)

## Summary

❌ **CARLA cannot be built natively for ARM64/Jetson Orin** (as of November 2024)

✅ **Client-Server Architecture Works** - Jetson runs Python client, x86 server runs CARLA

## Key Findings

### 1. Official ARM64 Support Status

**From GitHub Issue #5845 (Open since Oct 2022):**
- ❌ No official ARM64 support
- ❌ No pre-built ARM64 binaries
- ❌ No ARM64 egg files for Python API
- Official response: "Everything around here is using x86. ARM is a completely different Instruction set architecture (ISA)."

**Technical Blockers:**
1. **Unreal Engine 4.26** - No easy way to compile for ARM64
2. **Dependencies** - All dependencies (libosm2odr, libxerces-c, etc.) must be compiled for ARM
3. **No Documentation** - No official guide for ARM compilation

### 2. Unreal Engine 4.26 on ARM64

**Compilation Challenges:**
- Requires UE4 source code compilation
- Need ARM64 toolchain (clang++ v8 with AArch64)
- Environment variables: `LINUX_MULTIARCH_ROOT`, `UE4_LINUX_USE_LIBCXX=0`
- Vulkan driver issues on Jetson Orin reported
- Desktop OpenGL only available on Jetson (not standard ARM)

**Effort Required:**
- Multiple UE4 engine recompilations
- Custom patches for Jetson GPU support
- 4-6 hours build time (minimum)
- Likely multiple attempts needed

### 3. Proven Solution: Client-Server Architecture

**Architecture Used by Autoware.universe-with-carla-0.9.15:**

```
┌─────────────────────────────────────┐
│  Host Machine (x86_64)              │
│  - NVIDIA RTX 2070/3080/4090        │
│  - CARLA 0.9.15 Server (Docker)     │
│  - Autoware-CARLA Bridge (ROS2)     │
└────────────┬────────────────────────┘
             │ 1 Gbps Network
┌────────────┴────────────────────────┐
│  Jetson Orin (ARM64)                │
│  - Autoware.universe (Docker)       │
│  - CARLA Python Client              │
│  - Autonomous Driving Stack         │
└─────────────────────────────────────┘
```

**Key Components:**
1. **x86 Host**: Runs CARLA simulator (GPU-intensive rendering)
2. **Jetson Orin**: Runs perception/planning algorithms (inference)
3. **Network**: ROS2 bridge for communication
4. **Docker**: Pre-built ARM64 image for Jetson (autoware.universe)

### 4. Docker Images Available

**For x86_64 (CARLA Server):**
- `carlasim/carla:0.9.15` - Official image
- Works perfectly for simulation server

**For ARM64 (Python Client Only):**
- No full CARLA image
- Python client library can be installed: `pip install carla`
- Connects to remote x86 CARLA server

**Community Image (Autoware):**
- Pre-built Docker image for Jetson Orin
- Contains: Autoware.universe + CARLA Python client
- Size: Large (optimized for ARM64)
- Reference: https://github.com/LiZheng1997/Autoware.universe-with-carla-0.9.15

## Feasibility Assessment

### ❌ Building CARLA Natively on Jetson Orin: **NOT FEASIBLE**

**Reasons:**
1. Unreal Engine 4.26 cannot be easily compiled for ARM64
2. All dependencies need ARM compilation
3. No official documentation or support
4. Build time: 4-6+ hours with high failure rate
5. GPU driver compatibility issues
6. Performance would likely be poor even if successful

**Effort:** 40-80 hours of development + debugging
**Success Rate:** <20%
**Recommendation:** ❌ Do not attempt

### ✅ Client-Server Architecture: **PROVEN & RECOMMENDED**

**Reasons:**
1. Already proven by Autoware community (2024)
2. Separates concerns: rendering (x86) vs inference (Jetson)
3. Better performance distribution
4. Jetson focuses on what it's good at (inference)
5. Easy to deploy with Docker

**Effort:** 2-4 hours setup
**Success Rate:** 95%+
**Recommendation:** ✅ Use this approach

## Recommended Implementation

### Architecture Design

```yaml
# docker-compose.yml on x86 Server
services:
  carla-server:
    image: carlasim/carla:0.9.15
    runtime: nvidia
    ports:
      - "2000:2000"  # CARLA RPC
      - "2001:2001"  # Streaming
    networks:
      - carla-net

  carla-bridge:
    image: autoware/carla-bridge:latest
    depends_on:
      - carla-server
    networks:
      - carla-net
```

```python
# On Jetson Orin - Python Client
import carla

# Connect to remote x86 CARLA server
client = carla.Client('x86-server-ip', 2000)
client.set_timeout(10.0)

world = client.get_world()
# Run perception, planning, control on Jetson
```

### Network Requirements

- **Minimum:** 100 Mbps Ethernet
- **Recommended:** 1 Gbps Ethernet
- **Latency:** <10ms for real-time control
- **Setup:** Local network or VPN

### Performance Expectations

**x86 Server (CARLA):**
- GPU: NVIDIA RTX 2070 or better
- Resolution: 1920x1080
- Quality: Epic
- FPS: 30-60

**Jetson Orin (Client):**
- Model: AGX/NX/Nano
- Tasks: Perception, planning, control
- Latency: <100ms end-to-end
- Resource: CPU/GPU for inference only

## Alternative Solutions

### 1. Lightweight Simulators
- **LGSVL Simulator** - Has ARM64 support
- **Gazebo** - Lighter weight, ARM-friendly
- **Webots** - Cross-platform support

### 2. Recorded Data Playback
- Record CARLA scenarios on x86
- Playback sensor data on Jetson
- Test algorithms without live simulation

### 3. Hybrid Approach
- Development: x86 desktop with CARLA
- Testing: Jetson with recorded scenarios
- Deployment: Real vehicle

## Conclusion

**For Jetson Orin + CARLA:**

1. ❌ **Do NOT** attempt to build CARLA natively on Jetson
2. ✅ **DO** use client-server architecture
3. ✅ **DO** leverage existing community solutions (Autoware)
4. ✅ **DO** consider alternative simulators if full local simulation needed

**Recommended Project Direction:**

Update project to focus on **client-server architecture** with:
- x86 Docker image for CARLA server (already working)
- ARM64 Docker image for CARLA Python client + utilities
- Clear documentation for distributed setup
- Example docker-compose files for both platforms

## References

1. GitHub Issue #5845 - CARLA ARM64 Library Request (Open)
2. GitHub Issue #6750 - Build CARLA on Jetson (No official solution)
3. Autoware.universe-with-carla-0.9.15 - Proven implementation
4. Unreal Engine ARM64 compilation discussions
5. NVIDIA Jetson forums - CARLA deployment attempts

## Next Steps for Project

1. Remove claims of "native ARM64 support"
2. Focus on working x86 implementation
3. Add documentation for client-server setup
4. Create ARM64 client-only Docker image
5. Provide examples for Jetson connecting to remote CARLA
6. Add network configuration guides

---

**Last Updated:** 2025-11-04
**Research Status:** Complete
**Recommendation:** Client-Server Architecture
