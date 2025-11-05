#!/usr/bin/env bash
# Step 3: CARLA Helper - Interactive Menu
# Manage running CARLA session (maps, vehicles, weather)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HELPER_PY="$SCRIPT_DIR/3-carla-helper.py"

# Check if CARLA is running
check_carla() {
  if ! ss -tlnp 2>/dev/null | grep -q ":2000 " && ! netstat -tlnp 2>/dev/null | grep -q ":2000 "; then
    echo ""
    echo "⚠️  CARLA server not detected on port 2000"
    echo "   Please run: scripts/2-start-carla.sh"
    echo ""
    return 1
  fi
  return 0
}

# Show interactive menu
show_menu() {
  clear
  echo "=========================================="
  echo "  CARLA Interactive Helper"
  echo "=========================================="
  echo ""
  echo "Maps & Environment:"
  echo "  1) List available maps"
  echo "  2) Change map"
  echo "  3) Change weather"
  echo ""
  echo "Vehicles:"
  echo "  4) Spawn vehicle"
  echo "  5) List vehicle types"
  echo "  6) Move camera view"
  echo ""
  echo "Control:"
  echo "  7) Manual driving (keyboard/wheel)"
  echo ""
  echo "  0) Exit"
  echo ""
  echo "=========================================="
  echo -n "Select option: "
}

# Map selection submenu
select_map() {
  echo ""
  echo "Available maps:"
  "$HELPER_PY" --list-maps | nl -w2 -s') '
  echo ""
  echo -n "Enter map name (e.g., Town04) or 'b' to go back: "
  read -r map_choice
  if [[ "$map_choice" != "b" ]]; then
    "$HELPER_PY" --set-map "$map_choice"
  fi
}

# Weather selection submenu
select_weather() {
  echo ""
  echo "Available weather presets:"
  echo "  1) ClearNoon"
  echo "  2) ClearSunset"
  echo "  3) CloudyNoon"
  echo "  4) CloudySunset"
  echo "  5) WetNoon"
  echo "  6) WetSunset"
  echo "  7) HardRainNoon"
  echo "  8) HardRainSunset"
  echo "  9) SoftRainNoon"
  echo " 10) SoftRainSunset"
  echo ""
  echo -n "Select weather (1-10) or 'b' to go back: "
  read -r weather_choice

  case $weather_choice in
    1) "$HELPER_PY" --weather ClearNoon ;;
    2) "$HELPER_PY" --weather ClearSunset ;;
    3) "$HELPER_PY" --weather CloudyNoon ;;
    4) "$HELPER_PY" --weather CloudySunset ;;
    5) "$HELPER_PY" --weather WetNoon ;;
    6) "$HELPER_PY" --weather WetSunset ;;
    7) "$HELPER_PY" --weather HardRainNoon ;;
    8) "$HELPER_PY" --weather HardRainSunset ;;
    9) "$HELPER_PY" --weather SoftRainNoon ;;
    10) "$HELPER_PY" --weather SoftRainSunset ;;
    b) return ;;
    *) echo "Invalid choice" ;;
  esac
}

# Vehicle spawn submenu
spawn_vehicle() {
  echo ""
  echo "Quick vehicle selection:"
  echo "  1) Tesla Model 3"
  echo "  2) Audi TT"
  echo "  3) Mercedes Coupe"
  echo "  4) BMW GrandTourer"
  echo "  5) Dodge Charger Police"
  echo "  6) Custom (enter blueprint ID)"
  echo ""
  echo -n "Select vehicle (1-6) or 'b' to go back: "
  read -r vehicle_choice

  case $vehicle_choice in
    1) vehicle_id="vehicle.tesla.model3" ;;
    2) vehicle_id="vehicle.audi.tt" ;;
    3) vehicle_id="vehicle.mercedes.coupe" ;;
    4) vehicle_id="vehicle.bmw.grandtourer" ;;
    5) vehicle_id="vehicle.dodge.charger_police" ;;
    6)
      echo -n "Enter blueprint ID: "
      read -r vehicle_id
      ;;
    b) return ;;
    *)
      echo "Invalid choice"
      return
      ;;
  esac

  echo ""
  echo "Camera view:"
  echo "  1) Chase (behind vehicle)"
  echo "  2) Front"
  echo "  3) Top"
  echo "  4) Free (no follow)"
  echo ""
  echo -n "Select view (1-4, default: chase): "
  read -r view_choice

  case $view_choice in
    1|"") view="chase" ;;
    2) view="front" ;;
    3) view="top" ;;
    4) view="free" ;;
    *) view="chase" ;;
  esac

  "$HELPER_PY" --spawn "$vehicle_id" --view "$view"
}

# Camera view submenu
move_camera() {
  echo ""
  echo "Camera views:"
  echo "  1) Chase (behind vehicle)"
  echo "  2) Front"
  echo "  3) Top"
  echo "  4) Free"
  echo ""
  echo -n "Select view (1-4) or 'b' to go back: "
  read -r view_choice

  case $view_choice in
    1) "$HELPER_PY" --view chase ;;
    2) "$HELPER_PY" --view front ;;
    3) "$HELPER_PY" --view top ;;
    4) "$HELPER_PY" --view free ;;
    b) return ;;
    *) echo "Invalid choice" ;;
  esac
}

# Main interactive loop
interactive_mode() {
  if ! check_carla; then
    exit 1
  fi

  while true; do
    show_menu
    read -r choice

    case $choice in
      1)
        echo ""
        "$HELPER_PY" --list-maps
        echo ""
        read -p "Press Enter to continue..."
        ;;
      2)
        select_map
        echo ""
        read -p "Press Enter to continue..."
        ;;
      3)
        select_weather
        echo ""
        read -p "Press Enter to continue..."
        ;;
      4)
        spawn_vehicle
        echo ""
        read -p "Press Enter to continue..."
        ;;
      5)
        echo ""
        "$HELPER_PY" --list-vehicles
        echo ""
        read -p "Press Enter to continue..."
        ;;
      6)
        move_camera
        echo ""
        read -p "Press Enter to continue..."
        ;;
      7)
        echo ""
        echo "Launching manual control (press Q or ESC to exit)..."
        echo ""
        "$HELPER_PY" --manual
        echo ""
        read -p "Press Enter to continue..."
        ;;
      0)
        echo ""
        echo "Goodbye!"
        exit 0
        ;;
      *)
        echo ""
        echo "Invalid option"
        sleep 1
        ;;
    esac
  done
}

# Check if Python helper exists
if [[ ! -x "$HELPER_PY" ]]; then
  echo "Error: Python helper not found at $HELPER_PY"
  exit 1
fi

# If arguments provided, pass through to Python helper
if [[ $# -gt 0 ]]; then
  exec "$HELPER_PY" "$@"
else
  # No arguments, run interactive mode
  interactive_mode
fi
