#!/usr/bin/env python3.7
"""Simple CARLA telemetry demo: prints vehicle pose and control each tick."""

import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CARLA_ROOT = PROJECT_ROOT / "local_carla"
EGG_DIR = CARLA_ROOT / "PythonAPI" / "carla" / "dist"

try:
    egg = max(EGG_DIR.glob("carla-*.egg"))
except ValueError:
    sys.exit("CARLA egg not found; run scripts/1-setup-carla.sh")

sys.path.append(str(egg))
import carla  # type: ignore

client = carla.Client("127.0.0.1", 2000)
client.set_timeout(5.0)
world = client.get_world()

vehicle = None
actors = world.get_actors().filter("vehicle.*")
for actor in actors:
    if actor.attributes.get("role_name") == "hero" or "tesla" in actor.type_id:
        vehicle = actor
        break

if vehicle is None:
    vehicle = actors[0] if actors else None

if vehicle is None:
    sys.exit("No vehicle found in simulation")

print(f"Tracking {vehicle.type_id} (id={vehicle.id})")

last_time = time.time()

def on_tick(snapshot: carla.WorldSnapshot) -> None:
    global last_time
    transform = vehicle.get_transform()
    velocity = vehicle.get_velocity()
    control = vehicle.get_control()
    now = time.time()
    dt = now - last_time
    last_time = now
    print(
        f"frame={snapshot.frame:>6} | t={snapshot.timestamp.platform_timestamp:6.2f}s | "
        f"pos=({transform.location.x:7.2f}, {transform.location.y:7.2f}, {transform.location.z:5.2f}) | "
        f"speed={3.6 * (velocity.length()):6.2f} km/h | "
        f"ctrl(thr={control.throttle:.2f}, brk={control.brake:.2f}, steer={control.steer:.2f}, gear={control.gear})"
    )

world.on_tick(on_tick)
print("Press Ctrl+C to stop...")
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    pass
finally:
    world.remove_on_tick(on_tick)
