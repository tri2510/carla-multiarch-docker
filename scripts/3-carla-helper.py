#!/usr/bin/env python3
"""Step 3: CARLA Helper - Manage Running CARLA Session

This helper lets you control a running CARLA simulator (started with 2-start-carla.sh).

Features:
  * List and switch maps (Town01, Town02, etc.)
  * Spawn/destroy vehicles with custom blueprints and colors
  * Change weather presets (ClearNoon, HardRainSunset, etc.)
  * Move spectator camera (chase/front/top views)
  * Launch manual control for keyboard/wheel driving

The helper connects to a running CARLA simulator (any CARLA 0.9.x server).
"""

from __future__ import annotations

import argparse
import os
import random
import subprocess
import sys
import time
from pathlib import Path
from typing import Iterable, List, Optional

DEFAULT_ROLE_NAME = "hero"
CARLA_ROOT = Path(__file__).resolve().parents[1] / "local_carla"
PY_API_DIST = CARLA_ROOT / "PythonAPI" / "carla" / "dist"
PY_API_SOURCE = CARLA_ROOT / "PythonAPI" / "carla"
EXAMPLES_DIR = CARLA_ROOT / "PythonAPI" / "examples"


def ensure_carla_on_path() -> None:
    if not CARLA_ROOT.exists():
        print("[helper] local_carla directory is missing; run scripts/1-setup-carla.sh first", file=sys.stderr)
        sys.exit(2)
    eggs = sorted(PY_API_DIST.glob("carla-*.egg"))
    if not eggs:
        print(f"[helper] No CARLA egg found under {PY_API_DIST}", file=sys.stderr)
        sys.exit(2)
    sys.path.append(str(eggs[-1]))
    sys.path.append(str(PY_API_SOURCE))


ensure_carla_on_path()

try:
    import carla  # type: ignore
except ModuleNotFoundError as exc:  # pragma: no cover
    print(f"[helper] Failed to import CARLA Python API: {exc}", file=sys.stderr)
    sys.exit(2)


WEATHER_PRESETS = {
    "ClearNoon": carla.WeatherParameters.ClearNoon,
    "ClearSunset": carla.WeatherParameters.ClearSunset,
    "CloudyNoon": carla.WeatherParameters.CloudyNoon,
    "CloudySunset": carla.WeatherParameters.CloudySunset,
    "WetNoon": carla.WeatherParameters.WetNoon,
    "WetSunset": carla.WeatherParameters.WetSunset,
    "MidRainyNoon": carla.WeatherParameters.MidRainyNoon,
    "MidRainSunset": carla.WeatherParameters.MidRainSunset,
    "HardRainNoon": carla.WeatherParameters.HardRainNoon,
    "HardRainSunset": carla.WeatherParameters.HardRainSunset,
    "SoftRainNoon": carla.WeatherParameters.SoftRainNoon,
    "SoftRainSunset": carla.WeatherParameters.SoftRainSunset,
}


