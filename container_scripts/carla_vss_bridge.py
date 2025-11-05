#!/usr/bin/env python3
"""CARLA → KUKSA VSS bridge for streaming speed/RPM."""

import argparse
import logging
import math
import os
import signal
import sys
import time
from typing import Optional

try:
    import carla
except ImportError as exc:  # pragma: no cover
    print("[ERROR] CARLA Python API is not available inside this environment.")
    print("Install the carla wheel or run inside the CARLA container.")
    print(f"Details: {exc}")
    sys.exit(1)

try:
    from kuksa_client.grpc import VSSClient, Datapoint
except ImportError as exc:  # pragma: no cover
    print("[ERROR] kuksa-client is not installed. Install with: pip install kuksa-client")
    print(f"Details: {exc}")
    sys.exit(1)

LOGGER = logging.getLogger("carla_vss_bridge")
DEFAULT_VSS_SPEED = "Vehicle.Speed"
DEFAULT_VSS_RPM = "Vehicle.Powertrain.CombustionEngine.Speed"


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


class CarlaVSSBridge:
    def __init__(
        self,
        carla_host: str = "127.0.0.1",
        carla_port: int = 2000,
        carla_timeout: float = 5.0,
        vehicle_role: Optional[str] = "hero",
        vehicle_id: Optional[int] = None,
        kuksa_host: str = "127.0.0.1",
        kuksa_port: int = 55555,
        vss_speed_path: str = DEFAULT_VSS_SPEED,
        vss_rpm_path: str = DEFAULT_VSS_RPM,
        max_speed_kmh: float = 160.0,
        rpm_idle: float = 800.0,
        rpm_max: float = 5000.0,
        update_interval: float = 0.1,
        reconnect_delay: float = 2.0,
    ):
        self.carla_host = carla_host
        self.carla_port = carla_port
        self.carla_timeout = carla_timeout
        self.vehicle_role = vehicle_role
        self.vehicle_id = vehicle_id
        self.kuksa_host = kuksa_host
        self.kuksa_port = kuksa_port
        self.vss_speed_path = vss_speed_path
        self.vss_rpm_path = vss_rpm_path
        self.max_speed_kmh = max_speed_kmh
        self.rpm_idle = rpm_idle
        self.rpm_max = rpm_max
        self.update_interval = update_interval
        self.reconnect_delay = reconnect_delay

        self._shutdown = False
        self._carla_client: Optional[carla.Client] = None
        self._world: Optional[carla.World] = None
        self._vehicle: Optional[carla.Vehicle] = None
        self._kuksa_client: Optional[VSSClient] = None

    # ------------------------------------------------------------------
    def start(self) -> None:
        self._setup_signal_handlers()
        self._connect_carla()
        self._connect_kuksa()
        self._loop()

    # ------------------------------------------------------------------
    def _setup_signal_handlers(self) -> None:
        def _stop_handler(signum, frame):  # pylint: disable=unused-argument
            LOGGER.info("Signal %s received, shutting down bridge", signum)
            self._shutdown = True

        signal.signal(signal.SIGINT, _stop_handler)
        signal.signal(signal.SIGTERM, _stop_handler)

    # ------------------------------------------------------------------
    def _connect_carla(self) -> None:
        LOGGER.info("Connecting to CARLA at %s:%s", self.carla_host, self.carla_port)
        self._carla_client = carla.Client(self.carla_host, self.carla_port)
        self._carla_client.set_timeout(self.carla_timeout)
        self._world = self._carla_client.get_world()
        self._ensure_vehicle()

    # ------------------------------------------------------------------
    def _connect_kuksa(self) -> None:
        LOGGER.info("Connecting to KUKSA server at %s:%s", self.kuksa_host, self.kuksa_port)
        try:
            self._kuksa_client = VSSClient(self.kuksa_host, self.kuksa_port)
            self._kuksa_client.connect()
        except Exception as exc:  # pragma: no cover
            LOGGER.error("Failed to connect to KUKSA (%s). Retrying in %.1fs", exc, self.reconnect_delay)
            self._kuksa_client = None

    # ------------------------------------------------------------------
    def _ensure_vehicle(self) -> None:
        if not self._world:
            raise RuntimeError("CARLA world not available")

        actors = self._world.get_actors().filter('vehicle.*')
        selected = None

        if self.vehicle_id is not None:
            selected = self._world.get_actor(self.vehicle_id)
            if selected is None:
                raise RuntimeError(f"Vehicle with id {self.vehicle_id} not found")
        elif self.vehicle_role:
            for veh in actors:
                if veh.attributes.get('role_name') == self.vehicle_role:
                    selected = veh
                    break

        if selected is None and len(actors) > 0:
            selected = actors[0]

        if selected is None:
            raise RuntimeError("No vehicle actors found in the scene. Spawn one and retry.")

        self._vehicle = selected
        LOGGER.info(
            "Publishing telemetry from vehicle id=%s blueprint=%s role=%s",
            self._vehicle.id,
            self._vehicle.type_id,
            self._vehicle.attributes.get('role_name', '<none>'),
        )

    # ------------------------------------------------------------------
    def _loop(self) -> None:
        while not self._shutdown:
            try:
                if not self._vehicle or not self._vehicle.is_alive:
                    LOGGER.warning("Vehicle reference lost, re-acquiring")
                    self._ensure_vehicle()

                speed = self._compute_speed_kmh()
                rpm = self._estimate_rpm(speed)
                self._publish(speed, rpm)
            except RuntimeError as exc:
                LOGGER.error("Runtime error: %s", exc)
            except carla.TimeoutError as exc:  # pragma: no cover
                LOGGER.warning("CARLA timeout: %s", exc)
                time.sleep(self.reconnect_delay)
                self._connect_carla()
            except Exception as exc:  # pragma: no cover
                LOGGER.exception("Unexpected error: %s", exc)
                time.sleep(self.reconnect_delay)

            time.sleep(self.update_interval)

        self._teardown()

    # ------------------------------------------------------------------
    def _compute_speed_kmh(self) -> float:
        if not self._vehicle:
            return 0.0
        velocity = self._vehicle.get_velocity()
        speed = 3.6 * math.sqrt(velocity.x ** 2 + velocity.y ** 2 + velocity.z ** 2)
        return round(speed, 3)

    # ------------------------------------------------------------------
    def _estimate_rpm(self, speed_kmh: float) -> float:
        if self.max_speed_kmh <= 0:
            ratio = 0.0
        else:
            ratio = clamp(speed_kmh / self.max_speed_kmh, 0.0, 1.0)

        rpm = self.rpm_idle + ratio * (self.rpm_max - self.rpm_idle)
        return round(clamp(rpm, self.rpm_idle, self.rpm_max), 0)

    # ------------------------------------------------------------------
    def _publish(self, speed: float, rpm: float) -> None:
        if not self._kuksa_client:
            self._connect_kuksa()
            if not self._kuksa_client:
                return

        updates = {
            self.vss_speed_path: Datapoint(speed),
            self.vss_rpm_path: Datapoint(rpm),
        }
        try:
            self._kuksa_client.set_current_values(updates)
            LOGGER.debug("Published speed=%.2f km/h rpm=%.0f", speed, rpm)
        except Exception as exc:  # pragma: no cover
            LOGGER.error("Failed to publish to KUKSA: %s", exc)
            self._kuksa_client.disconnect()
            self._kuksa_client = None
            time.sleep(self.reconnect_delay)

    # ------------------------------------------------------------------
    def _teardown(self) -> None:
        LOGGER.info("Stopping CARLA→KUKSA bridge")
        try:
            if self._kuksa_client:
                self._kuksa_client.disconnect()
        finally:
            self._kuksa_client = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Stream CARLA telemetry to a KUKSA VSS server")
    parser.add_argument("--carla-host", default=os.getenv("CARLA_SERVER_HOST", "127.0.0.1"))
    parser.add_argument("--carla-port", type=int, default=int(os.getenv("CARLA_SERVER_PORT", "2000")))
    parser.add_argument("--carla-timeout", type=float, default=5.0)
    parser.add_argument("--vehicle-role-name", default=os.getenv("CARLA_VEHICLE_ROLE", "hero"),
                        help="Role name of the vehicle to monitor (default: hero)")
    parser.add_argument("--vehicle-id", type=int, default=None,
                        help="Explicit CARLA actor id to monitor (overrides role name)")
    parser.add_argument("--kuksa-host", default=os.getenv("KUKSA_HOST", "127.0.0.1"))
    parser.add_argument("--kuksa-port", type=int, default=int(os.getenv("KUKSA_PORT", "55555")))
    parser.add_argument("--vss-speed-path", default=DEFAULT_VSS_SPEED)
    parser.add_argument("--vss-rpm-path", default=DEFAULT_VSS_RPM)
    parser.add_argument("--max-speed-kmh", type=float, default=160.0,
                        help="Speed corresponding to max RPM mapping")
    parser.add_argument("--rpm-idle", type=float, default=800.0)
    parser.add_argument("--rpm-max", type=float, default=5000.0)
    parser.add_argument("--update-interval", type=float, default=0.1,
                        help="Seconds between updates")
    parser.add_argument("--log-level", default="INFO")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level.upper(), logging.INFO),
                        format="%(asctime)s %(levelname)s %(name)s: %(message)s")

    bridge = CarlaVSSBridge(
        carla_host=args.carla_host,
        carla_port=args.carla_port,
        carla_timeout=args.carla_timeout,
        vehicle_role=args.vehicle_role_name,
        vehicle_id=args.vehicle_id,
        kuksa_host=args.kuksa_host,
        kuksa_port=args.kuksa_port,
        vss_speed_path=args.vss_speed_path,
        vss_rpm_path=args.vss_rpm_path,
        max_speed_kmh=args.max_speed_kmh,
        rpm_idle=args.rpm_idle,
        rpm_max=args.rpm_max,
        update_interval=args.update_interval,
    )

    try:
        bridge.start()
    except KeyboardInterrupt:
        LOGGER.info("Interrupted by user")
    except Exception as exc:  # pragma: no cover
        LOGGER.exception("Bridge crashed: %s", exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
