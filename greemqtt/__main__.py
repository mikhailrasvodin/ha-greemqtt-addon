import asyncio
import ipaddress
import os
import signal
import sys
from ipaddress import IPv4Address
from typing import AsyncGenerator, List, Optional

from GreeMQTT import device_db
from GreeMQTT.config import NETWORK
from GreeMQTT.device.device import Device
from GreeMQTT.device.device_communication import DeviceCommunicator
from GreeMQTT.logger import log
from GreeMQTT.mqtt_client import create_mqtt_client
from GreeMQTT.mqtt_handler import start_cleanup_task, start_device_tasks

log.info("GreeMQTT package initialized (patch 1)")


class GreeMQTTApp:
    def __init__(self):
        self.stop_event = asyncio.Event()

    def setup_signal_handlers(self):
        """Setup signal handlers for graceful shutdown."""

        def handle_shutdown(signum, frame):
            log.info(f"Shutdown signal {signum} received")
            self.stop_event.set()

        for sig in [signal.SIGTERM, signal.SIGINT]:
            signal.signal(sig, handle_shutdown)

    @staticmethod
    async def scan_network_for_devices(device_ips: List[str]) -> AsyncGenerator[Device, None]:
        """Scan network for devices on port 7000."""
        known_devices = device_db.get_all_devices()
        if not device_ips:
            subnet = os.environ.get("SUBNET", "192.168.1.0/24")
            log.info("Scanning network for devices", subnet=subnet)

            # Get all valid IPs (exclude network and broadcast addresses)
            network = ipaddress.IPv4Network(subnet)
            known_devices_ips = [
                IPv4Address(device.device_ip)
                for device in known_devices
                if IPv4Address(device.device_ip) in network.hosts()
            ]

            device_ips = known_devices_ips + [ip for ip in network.hosts() if ip not in known_devices_ips]

            if not device_ips:
                raise ValueError("No valid IPs found in the specified subnet")

        # Scan IPs concurrently with reasonable limits
        semaphore = asyncio.Semaphore(20)  # Limit concurrent scans

        async def scan_ip(target_ip: str) -> Optional[Device]:
            async with semaphore:
                try:
                    if await DeviceCommunicator.broadcast_scan(target_ip):
                        device = next(
                            (d for d in known_devices if d.device_ip == target_ip),
                            None,
                        )
                        if not device:
                            device = await Device.search_devices(target_ip)
                            if device and device.key:
                                device_db.save_device(
                                    device.device_id,
                                    device.device_ip,
                                    device.key,
                                    device.is_GCM,
                                )
                                log.info("Found new device", ip=target_ip)
                            else:
                                log.warning("Device not found or invalid key", ip=target_ip)
                        return device
                except Exception as e:
                    log.error("Error scanning IP", ip=target_ip, error=str(e))
                if len(device_ips) % 20 == 0:
                    log.info("Scanned IPs", scanned_ips=len(device_ips))
                return None

        # Create all scan tasks
        scan_tasks = [asyncio.create_task(scan_ip(str(ip))) for ip in device_ips]

        # Yield devices as they complete
        for task in asyncio.as_completed(scan_tasks):
            try:
                device = await task
                if isinstance(device, Device) and device is not None:
                    log.info("Device found", ip=device.device_ip, id=device.device_id)
                    yield device
            except Exception as e:
                log.warning("Exception during device scan task", error=str(e))
                pass  # Ignore exceptions from individual scans

    async def discover_and_setup_devices(self):
        """Discover devices and set them up for MQTT communication."""
        # Get network to scan (from config or scan automatically)
        network = NETWORK.copy() if NETWORK else []
        successful_devices = 0
        failed_devices = []

        try:
            async for device in self.scan_network_for_devices(network):
                try:
                    mqtt_client = await create_mqtt_client()
                    await mqtt_client.__aenter__()

                    if device.device_ip in network:
                        network.remove(device.device_ip)
                    
                    await start_device_tasks(device, mqtt_client, self.stop_event)
                    log.info("Started device successfully", ip=device.device_ip, id=device.device_id)
                    successful_devices += 1
                    
                except Exception as e:
                    log.error(
                        "Failed to setup device, but continuing with others", 
                        ip=device.device_ip, 
                        id=getattr(device, 'device_id', 'unknown'),
                        error=str(e)
                    )
                    failed_devices.append({
                        'ip': device.device_ip,
                        'id': getattr(device, 'device_id', 'unknown'),
                        'error': str(e)
                    })
                    continue  # Continue with next device instead of failing
        except Exception as e:
            log.error("Error during device discovery, but application will continue", error=str(e))

        if network:
            log.warning(
                "Some devices were not found in the network",
                missing_devices=network,
            )
            # Start retry manager for missing devices
            try:
                from GreeMQTT.device.device_retry_manager import DeviceRetryManager
                retry_manager = DeviceRetryManager(network, self.stop_event)
                asyncio.create_task(retry_manager.run())  # Run in background, don't await
            except Exception as e:
                log.error("Failed to start retry manager, but continuing", error=str(e))

        # Log summary
        log.info(
            "Device setup completed", 
            successful=successful_devices, 
            failed=len(failed_devices),
            failed_devices=failed_devices if failed_devices else None
        )
        
        # Don't fail the application even if some devices failed
        if successful_devices == 0 and failed_devices:
            log.warning("No devices were successfully setup, but application will continue running")
        
    async def run(self):
        """Main application entry point."""
        self.setup_signal_handlers()

        try:
            # Setup devices and start MQTT communication
            await self.discover_and_setup_devices()
            
            # Start cleanup task (don't fail if this fails)
            try:
                await start_cleanup_task(self.stop_event)
            except Exception as e:
                log.error("Failed to start cleanup task, but continuing", error=str(e))

            # Wait for shutdown signal
            log.info("Application running - press Ctrl+C to stop")
            await self.stop_event.wait()

        except KeyboardInterrupt:
            log.info("Application interrupted by user")
        except Exception as e:
            log.error("Application error, but will continue running (CUSTOM ERROR HANDLING)", error=str(e))
            # Don't exit here - let the application continue running
            try:
                # Wait for shutdown signal even after error
                log.info("🔧 CUSTOM: Application continuing despite errors - press Ctrl+C to stop")
                await self.stop_event.wait()
            except Exception:
                pass


def main():
    """Simple main function entry point."""
    try:
        app = GreeMQTTApp()
        asyncio.run(app.run())
    except KeyboardInterrupt:
        log.info("Application interrupted by user")
    except Exception as e:
        log.error("Fatal error", error=str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()