#!/usr/bin/env python3
"""
CARLA Manual Control with Logitech Wheel Support
Enhanced version of the manual_control.py example with full wheel support
"""

import glob
import os
import sys
import pygame
import numpy as np

try:
    sys.path.append(glob.glob('../carla/dist/carla-*%d.%d-%s.egg' % (
        sys.version_info.major,
        sys.version_info.minor,
        'win-amd64' if os.name == 'nt' else 'linux-x86_64'))[0])
except IndexError:
    pass

import carla

# Try to import inputs library for better controller support
try:
    from inputs import get_gamepad, devices
    INPUTS_AVAILABLE = True
except ImportError:
    INPUTS_AVAILABLE = False
    print("Warning: 'inputs' library not available. Install with: pip install inputs")


class WheelControl:
    """Handle Logitech wheel input"""

    def __init__(self):
        pygame.joystick.init()
        self.joystick = None
        self.steering = 0.0
        self.throttle = 0.0
        self.brake = 0.0
        self.clutch = 0.0
        self.reverse = False
        self.handbrake = False

        # Detect and initialize wheel
        joystick_count = pygame.joystick.get_count()
        if joystick_count > 0:
            self.joystick = pygame.joystick.Joystick(0)
            self.joystick.init()
            print(f"Detected controller: {self.joystick.get_name()}")
            print(f"Axes: {self.joystick.get_numaxes()}")
            print(f"Buttons: {self.joystick.get_numbuttons()}")

            # Detect wheel type
            name = self.joystick.get_name().lower()
            if 'g29' in name or 'g920' in name:
                self.wheel_type = 'g29'
            elif 'g27' in name:
                self.wheel_type = 'g27'
            elif 'driving force' in name:
                self.wheel_type = 'dfgt'
            else:
                self.wheel_type = 'generic'

            print(f"Detected wheel type: {self.wheel_type}")
            self.setup_mappings()
        else:
            print("No wheel detected, falling back to keyboard")
            self.wheel_type = None

    def setup_mappings(self):
        """Setup button and axis mappings for different wheel types"""
        if self.wheel_type == 'g29' or self.wheel_type == 'g920':
            # Logitech G29/G920 mappings
            self.axis_steering = 0
            self.axis_throttle = 2  # Right pedal
            self.axis_brake = 1     # Middle pedal
            self.axis_clutch = 3    # Left pedal

            self.button_shift_up = 4
            self.button_shift_down = 5
            self.button_reverse = 6
            self.button_handbrake = 7

        elif self.wheel_type == 'g27':
            # Logitech G27 mappings
            self.axis_steering = 0
            self.axis_throttle = 1
            self.axis_brake = 2
            self.axis_clutch = 3

            self.button_shift_up = 4
            self.button_shift_down = 5
            self.button_reverse = 6
            self.button_handbrake = 7

        else:
            # Generic mappings
            self.axis_steering = 0
            self.axis_throttle = 1
            self.axis_brake = 2
            self.axis_clutch = 3

            self.button_shift_up = 4
            self.button_shift_down = 5
            self.button_reverse = 6
            self.button_handbrake = 7

    def parse_input(self):
        """Parse wheel input and return control values"""
        if not self.joystick:
            return None

        # Read axes
        # Steering: -1 (left) to 1 (right)
        self.steering = self.joystick.get_axis(self.axis_steering)

        # Throttle: -1 (released) to 1 (pressed) - need to normalize to 0-1
        throttle_raw = self.joystick.get_axis(self.axis_throttle)
        self.throttle = (1.0 - throttle_raw) / 2.0  # Convert -1~1 to 0~1

        # Brake: -1 (released) to 1 (pressed) - need to normalize to 0-1
        brake_raw = self.joystick.get_axis(self.axis_brake)
        self.brake = (1.0 - brake_raw) / 2.0  # Convert -1~1 to 0~1

        # Clutch (if available)
        if self.joystick.get_numaxes() > self.axis_clutch:
            clutch_raw = self.joystick.get_axis(self.axis_clutch)
            self.clutch = (1.0 - clutch_raw) / 2.0

        # Read buttons
        if self.joystick.get_numbuttons() > self.button_reverse:
            if self.joystick.get_button(self.button_reverse):
                self.reverse = not self.reverse

        if self.joystick.get_numbuttons() > self.button_handbrake:
            self.handbrake = self.joystick.get_button(self.button_handbrake)

        return carla.VehicleControl(
            throttle=self.throttle,
            steer=self.steering,
            brake=self.brake,
            hand_brake=self.handbrake,
            reverse=self.reverse
        )


