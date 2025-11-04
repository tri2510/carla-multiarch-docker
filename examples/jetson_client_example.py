#!/usr/bin/env python3
"""
CARLA Client Example for Jetson Orin
Connects to remote x86 CARLA server and demonstrates basic operations
"""

import os
import sys
import time
import carla


def main():
    # Get server configuration from environment
    host = os.getenv('CARLA_SERVER_HOST', '192.168.1.100')
    port = int(os.getenv('CARLA_SERVER_PORT', '2000'))

    print("=" * 60)
    print("CARLA Jetson Client Example")
    print("=" * 60)
    print(f"Connecting to CARLA server at {host}:{port}")
    print()

    try:
        # Connect to CARLA server
        client = carla.Client(host, port)
        client.set_timeout(10.0)

        # Get world
        world = client.get_world()
        print(f"✅ Connected to CARLA server")
        print(f"   Server version: {client.get_server_version()}")
        print(f"   Map: {world.get_map().name}")
        print()

        # Get available maps
        available_maps = client.get_available_maps()
        print(f"Available maps ({len(available_maps)}):")
        for map_name in available_maps[:5]:  # Show first 5
            print(f"  - {map_name}")
        print()

        # Spawn a vehicle
        print("Spawning vehicle...")
        blueprint_library = world.get_blueprint_library()
        vehicle_bp = blueprint_library.filter('vehicle.tesla.model3')[0]

        spawn_points = world.get_map().get_spawn_points()
        if spawn_points:
            spawn_point = spawn_points[0]
            vehicle = world.spawn_actor(vehicle_bp, spawn_point)
            print(f"✅ Spawned vehicle: {vehicle.type_id}")
            print(f"   Location: {spawn_point.location}")
            print()

            # Enable autopilot
            vehicle.set_autopilot(True)
            print("✅ Autopilot enabled")
            print()

            # Monitor vehicle for a few seconds
            print("Monitoring vehicle (10 seconds)...")
            for i in range(10):
                transform = vehicle.get_transform()
                velocity = vehicle.get_velocity()
                speed = 3.6 * (velocity.x**2 + velocity.y**2 + velocity.z**2)**0.5

                print(f"  [{i+1}/10] Speed: {speed:.1f} km/h | "
                      f"Location: ({transform.location.x:.1f}, "
                      f"{transform.location.y:.1f})")
                time.sleep(1)

            print()

            # Cleanup
            print("Cleaning up...")
            vehicle.destroy()
            print("✅ Vehicle destroyed")

        else:
            print("⚠️  No spawn points available")

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

    print()
    print("=" * 60)
    print("Example completed successfully!")
    print("=" * 60)


if __name__ == '__main__':
    main()
