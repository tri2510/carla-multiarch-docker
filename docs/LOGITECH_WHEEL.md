# Logitech Wheel Setup (G29 / G923)

This project ships with `scripts/wheel-config-g29.ini`, a baseline mapping for
Logitech G29/G923 wheels. The helper copies that file next to CARLA's
`manual_control_steeringwheel.py` when you choose menu option **7** (wheel mode).
If your axes or buttons differ, follow the steps below to capture your layout
and create a custom config.

## 1. Install joystick tools
```bash
sudo apt install joystick jstest-gtk
```

## 2. Inspect axis / button numbers
Use either the GUI (`jstest-gtk`) or CLI:
```bash
jstest --event /dev/input/js0
```
Record the axis IDs for steering, throttle, brake (and clutch if needed) plus
button IDs for reverse/handbrake toggles.

### Typical G29/G923 mapping
| Control            | Axis/Button ID |
|--------------------|----------------|
| Steering wheel     | Axis 0         |
| Throttle pedal     | Axis 2         |
| Brake pedal        | Axis 3         |
| Reverse toggle     | Button 4 (right paddle) |
| Handbrake          | Button 2 (circle)       |

Your hardware/driver stack may report different IDs, so always confirm with
`jstest`.

## 3. Create a custom config (optional)
Copy the template and edit the indices:
```bash
cp scripts/wheel-config-g29.ini ~/my-wheel.ini
# edit values
```
Point the helper to that file:
```bash
export CARLA_WHEEL_CONFIG=~/my-wheel.ini
scripts/3-carla-helper.sh
```
Menu option **7** will now inject your custom mapping. Leave the variable unset
if you just want the default profile.

## 4. Button mapping inside CARLA
`manual_control_steeringwheel.py` still honors many keyboard shortcuts. Useful
ones:
- `TAB` – change camera position
- `` ` `` – next sensor
- `Q` – toggle reverse gear (in addition to the wheel paddle)
- `P` – toggle autopilot

Refer to CARLA's upstream script for the full list of buttons if you want to
remap additional functions.
