#!/usr/bin/env python3
"""Launch CARLA's manual_control_steeringwheel.py with Logitech shifter support."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXAMPLES_DIR = PROJECT_ROOT / "local_carla" / "PythonAPI" / "examples"
BASE_SCRIPT = EXAMPLES_DIR / "manual_control_steeringwheel.py"


def load_base_module():
    if not BASE_SCRIPT.exists():
        print(f"manual_control_steeringwheel.py not found at {BASE_SCRIPT}", file=sys.stderr)
        sys.exit(2)
    spec = importlib.util.spec_from_file_location("manual_control_steeringwheel", BASE_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def patch_dual_control(module):
    carla = module.carla

    class DualControlWithShifter(module.DualControl):  # type: ignore[misc]
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self._shifter_mapping = {}
            self._shifter_reverse = None
            self._configure_shifter()

        def _configure_shifter(self):
            for section in ("G29 Shifter", "Logitech Shifter", "Shifter"):
                if self._parser.has_section(section):
                    self._shifter_mapping = {
                        self._parser.getint(section, "gear1", fallback=-1): 1,
                        self._parser.getint(section, "gear2", fallback=-1): 2,
                        self._parser.getint(section, "gear3", fallback=-1): 3,
                        self._parser.getint(section, "gear4", fallback=-1): 4,
                        self._parser.getint(section, "gear5", fallback=-1): 5,
                        self._parser.getint(section, "gear6", fallback=-1): 6,
                    }
                    # Remove invalid entries
                    self._shifter_mapping = {
                        btn: gear for btn, gear in self._shifter_mapping.items() if btn >= 0
                    }
                    self._shifter_reverse = self._parser.getint(section, "reverse", fallback=-1)
                    if self._shifter_reverse < 0:
                        self._shifter_reverse = None
                    return

        def _apply_shifter(self, button_states):
            if not self._shifter_mapping:
                return
            gear = None
            for btn, gear_value in self._shifter_mapping.items():
                if btn < len(button_states) and button_states[btn]:
                    gear = gear_value
                    break
            if gear is None and self._shifter_reverse is not None:
                if self._shifter_reverse < len(button_states) and button_states[self._shifter_reverse]:
                    gear = -1
            if gear is None:
                return
            if isinstance(self._control, carla.VehicleControl):
                self._control.manual_gear_shift = True
                self._control.gear = gear

        def _parse_vehicle_wheel(self):
            super()._parse_vehicle_wheel()
            button_states = [bool(self._joystick.get_button(i)) for i in range(self._joystick.get_numbuttons())]
            self._apply_shifter(button_states)

    module.DualControl = DualControlWithShifter


def main():
    module = load_base_module()
    patch_dual_control(module)
    module.main()


if __name__ == "__main__":
    main()
