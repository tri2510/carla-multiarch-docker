#!/usr/bin/env bash
# Step 3: CARLA Helper - Interactive Menu
# Manage running CARLA session (maps, vehicles, weather)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HELPER_PY="$SCRIPT_DIR/3-carla-helper.py"

# Detect wheel availability via pygame (returns 0 if at least one joystick)
wheel_detected() {
  python3 - <<'PY' >/dev/null 2>&1
import pygame
pygame.init()
pygame.joystick.init()
import sys
sys.exit(0 if pygame.joystick.get_count() > 0 else 1)
PY
}

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
  echo "  7) Manual driving (Logitech wheel)"
  echo ""
  echo "Settings:"
  echo "  8) Change quality (restart CARLA)"
  echo "  9) Manual driving (keyboard)"
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

  # Get maps and store in array (use --raw for clean output)
  mapfile -t maps < <("$HELPER_PY" --list-maps --raw)

  # Display with numbers
  local i=1
  for map in "${maps[@]}"; do
    echo "  $i) $(echo "$map" | sed 's|/Game/Carla/Maps/||')"
    ((i++))
  done

  echo ""
  echo -n "Select map number (1-${#maps[@]}) or 'b' to go back: "
  read -r map_choice

  if [[ "$map_choice" == "b" ]]; then
    return
  fi

  # Validate number
  if [[ "$map_choice" =~ ^[0-9]+$ ]] && [ "$map_choice" -ge 1 ] && [ "$map_choice" -le "${#maps[@]}" ]; then
    local selected_map="${maps[$((map_choice - 1))]}"
    echo ""
    echo "Loading $(echo "$selected_map" | sed 's|/Game/Carla/Maps/||')..."
    "$HELPER_PY" --set-map "$selected_map"
    if [ $? -eq 0 ]; then
      echo "✓ Map changed successfully!"
    else
      echo "✗ Failed to change map"
    fi
  else
    echo "Invalid selection"
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

# Manual control helpers
launch_wheel_manual() {
  local wheel_config="${CARLA_WHEEL_CONFIG:-}"
  echo ""
  echo "=========================================="
  echo "  Manual Control (Logitech Wheel)"
  echo "=========================================="
  echo ""
  echo "Wheel setup:"
  echo "  • Default profile: scripts/wheel-config-g29.ini"
  echo "  • Override via env: export CARLA_WHEEL_CONFIG=/path/to/wheel_config.ini"
  echo "  • Mapping guide: docs/LOGITECH_WHEEL.md"
  echo "  • Tap the brake pedal once to wake up the wheel"
  echo ""
  if ! wheel_detected; then
    echo "⚠️  No joystick detected. Connect the Logitech wheel, then press Enter to retry." 
    echo "    (Press 'k' to fall back to keyboard mode.)"
    read -r user_choice
    if [[ "$user_choice" =~ ^[Kk]$ ]]; then
      launch_keyboard_manual
      return
    fi
    if ! wheel_detected; then
      echo "Still no joystick detected. Falling back to keyboard mode."
      launch_keyboard_manual
      return
    fi
  fi
  echo "Controls (wheel buttons):"
  echo "  • Circle: handbrake"
  echo "  • Right paddle: toggle reverse"
  echo "  • Buttons 0-3: restart/hud/camera/weather"
  echo "  • Keyboard shortcuts still work (Q gear, TAB camera, etc.)"
  echo ""
  echo "Press any key to launch manual_control_steeringwheel.py..."
  read -n 1 -s
  echo ""

  if [[ -n "$wheel_config" ]]; then
    if [[ -f "$wheel_config" ]]; then
      "$HELPER_PY" --manual-wheel --wheel-config "$wheel_config"
    else
      echo "WARNING: CARLA_WHEEL_CONFIG=$wheel_config not found. Using default profile."
      "$HELPER_PY" --manual-wheel
    fi
  else
    "$HELPER_PY" --manual-wheel
  fi
}

