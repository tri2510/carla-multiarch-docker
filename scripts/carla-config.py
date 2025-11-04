#!/usr/bin/env python3
"""
CARLA Configuration Helper
Interactive tool to configure CARLA settings, weather, traffic, and more
"""

import os
import sys
import yaml
import argparse
from pathlib import Path


class CarlaConfigHelper:
    def __init__(self, config_dir="/home/carla/configs"):
        self.config_dir = Path(config_dir)
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.config_file = self.config_dir / "carla_settings.yaml"
        self.load_config()

    def load_config(self):
        """Load existing configuration or create default"""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                self.config = yaml.safe_load(f) or {}
        else:
            self.config = self.get_default_config()
            self.save_config()

    def save_config(self):
        """Save configuration to file"""
        with open(self.config_file, 'w') as f:
            yaml.dump(self.config, f, default_flow_style=False, sort_keys=False)
        print(f"\nConfiguration saved to: {self.config_file}")

    def get_default_config(self):
        """Get default CARLA configuration"""
        return {
            'server': {
                'host': 'localhost',
                'port': 2000,
                'timeout': 10.0,
            },
            'graphics': {
                'quality': 'Epic',  # Low, Medium, High, Epic
                'resolution': {
                    'width': 1920,
                    'height': 1080,
                },
                'rendering_mode': 'window',  # window, offscreen
                'fps': 30,
                'vsync': True,
            },
            'world': {
                'map': 'Town03',  # Town01-Town12, etc.
                'weather': 'ClearNoon',
                'sync_mode': True,
                'fixed_delta_seconds': 0.05,
            },
            'traffic': {
                'enabled': False,
                'number_of_vehicles': 50,
                'number_of_walkers': 50,
                'safe': True,
                'hybrid_mode': True,
            },
            'spectator': {
                'follow_vehicle': True,
                'camera_height': 5.0,
                'camera_distance': 10.0,
            },
            'controller': {
                'type': 'logitech_g29',
                'deadzone': 0.05,
                'sensitivity': 1.0,
                'force_feedback': True,
            },
            'sensors': {
                'rgb_camera': {
                    'enabled': True,
                    'width': 1920,
                    'height': 1080,
                    'fov': 90,
                },
                'depth_camera': {
                    'enabled': False,
                    'width': 1920,
                    'height': 1080,
                },
                'semantic_camera': {
                    'enabled': False,
                    'width': 1920,
                    'height': 1080,
                },
                'lidar': {
                    'enabled': False,
                    'channels': 32,
                    'range': 100,
                    'points_per_second': 100000,
                },
                'radar': {
                    'enabled': False,
                    'range': 100,
                },
                'gnss': {
                    'enabled': False,
                },
                'imu': {
                    'enabled': False,
                },
            },
        }

    def interactive_setup(self):
        """Interactive configuration setup"""
        print("=" * 60)
        print("CARLA Configuration Helper - Interactive Setup")
        print("=" * 60)
        print()

        # Server settings
        print("=== Server Settings ===")
        host = input(f"Server host [{self.config['server']['host']}]: ").strip()
        if host:
            self.config['server']['host'] = host

        port = input(f"Server port [{self.config['server']['port']}]: ").strip()
        if port:
            self.config['server']['port'] = int(port)

        # Graphics settings
        print("\n=== Graphics Settings ===")
        print("Quality options: Low, Medium, High, Epic")
        quality = input(f"Quality [{self.config['graphics']['quality']}]: ").strip()
        if quality:
            self.config['graphics']['quality'] = quality

        res_width = input(f"Resolution width [{self.config['graphics']['resolution']['width']}]: ").strip()
        if res_width:
            self.config['graphics']['resolution']['width'] = int(res_width)

        res_height = input(f"Resolution height [{self.config['graphics']['resolution']['height']}]: ").strip()
        if res_height:
            self.config['graphics']['resolution']['height'] = int(res_height)

        # World settings
        print("\n=== World Settings ===")
        print("Available maps: Town01, Town02, Town03, Town04, Town05, Town10HD")
        map_name = input(f"Map [{self.config['world']['map']}]: ").strip()
        if map_name:
            self.config['world']['map'] = map_name

        print("\nWeather presets: ClearNoon, CloudyNoon, WetNoon, WetCloudyNoon,")
        print("                 SoftRainNoon, MidRainyNoon, HardRainNoon,")
        print("                 ClearSunset, CloudySunset, WetSunset, WetCloudySunset")
        weather = input(f"Weather [{self.config['world']['weather']}]: ").strip()
        if weather:
            self.config['world']['weather'] = weather

        # Traffic settings
        print("\n=== Traffic Settings ===")
        traffic = input(f"Enable traffic? (y/n) [{self.config['traffic']['enabled']}]: ").strip().lower()
        if traffic == 'y':
            self.config['traffic']['enabled'] = True
            vehicles = input(f"Number of vehicles [{self.config['traffic']['number_of_vehicles']}]: ").strip()
            if vehicles:
                self.config['traffic']['number_of_vehicles'] = int(vehicles)

            walkers = input(f"Number of walkers [{self.config['traffic']['number_of_walkers']}]: ").strip()
            if walkers:
                self.config['traffic']['number_of_walkers'] = int(walkers)
        elif traffic == 'n':
            self.config['traffic']['enabled'] = False

        # Controller settings
        print("\n=== Controller Settings ===")
        print("Controller types: logitech_g27, logitech_g29, logitech_g920, generic")
        controller = input(f"Controller type [{self.config['controller']['type']}]: ").strip()
        if controller:
            self.config['controller']['type'] = controller

        ff = input(f"Enable force feedback? (y/n) [{self.config['controller']['force_feedback']}]: ").strip().lower()
        if ff == 'y':
            self.config['controller']['force_feedback'] = True
        elif ff == 'n':
            self.config['controller']['force_feedback'] = False

        # Save configuration
        self.save_config()
        print("\n" + "=" * 60)
        print("Configuration complete!")
        print("=" * 60)

    def show_config(self):
        """Display current configuration"""
        print("\n" + "=" * 60)
        print("Current CARLA Configuration")
        print("=" * 60)
        print(yaml.dump(self.config, default_flow_style=False, sort_keys=False))
        print("=" * 60)

    def export_env(self):
        """Export configuration as environment variables"""
        print("\n# CARLA Environment Variables")
        print(f"export CARLA_HOST={self.config['server']['host']}")
        print(f"export CARLA_PORT={self.config['server']['port']}")
        print(f"export CARLA_QUALITY={self.config['graphics']['quality']}")
        print(f"export CARLA_RES_X={self.config['graphics']['resolution']['width']}")
        print(f"export CARLA_RES_Y={self.config['graphics']['resolution']['height']}")
        print(f"export CARLA_MAP={self.config['world']['map']}")
        print(f"export CARLA_WEATHER={self.config['world']['weather']}")

    def quick_presets(self):
        """Show and apply quick configuration presets"""
        print("\n" + "=" * 60)
        print("Quick Configuration Presets")
        print("=" * 60)
        print("1. High Performance (Low quality, high FPS)")
        print("2. Balanced (Medium quality)")
        print("3. Visual Quality (Epic quality, lower FPS)")
        print("4. Jetson Optimized (Optimized for Jetson Orin)")
        print("5. Development (Quick iterations)")
        print("0. Cancel")
        print()

        choice = input("Select preset: ").strip()

        if choice == '1':
            self.config['graphics']['quality'] = 'Low'
            self.config['graphics']['resolution'] = {'width': 1280, 'height': 720}
            self.config['graphics']['fps'] = 60
            self.config['traffic']['number_of_vehicles'] = 20
            print("Applied: High Performance preset")

        elif choice == '2':
            self.config['graphics']['quality'] = 'Medium'
            self.config['graphics']['resolution'] = {'width': 1920, 'height': 1080}
            self.config['graphics']['fps'] = 30
            self.config['traffic']['number_of_vehicles'] = 50
            print("Applied: Balanced preset")

        elif choice == '3':
            self.config['graphics']['quality'] = 'Epic'
            self.config['graphics']['resolution'] = {'width': 1920, 'height': 1080}
            self.config['graphics']['fps'] = 30
            self.config['traffic']['number_of_vehicles'] = 50
            print("Applied: Visual Quality preset")

        elif choice == '4':
            self.config['graphics']['quality'] = 'Medium'
            self.config['graphics']['resolution'] = {'width': 1280, 'height': 720}
            self.config['graphics']['fps'] = 30
            self.config['traffic']['number_of_vehicles'] = 30
            self.config['world']['sync_mode'] = True
            print("Applied: Jetson Optimized preset")

        elif choice == '5':
            self.config['graphics']['quality'] = 'Low'
            self.config['graphics']['resolution'] = {'width': 800, 'height': 600}
            self.config['graphics']['rendering_mode'] = 'offscreen'
            self.config['traffic']['enabled'] = False
            print("Applied: Development preset")

        if choice in ['1', '2', '3', '4', '5']:
            self.save_config()


