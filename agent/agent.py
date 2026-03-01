#!/usr/bin/env python3
"""VIDLOOP Agent — pull-based synchronisation agent for Raspberry Pi.

Periodically polls the central server for new content, downloads it into
the local videos directory, and validates ZeroTier connectivity before
each sync cycle (when a network ID is configured).

Environment variables:
    VIDLOOP_SERVER_URL      Base URL of the central server
                            (default: http://192.168.196.1:5000)
    VIDLOOP_DEVICE_ID       Unique identifier for this device
                            (default: system hostname)
    VIDLOOP_VIDEOS_DIR      Directory where videos are stored
                            (default: /home/pi/VIDLOOP44)
    VIDLOOP_SYNC_INTERVAL   Seconds between sync cycles (default: 60)
    ZEROTIER_NETWORK_ID     ZeroTier network ID to validate before syncing
                            (optional — skip check if not set)
"""

import os
import sys
import time
import logging
import subprocess
import socket
from pathlib import Path

import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SERVER_URL = os.getenv("VIDLOOP_SERVER_URL", "http://192.168.196.1:5000")
DEVICE_ID = os.getenv("VIDLOOP_DEVICE_ID", socket.gethostname())
VIDEOS_DIR = os.getenv("VIDLOOP_VIDEOS_DIR", "/home/pi/VIDLOOP44")
SYNC_INTERVAL = int(os.getenv("VIDLOOP_SYNC_INTERVAL", "60"))
ZEROTIER_NETWORK_ID = os.getenv("ZEROTIER_NETWORK_ID", "")

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

_log_handlers: list = [logging.StreamHandler(sys.stdout)]
_log_file = "/var/log/vidloop-agent.log"
try:
    _log_handlers.append(logging.FileHandler(_log_file))
except OSError:
    pass  # Running in a context without access to /var/log

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=_log_handlers,
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# ZeroTier helpers
# ---------------------------------------------------------------------------


def check_zerotier_connectivity() -> bool:
    """Return True if the configured ZeroTier network is connected and authorised."""
    if not ZEROTIER_NETWORK_ID:
        return True
    try:
        result = subprocess.run(
            ["zerotier-cli", "listnetworks"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            logger.warning("zerotier-cli returned non-zero: %s", result.stderr.strip())
            return False
        for line in result.stdout.splitlines():
            if ZEROTIER_NETWORK_ID in line and "OK" in line:
                logger.debug("ZeroTier network %s is connected.", ZEROTIER_NETWORK_ID)
                return True
        logger.warning(
            "ZeroTier network %s not found or not authorised.", ZEROTIER_NETWORK_ID
        )
        return False
    except FileNotFoundError:
        logger.warning("zerotier-cli not found — skipping ZeroTier check.")
        return True  # Allow sync when ZeroTier is not installed
    except subprocess.TimeoutExpired:
        logger.warning("zerotier-cli timed out.")
        return False


# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------


def get_local_files() -> set:
    """Return the set of filenames already present in the videos directory."""
    videos_path = Path(VIDEOS_DIR)
    videos_path.mkdir(parents=True, exist_ok=True)
    return {f.name for f in videos_path.iterdir() if f.is_file()}


def download_file(filename: str) -> None:
    """Download *filename* from the server into the videos directory."""
    # Basic path-safety: reject filenames with directory separators
    if os.sep in filename or (os.altsep and os.altsep in filename):
        logger.error("Refusing to download file with path separator: %s", filename)
        return

    url = f"{SERVER_URL}/api/device/files/{filename}"
    dest = Path(VIDEOS_DIR) / filename

    try:
        logger.info("Downloading %s …", filename)
        with requests.get(url, stream=True, timeout=120) as resp:
            resp.raise_for_status()
            with open(dest, "wb") as fh:
                for chunk in resp.iter_content(chunk_size=8192):
                    fh.write(chunk)
        logger.info("Saved %s → %s", filename, dest)
    except requests.RequestException as exc:
        logger.error("Failed to download %s: %s", filename, exc)
        if dest.exists():
            dest.unlink()


# ---------------------------------------------------------------------------
# Sync logic
# ---------------------------------------------------------------------------


def sync_with_server() -> None:
    """Contact the central server, register this device, and fetch new files."""
    local_files = get_local_files()
    payload = {
        "device_id": DEVICE_ID,
        "local_files": list(local_files),
    }

    try:
        resp = requests.post(
            f"{SERVER_URL}/api/device/sync",
            json=payload,
            timeout=30,
        )
        resp.raise_for_status()
    except requests.RequestException as exc:
        logger.error("Sync request failed: %s", exc)
        return

    data = resp.json()
    new_files = data.get("new_files", [])

    if not new_files:
        logger.info("No new files to download.")
        return

    logger.info("%d new file(s) to download.", len(new_files))
    for file_info in new_files:
        filename = file_info.get("filename")
        if filename:
            download_file(filename)


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------


def run() -> None:
    """Entry point: continuously sync with the central server."""
    logger.info(
        "VIDLOOP Agent starting — device: %s, server: %s, interval: %ds",
        DEVICE_ID,
        SERVER_URL,
        SYNC_INTERVAL,
    )

    while True:
        if ZEROTIER_NETWORK_ID and not check_zerotier_connectivity():
            logger.warning("ZeroTier not connected — skipping sync cycle.")
        else:
            try:
                sync_with_server()
            except requests.RequestException as exc:  # noqa: BLE001
                logger.error("Network error during sync cycle: %s", exc)
            except OSError as exc:
                logger.error("File I/O error during sync cycle: %s", exc)
            except Exception as exc:  # noqa: BLE001
                logger.error("Unexpected error during sync cycle: %s", exc)

        time.sleep(SYNC_INTERVAL)


if __name__ == "__main__":
    run()