launch_keyboard_manual() {
  echo ""
  echo "=========================================="
  echo "  Manual Control (Keyboard)"
  echo "=========================================="
  echo ""
  echo "Controls:"
  echo "  W/S         - Throttle/Brake"
  echo "  A/D         - Steer left/right"
  echo "  Space       - Handbrake"
  echo "  Q or ESC    - Exit manual control"
  echo ""
  echo "Press any key to start..."
  read -n 1 -s
  echo ""
  "$HELPER_PY" --manual
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

# Quality change submenu
change_quality() {
  echo ""
  echo "=========================================="
  echo "  Change Quality Settings"
  echo "=========================================="
  echo ""
  echo "Quality levels:"
  echo "  1) Low      - Best performance"
  echo "  2) Medium   - Balanced"
  echo "  3) High     - Better visuals"
  echo "  4) Epic     - Best visuals (slow)"
  echo ""
  echo -n "Select quality (1-4) or 'b' to go back: "
  read -r quality_choice

  case $quality_choice in
    1) quality="Low" ;;
    2) quality="Medium" ;;
    3) quality="High" ;;
    4) quality="Epic" ;;
    b) return ;;
    *)
      echo "Invalid choice"
      return
      ;;
  esac

  echo ""
  echo "Resolution presets:"
  echo "  1) 800x600    - Fastest"
  echo "  2) 1280x720   - HD"
  echo "  3) 1920x1080  - Full HD"
  echo "  4) 2560x1440  - 2K"
  echo "  5) Custom"
  echo ""
  echo -n "Select resolution (1-5, default: keep current): "
  read -r res_choice

  resolution=""
  case $res_choice in
    1) resolution="800x600" ;;
    2) resolution="1280x720" ;;
    3) resolution="1920x1080" ;;
    4) resolution="2560x1440" ;;
    5)
      echo -n "Enter custom resolution (e.g., 1600x900): "
      read -r resolution
      ;;
    "") ;;
    *)
      echo "Invalid choice"
      return
      ;;
  esac

  echo ""
  echo "Stopping CARLA and restarting with new settings..."
  echo "Quality: $quality"
  [[ -n "$resolution" ]] && echo "Resolution: $resolution"
  echo ""
  echo -n "Proceed? (y/N): "
  read -r confirm

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    return
  fi

  # Kill existing CARLA
  pkill -f CarlaUE4 || true
  sleep 2

  # Build restart command
  restart_cmd="$SCRIPT_DIR/2-start-carla.sh --quality $quality"
  [[ -n "$resolution" ]] && restart_cmd="$restart_cmd --resolution $resolution"

  echo ""
  echo "Restarting CARLA..."
  echo "Command: $restart_cmd"
  echo ""

  # Execute in background
  bash -c "$restart_cmd" &

  echo "Waiting for CARLA to start (10 seconds)..."
  sleep 10

  if ss -tlnp 2>/dev/null | grep -q ":2000 " || netstat -tlnp 2>/dev/null | grep -q ":2000 "; then
    echo "✓ CARLA restarted successfully with new settings!"
  else
    echo "⚠️  CARLA may still be starting. Check with: ps aux | grep CarlaUE4"
  fi

  echo ""
  sleep 2
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
        echo "Press any key to return to menu..."
        read -n 1 -s
        ;;
      2)
        select_map
        echo ""
        sleep 1
        ;;
      3)
        select_weather
        echo ""
        sleep 1
        ;;
      4)
        spawn_vehicle
        echo ""
        sleep 1
        ;;
      5)
        echo ""
        "$HELPER_PY" --list-vehicles
        echo ""
        echo "Press any key to return to menu..."
        read -n 1 -s
        ;;
      6)
        move_camera
        echo ""
        sleep 1
        ;;
      7)
        launch_wheel_manual
        echo ""
        echo "Manual control ended. Returning to menu in 2 seconds..."
        sleep 2
        ;;
      8)
        change_quality
        ;;
      9)
        launch_keyboard_manual
        echo ""
        echo "Manual control ended. Returning to menu in 2 seconds..."
        sleep 2
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
