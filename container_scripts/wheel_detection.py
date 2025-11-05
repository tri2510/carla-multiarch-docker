#!/usr/bin/env python3
"""Interactive Logitech/joystick detection helper."""

import sys
import pygame


def test_wheel_detection() -> bool:
    print("=" * 60)
    print("STEERING WHEEL DETECTION TEST")
    print("=" * 60)

    try:
        pygame.init()
        pygame.joystick.init()

        joystick_count = pygame.joystick.get_count()
        print("\n✓ Pygame initialized successfully")
        print(f"✓ Joysticks detected: {joystick_count}")

        if joystick_count == 0:
            print("\n❌ No steering wheel/joystick detected!")
            print("\nTroubleshooting:")
            print("  1. Connect the Logitech wheel via USB")
            print("  2. Check: ls -la /dev/input/js*")
            print("  3. Check: lsusb | grep -i logitech")
            print("  4. Ensure the docker user can access /dev/input (privileged or proper udev rule)")
            return False

        print("\n" + "=" * 60)
        print("DEVICE INFORMATION")
        print("=" * 60)

        joystick = pygame.joystick.Joystick(0)
        joystick.init()

        print(f"Device Name:    {joystick.get_name()}")
        print(f"Axes:           {joystick.get_numaxes()}")
        print(f"Buttons:        {joystick.get_numbuttons()}")
        print(f"Hats (D-Pads):  {joystick.get_numhats()}")
        print(f"Trackballs:     {joystick.get_numballs()}")

        device_name = joystick.get_name().lower()
        if any(model in device_name for model in ("g923", "g29", "g27", "logitech")):
            print("\n✅ Logitech wheel detected!")
        else:
            print("\n⚠️ Device detected but name does not match Logitech presets.")
            print("   If this is your wheel it should still function, but double-check mappings.")

        print("\n" + "=" * 60)
        print("LIVE INPUT TEST - Press Ctrl+C to stop")
        print("=" * 60)
        print("Move the wheel, pedals, buttons. Expected axes:")
        print("  Axis 0: Steering  (-1.0 left, 1.0 right)")
        print("  Axis 1: Throttle")
        print("  Axis 2: Brake")
        print("  Axis 3: Clutch (if available)\n")

        clock = pygame.time.Clock()
        while True:
            pygame.event.pump()

            axes_str = "Axes: "
            for idx in range(joystick.get_numaxes()):
                axes_str += f"[{idx}]:{joystick.get_axis(idx):6.3f} "

            pressed_buttons = [str(idx) for idx in range(joystick.get_numbuttons()) if joystick.get_button(idx)]
            buttons_str = f"Buttons: {','.join(pressed_buttons) if pressed_buttons else 'none'}"

            hat_str = ""
            if joystick.get_numhats() > 0:
                hat = joystick.get_hat(0)
                if hat != (0, 0):
                    hat_str = f"D-Pad: {hat}"

            status = f"\r{axes_str} | {buttons_str} {hat_str}            "
            print(status, end="", flush=True)

            clock.tick(30)

    except KeyboardInterrupt:
        print("\n\n✓ Test stopped by user")
        return True
    except Exception as exc:
        print(f"\n❌ Error: {exc}")
        print("\nEnsure pygame is installed and that /dev/input devices are accessible")
        return False
    finally:
        try:
            pygame.quit()
        except Exception:
            pass

    print("\n" + "=" * 60)
    print("✅ WHEEL DETECTION TEST COMPLETE")
    print("=" * 60)
    print("\nNext steps:")
    print("  - Run manual control: docker compose exec carla python3 /home/carla/scripts/manual_control_wheel.py")
    print("  - Or start your wheel workflow script")
    return True


if __name__ == "__main__":
    sys.exit(0 if test_wheel_detection() else 1)
