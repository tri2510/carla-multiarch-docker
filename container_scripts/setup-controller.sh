#!/bin/bash
# Logitech Wheel Controller Setup Script

set -e

echo "========================================="
echo "Logitech Wheel Controller Setup"
echo "========================================="

# Check for connected controllers
echo "Detecting connected input devices..."
echo ""

# List all input devices
if [ -d /dev/input ]; then
    echo "Available input devices:"
    ls -la /dev/input/
    echo ""
fi

# Check for joystick devices
JOYSTICKS=$(ls /dev/input/js* 2>/dev/null || true)
if [ -n "$JOYSTICKS" ]; then
    echo "Detected joystick devices:"
    echo "$JOYSTICKS"
    echo ""
else
    echo "Warning: No joystick devices found"
    echo "Make sure your Logitech wheel is connected"
    echo ""
fi

# Check for event devices
EVENTS=$(ls /dev/input/event* 2>/dev/null || true)
if [ -n "$EVENTS" ]; then
    echo "Detected event devices:"
    for event in $EVENTS; do
        if [ -r "$event" ]; then
            NAME=$(cat /sys/class/input/$(basename $event | sed 's/event/input/')/name 2>/dev/null || echo "Unknown")
            echo "  $event: $NAME"
        fi
    done
    echo ""
fi

# Detect Logitech wheels specifically
echo "Searching for Logitech wheels..."
LOGITECH_DEVICES=$(lsusb | grep -i "logitech" || true)
if [ -n "$LOGITECH_DEVICES" ]; then
    echo "Found Logitech devices:"
    echo "$LOGITECH_DEVICES"
    echo ""
else
    echo "No Logitech devices found via USB"
    echo ""
fi

# Set permissions
echo "Setting permissions for input devices..."
if [ -w /dev/input ]; then
    sudo chmod -R a+rw /dev/input/* 2>/dev/null || echo "Note: Some devices may not be accessible"
    echo "Permissions set successfully"
else
    echo "Warning: Cannot write to /dev/input"
fi

# Test joystick if jstest is available
if command -v jstest &> /dev/null && [ -n "$JOYSTICKS" ]; then
    echo ""
    echo "Testing first joystick device..."
    FIRST_JS=$(echo "$JOYSTICKS" | head -n1)
    echo "Run this command to test: jstest $FIRST_JS"
    echo "Run this command to calibrate: jscal $FIRST_JS"
fi

# Create controller configuration
CONFIG_DIR="/home/$(whoami)/01_SDV/72_carla_arm/configs"
CONFIG_FILE="$CONFIG_DIR/controller.conf"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
# Logitech Wheel Controller Configuration
# Generated on $(date)

# Controller device (auto-detected)
CONTROLLER_DEVICE="${FIRST_JS:-/dev/input/js0}"

# Controller type
# Options: g27, g29, g920, driving_force_gt, generic
CONTROLLER_TYPE="${CONTROLLER_TYPE:-g29}"

# Controller settings
CONTROLLER_DEADZONE="${CONTROLLER_DEADZONE:-0.05}"
CONTROLLER_SENSITIVITY="${CONTROLLER_SENSITIVITY:-1.0}"

# Force feedback
FORCE_FEEDBACK="${FORCE_FEEDBACK:-true}"
FORCE_FEEDBACK_STRENGTH="${FORCE_FEEDBACK_STRENGTH:-1.0}"

# Button mapping (customize for your wheel)
# Format: BUTTON_<NAME>=<button_number>
BUTTON_ACCELERATE=5
BUTTON_BRAKE=6
BUTTON_CLUTCH=7
BUTTON_HANDBRAKE=8
BUTTON_SHIFT_UP=4
BUTTON_SHIFT_DOWN=5

# Axis mapping
AXIS_STEERING=0
AXIS_THROTTLE=1
AXIS_BRAKE=2
AXIS_CLUTCH=3

# Pedal inversion (some wheels have inverted pedals)
INVERT_THROTTLE="${INVERT_THROTTLE:-false}"
INVERT_BRAKE="${INVERT_BRAKE:-false}"
INVERT_CLUTCH="${INVERT_CLUTCH:-false}"

EOF

echo ""
echo "Configuration file created: $CONFIG_FILE"
echo "Edit this file to customize your controller settings"

echo ""
echo "========================================="
echo "Controller setup complete!"
echo ""
echo "Common Logitech Wheels Supported:"
echo "  - Logitech G27"
echo "  - Logitech G29"
echo "  - Logitech G920"
echo "  - Logitech Driving Force GT"
echo ""
echo "To test in CARLA, run the manual control script:"
echo "  docker compose exec carla python3 /home/carla/PythonAPI/examples/manual_control.py"
echo "========================================="