VIEW_CHOICES = ["chase", "front", "top", "free"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Step 3: CARLA Helper - Manage running CARLA session",
        epilog="Make sure CARLA is running (use 2-start-carla.sh first)"
    )
    parser.add_argument("action", nargs="*", help="Optional description of planned actions (for logging only)")
    parser.add_argument("--host", default="127.0.0.1", help="CARLA host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=2000, help="RPC port (default: 2000)")
    parser.add_argument("--timeout", type=float, default=8.0, help="RPC timeout seconds")

    parser.add_argument("--list-maps", action="store_true")
    parser.add_argument("--set-map", metavar="TOWN", help="Load a specific Town (e.g. Town04)")
    parser.add_argument("--list-vehicles", action="store_true", help="Print matching vehicle blueprints")
    parser.add_argument("--vehicle-filter", default="vehicle.*", help="Blueprint filter when listing/spawning")

    parser.add_argument("--spawn", metavar="BLUEPRINT", help="Spawn/replace hero vehicle with blueprint id")
    parser.add_argument("--spawn-color", metavar="R,G,B", help="Set vehicle color (if supported)")
    parser.add_argument("--respawn-hero", action="store_true", help="Remove existing hero before applying other actions")
    parser.add_argument("--autopilot", choices=["on", "off"], help="Toggle autopilot on hero vehicle")

    parser.add_argument("--weather", choices=sorted(WEATHER_PRESETS.keys()), help="Apply a predefined weather preset")
    parser.add_argument("--view", choices=VIEW_CHOICES, help="Move spectator to a common viewpoint")
    parser.add_argument("--manual", action="store_true", help="Launch PythonAPI/examples/manual_control.py")
    parser.add_argument("--manual-args", nargs=argparse.REMAINDER, help="Arguments forwarded to manual_control.py after --")
    parser.add_argument("--role-name", default=DEFAULT_ROLE_NAME, help="Vehicle role_name to manage (default hero)")
    parser.add_argument("--spawn-index", type=int, default=-1, help="Spawn point index to use (default random)")

    return parser.parse_args()


def connect(host: str, port: int, timeout: float) -> carla.Client:
    client = carla.Client(host, port)
    client.set_timeout(timeout)
    return client


def list_maps(client: carla.Client) -> None:
    print("Available maps:")
    for idx, town in enumerate(client.get_available_maps()):
        print(f"  [{idx:02d}] {town}")


def list_vehicles(world: carla.World, bp_filter: str) -> None:
    print(f"Vehicle blueprints matching '{bp_filter}':")
    for bp in world.get_blueprint_library().filter(bp_filter):
        print(f"  - {bp.id}")


def get_spawn_point(world: carla.World, index: int) -> carla.Transform:
    spawn_points = world.get_map().get_spawn_points()
    if not spawn_points:
        raise RuntimeError("Map has no spawn points")
    if index >= 0:
        return spawn_points[index % len(spawn_points)]
    return random.choice(spawn_points)


def destroy_actor(actor: Optional[carla.Actor]) -> None:
    if actor is not None:
        actor.destroy()


def find_vehicle(world: carla.World, role_name: str) -> Optional[carla.Vehicle]:
    actors = world.get_actors().filter("vehicle.*")
    for actor in actors:
        if actor.attributes.get("role_name") == role_name:
            return actor  # type: ignore[return-value]
    return None


def spawn_vehicle(world: carla.World, bp_id: str, role_name: str, spawn_idx: int, color: Optional[str]) -> carla.Vehicle:
    bp_lib = world.get_blueprint_library()
    matches = bp_lib.filter(bp_id)
    if not matches:
        raise RuntimeError(f"No blueprint matches '{bp_id}'")
    blueprint = matches[0]
    if blueprint.has_attribute("role_name"):
        blueprint.set_attribute("role_name", role_name)
    if color and blueprint.has_attribute("color"):
        blueprint.set_attribute("color", color)
    transform = get_spawn_point(world, spawn_idx)
    vehicle = world.try_spawn_actor(blueprint, transform)
    if vehicle is None:
        raise RuntimeError("Failed to spawn vehicle (all spawn points occupied?)")
    print(f"Spawned {vehicle.type_id} at {transform.location}")
    return vehicle


def apply_weather(world: carla.World, preset: str) -> None:
    weather = WEATHER_PRESETS[preset]
    world.set_weather(weather)
    print(f"Applied weather preset: {preset}")


def set_view(world: carla.World, hero: Optional[carla.Vehicle], mode: str) -> None:
    spectator = world.get_spectator()
    if mode == "free" or hero is None:
        spectator.set_transform(spectator.get_transform())
        if hero is None and mode != "free":
            print("[helper] No hero vehicle; spectator left unchanged")
        return
    transform = hero.get_transform()
    if mode == "chase":
        transform.location += carla.Location(x=-8, z=3)
        transform.rotation.pitch = -10
    elif mode == "front":
        transform.location += carla.Location(x=8, z=2)
        transform.rotation.yaw += 180
        transform.rotation.pitch = -5
    elif mode == "top":
        transform.location += carla.Location(z=40)
        transform.rotation.pitch = -90
    spectator.set_transform(transform)
    print(f"Moved spectator to {mode} view")


def run_manual_control(extra_args: Optional[List[str]]) -> None:
    manual = EXAMPLES_DIR / "manual_control.py"
    if not manual.exists():
        raise RuntimeError(f"manual_control.py not found at {manual}")
    env = os.environ.copy()
    py_paths = [env.get("PYTHONPATH", ""), str(PY_API_SOURCE), str(PY_API_DIST)]
    env["PYTHONPATH"] = os.pathsep.join(filter(None, py_paths))
    cmd = [sys.executable, str(manual)]
    if extra_args:
        if extra_args and extra_args[0] == "--":
            extra_args = extra_args[1:]
        cmd.extend(extra_args)
    print("[helper] Starting manual_control.py", " ".join(cmd))
    subprocess.run(cmd, env=env, check=False)


def main() -> None:
    args = parse_args()
    client = connect(args.host, args.port, args.timeout)

    if args.list_maps:
        list_maps(client)

    world = client.get_world()
    if args.set_map:
        if args.set_map not in client.get_available_maps():
            raise RuntimeError(f"Unknown map {args.set_map}; run with --list-maps")
        world = client.load_world(args.set_map)
        time.sleep(1.0)

    if args.list_vehicles:
        list_vehicles(world, args.vehicle_filter)

    hero = None
    if args.respawn_hero:
        hero = find_vehicle(world, args.role_name)
        if hero:
            print(f"Destroying existing {args.role_name} ({hero.type_id})")
            destroy_actor(hero)
            hero = None

    if args.spawn:
        hero = spawn_vehicle(world, args.spawn, args.role_name, args.spawn_index, args.spawn_color)
    else:
        hero = find_vehicle(world, args.role_name)

    if args.autopilot and hero:
        hero.set_autopilot(args.autopilot == "on")
        print(f"Autopilot {'enabled' if args.autopilot == 'on' else 'disabled'} for {hero.type_id}")

    if args.weather:
        apply_weather(world, args.weather)

    if args.view:
        set_view(world, hero, args.view)

    if args.manual:
        run_manual_control(args.manual_args)

    if not any([
        args.list_maps,
        args.set_map,
        args.list_vehicles,
        args.spawn,
        args.respawn_hero,
        args.autopilot,
        args.weather,
        args.view,
        args.manual,
    ]):
        print("No actions requested; use --help for options.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover
        print(f"[helper][ERROR] {exc}", file=sys.stderr)
        sys.exit(1)