class CarlaManualControl:
    """Main control class for CARLA with wheel support"""

    def __init__(self, host='localhost', port=2000):
        self.client = None
        self.world = None
        self.vehicle = None
        self.camera = None
        self.display = None
        self.wheel = None

        # Connect to CARLA
        print(f"Connecting to CARLA at {host}:{port}")
        self.client = carla.Client(host, port)
        self.client.set_timeout(10.0)
        self.world = self.client.get_world()

        print(f"Connected! Current map: {self.world.get_map().name}")

        # Initialize pygame
        pygame.init()
        self.display = pygame.display.set_mode((800, 600))
        pygame.display.set_caption('CARLA Manual Control')

        # Initialize wheel
        self.wheel = WheelControl()

    def spawn_vehicle(self):
        """Spawn a vehicle in the world"""
        blueprint_library = self.world.get_blueprint_library()

        # Choose a vehicle
        vehicle_bp = blueprint_library.filter('vehicle.tesla.model3')[0]

        # Get a spawn point
        spawn_points = self.world.get_map().get_spawn_points()
        spawn_point = spawn_points[0] if spawn_points else carla.Transform()

        # Spawn the vehicle
        self.vehicle = self.world.spawn_actor(vehicle_bp, spawn_point)
        print(f"Spawned vehicle: {vehicle_bp.id}")

        return self.vehicle

    def setup_camera(self):
        """Setup third-person camera"""
        blueprint_library = self.world.get_blueprint_library()
        camera_bp = blueprint_library.find('sensor.camera.rgb')
        camera_bp.set_attribute('image_size_x', '800')
        camera_bp.set_attribute('image_size_y', '600')

        # Attach camera behind vehicle
        camera_transform = carla.Transform(carla.Location(x=-5, z=3))
        self.camera = self.world.spawn_actor(camera_bp, camera_transform,
                                             attach_to=self.vehicle)

        # Setup camera callback
        self.camera.listen(lambda image: self.process_image(image))

    def process_image(self, image):
        """Process camera image and display"""
        array = np.frombuffer(image.raw_data, dtype=np.dtype("uint8"))
        array = np.reshape(array, (image.height, image.width, 4))
        array = array[:, :, :3]
        array = array[:, :, ::-1]  # BGR to RGB

        surface = pygame.surfarray.make_surface(array.swapaxes(0, 1))
        self.display.blit(surface, (0, 0))
        pygame.display.flip()

    def run(self):
        """Main control loop"""
        if not self.vehicle:
            self.spawn_vehicle()

        self.setup_camera()

        clock = pygame.time.Clock()
        running = True

        print("\n" + "=" * 60)
        print("CARLA Manual Control - Logitech Wheel")
        print("=" * 60)
        print("Controls:")
        print("  Steering Wheel - Steer")
        print("  Right Pedal    - Throttle")
        print("  Middle Pedal   - Brake")
        print("  Left Pedal     - Clutch")
        print("  Button 6       - Toggle Reverse")
        print("  Button 7       - Handbrake")
        print("  ESC/Q          - Quit")
        print("=" * 60)

        while running:
            clock.tick(60)  # 60 FPS

            # Handle events
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE or event.key == pygame.K_q:
                        running = False

            # Get wheel input
            control = self.wheel.parse_input()

            # Apply control to vehicle
            if control and self.vehicle:
                self.vehicle.apply_control(control)

                # Display info
                velocity = self.vehicle.get_velocity()
                speed = 3.6 * np.sqrt(velocity.x**2 + velocity.y**2 + velocity.z**2)

                # Draw HUD
                font = pygame.font.Font(None, 36)
                hud_text = [
                    f"Speed: {speed:.1f} km/h",
                    f"Steering: {self.wheel.steering:.2f}",
                    f"Throttle: {self.wheel.throttle:.2f}",
                    f"Brake: {self.wheel.brake:.2f}",
                    f"Reverse: {'ON' if self.wheel.reverse else 'OFF'}",
                ]

                y_offset = 10
                for text in hud_text:
                    surface = font.render(text, True, (255, 255, 255))
                    self.display.blit(surface, (10, y_offset))
                    y_offset += 40

        # Cleanup
        self.cleanup()

    def cleanup(self):
        """Clean up resources"""
        print("Cleaning up...")
        if self.camera:
            self.camera.destroy()
        if self.vehicle:
            self.vehicle.destroy()
        pygame.quit()
        print("Done!")


def main():
    import argparse

    parser = argparse.ArgumentParser(description='CARLA Manual Control with Wheel')
    parser.add_argument('--host', default='localhost', help='CARLA server host')
    parser.add_argument('--port', type=int, default=2000, help='CARLA server port')

    args = parser.parse_args()

    try:
        controller = CarlaManualControl(host=args.host, port=args.port)
        controller.run()
    except KeyboardInterrupt:
        print("\nCancelled by user")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