def main():
    parser = argparse.ArgumentParser(description="CARLA Configuration Helper")
    parser.add_argument('--interactive', '-i', action='store_true',
                        help='Interactive configuration setup')
    parser.add_argument('--show', '-s', action='store_true',
                        help='Show current configuration')
    parser.add_argument('--export', '-e', action='store_true',
                        help='Export as environment variables')
    parser.add_argument('--presets', '-p', action='store_true',
                        help='Show and apply quick presets')
    parser.add_argument('--config-dir', default='/home/carla/configs',
                        help='Configuration directory')

    args = parser.parse_args()

    helper = CarlaConfigHelper(config_dir=args.config_dir)

    if args.interactive:
        helper.interactive_setup()
    elif args.show:
        helper.show_config()
    elif args.export:
        helper.export_env()
    elif args.presets:
        helper.quick_presets()
    else:
        # Default: show menu
        while True:
            print("\n" + "=" * 60)
            print("CARLA Configuration Helper")
            print("=" * 60)
            print("1. Interactive Setup")
            print("2. Show Current Configuration")
            print("3. Quick Presets")
            print("4. Export Environment Variables")
            print("0. Exit")
            print()

            choice = input("Select option: ").strip()

            if choice == '1':
                helper.interactive_setup()
            elif choice == '2':
                helper.show_config()
            elif choice == '3':
                helper.quick_presets()
            elif choice == '4':
                helper.export_env()
            elif choice == '0':
                print("Goodbye!")
                break
            else:
                print("Invalid choice, try again")


if __name__ == '__main__':
    main()
