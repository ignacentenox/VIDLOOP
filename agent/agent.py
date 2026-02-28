"""
VIDLOOP Agent — Raspberry Pi Pull Client
Desarrollado por IGNACE - Powered By: 44 Contenidos

Responsibilities
----------------
1. Verify ZeroTier connectivity before each sync cycle.
2. Call the central server's /api/device/sync endpoint to discover
   new content or configuration changes.
3. Download any new files to the local media directory.
4. When multiple images are downloaded, convert them into a single
   MP4 video using FFmpeg (20 seconds per image).
5. Mark completed tasks on the server via a follow-up POST request.
"""

import logging
import os
import subprocess
import sys
import time
import urllib.request
import urllib.parse
import urllib.error
import json
import uuid
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration — override via environment variables
# ---------------------------------------------------------------------------

SERVER_URL: str = os.environ.get("VIDLOOP_SERVER_URL", "http://192.168.0.1:5000")
SYNC_INTERVAL: int = int(os.environ.get("VIDLOOP_SYNC_INTERVAL", "60"))  # seconds
MEDIA_DIR: str = os.environ.get("VIDLOOP_MEDIA_DIR", "/home/pi/VIDLOOP44")
DEVICE_ID_FILE: str = os.environ.get(
    "VIDLOOP_DEVICE_ID_FILE", "/etc/vidloop/device_id"
)
ZEROTIER_NETWORK: str = os.environ.get("VIDLOOP_ZEROTIER_NETWORK", "")
IMAGE_DURATION: int = int(os.environ.get("VIDLOOP_IMAGE_DURATION", "20"))  # s/image

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".webp"}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("vidloop-agent")


# ---------------------------------------------------------------------------
# Device ID
# ---------------------------------------------------------------------------

def get_device_id() -> str:
    """Return the persistent device ID, creating one if it does not exist."""
    id_path = Path(DEVICE_ID_FILE)
    if id_path.exists():
        return id_path.read_text().strip()

    # Create parent directory if needed
    id_path.parent.mkdir(parents=True, exist_ok=True)
    device_id = str(uuid.uuid4())
    id_path.write_text(device_id)
    log.info("Generated new device ID: %s", device_id)
    return device_id


# ---------------------------------------------------------------------------
# ZeroTier
# ---------------------------------------------------------------------------

def zerotier_ip(network_id: str = "") -> str:
    """
    Return the ZeroTier IP assigned to this device.

    If *network_id* is given, only IPs from that network are considered.
    Returns an empty string when ZeroTier is not connected.
    """
    try:
        result = subprocess.run(
            ["zerotier-cli", "listnetworks"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        for line in result.stdout.splitlines():
            if "OK" not in line:
                continue
            parts = line.split()
            # Need at least 9 columns; network ID is at index 2, IP/CIDR at index 8
            if len(parts) < 9:
                continue
            if network_id and parts[2] != network_id:
                continue
            return parts[8].split("/")[0]
    except (FileNotFoundError, subprocess.TimeoutExpired, IndexError):
        pass
    return ""


def is_zerotier_connected(network_id: str = "") -> bool:
    """Return True if ZeroTier has an active connection."""
    return bool(zerotier_ip(network_id))


# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

def _http_get(url: str, timeout: int = 30) -> dict:
    """Perform a GET request and return the parsed JSON body."""
    with urllib.request.urlopen(url, timeout=timeout) as resp:  # noqa: S310
        return json.loads(resp.read().decode())


def _http_post(url: str, payload: dict, timeout: int = 30) -> dict:
    """Perform a POST request with a JSON body and return the parsed JSON body."""
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        return json.loads(resp.read().decode())


# ---------------------------------------------------------------------------
# Sync logic
# ---------------------------------------------------------------------------

def fetch_tasks(device_id: str) -> list:
    """Ask the server for pending tasks and return the list."""
    params = urllib.parse.urlencode({"device_id": device_id})
    url = f"{SERVER_URL}/api/device/sync?{params}"
    try:
        body = _http_get(url)
        return body.get("tasks", [])
    except Exception as exc:
        log.error("Failed to fetch tasks from %s: %s", url, exc)
        return []


def acknowledge_tasks(device_id: str, task_ids: list) -> None:
    """Notify the server that the given tasks have been processed."""
    if not task_ids:
        return
    url = f"{SERVER_URL}/api/device/sync"
    try:
        _http_post(url, {"device_id": device_id, "completed_task_ids": task_ids})
        log.info("Acknowledged %d task(s)", len(task_ids))
    except Exception as exc:
        log.error("Failed to acknowledge tasks: %s", exc)


# ---------------------------------------------------------------------------
# File download
# ---------------------------------------------------------------------------

def download_file(url: str, dest_dir: Path) -> Path | None:
    """Download *url* into *dest_dir* and return the local Path, or None on error."""
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in ("http", "https"):
        log.error("Rejected URL with unsafe scheme: %s", url)
        return None
    filename = Path(parsed.path).name
    if not filename:
        filename = str(uuid.uuid4())
    dest = dest_dir / filename
    try:
        log.info("Downloading %s → %s", url, dest)
        urllib.request.urlretrieve(url, dest)  # noqa: S310
        return dest
    except Exception as exc:
        log.error("Failed to download %s: %s", url, exc)
        return None


# ---------------------------------------------------------------------------
# FFmpeg image-to-video conversion
# ---------------------------------------------------------------------------

def images_to_video(image_paths: list[Path], output_path: Path, duration: int) -> bool:
    """
    Convert a list of images into an MP4 video with *duration* seconds per image.

    Uses FFmpeg's concat demuxer so that each image is shown for exactly
    *duration* seconds with no re-encoding of audio (there is none).

    Returns True on success, False on failure.
    """
    if not image_paths:
        return False

    concat_file = output_path.with_suffix(".concat.txt")
    try:
        # Build the concat file — escape single quotes in paths
        def _escape(p: Path) -> str:
            return str(p).replace("'", "'\\''")

        lines = []
        for img in image_paths:
            lines.append(f"file '{_escape(img)}'")
            lines.append(f"duration {duration}")
        # FFmpeg needs a final file entry without a duration for the last frame
        lines.append(f"file '{_escape(image_paths[-1])}'")
        concat_file.write_text("\n".join(lines))

        cmd = [
            "ffmpeg",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", str(concat_file),
            "-vf", "scale=1920:1080:force_original_aspect_ratio=decrease,"
                   "pad=1920:1080:(ow-iw)/2:(oh-ih)/2",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            str(output_path),
        ]
        log.info("Running FFmpeg: %s", " ".join(cmd))
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            log.error("FFmpeg error:\n%s", result.stderr)
            return False
        log.info("Video created: %s", output_path)
        return True
    except Exception as exc:
        log.error("images_to_video failed: %s", exc)
        return False
    finally:
        if concat_file.exists():
            concat_file.unlink()


# ---------------------------------------------------------------------------
# Task processing
# ---------------------------------------------------------------------------

def process_task(task: dict, media_dir: Path) -> bool:
    """
    Process a single task.

    Returns True if the task was completed successfully.
    """
    task_id = task.get("task_id", "unknown")
    task_type = task.get("type", "video")
    files = task.get("files", [])

    if not files:
        log.warning("Task %s has no files, skipping", task_id)
        return True

    media_dir.mkdir(parents=True, exist_ok=True)
    downloaded: list[Path] = []

    for url in files:
        local = download_file(url, media_dir)
        if local:
            downloaded.append(local)

    if not downloaded:
        log.error("Task %s: no files downloaded", task_id)
        return False

    # Check if the downloaded files are all images
    image_files = [p for p in downloaded if p.suffix.lower() in IMAGE_EXTENSIONS]

    if len(image_files) == len(downloaded) and len(image_files) > 0:
        # All downloads are images — convert to video
        output_video = media_dir / f"task_{task_id}.mp4"
        success = images_to_video(image_files, output_video, IMAGE_DURATION)
        if success:
            # Remove the individual image files now that the video is ready
            for img in image_files:
                try:
                    img.unlink()
                except OSError:
                    pass
        return success

    # For video tasks (or mixed) just keep the downloaded files as-is
    log.info(
        "Task %s (%s): downloaded %d file(s)", task_id, task_type, len(downloaded)
    )
    return True


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def run() -> None:
    """Entry point for the agent — runs until interrupted."""
    device_id = get_device_id()
    media_dir = Path(MEDIA_DIR)
    log.info(
        "VIDLOOP Agent starting | device_id=%s | server=%s | interval=%ss",
        device_id,
        SERVER_URL,
        SYNC_INTERVAL,
    )

    while True:
        # 1. Check ZeroTier connectivity (skip cycle if not connected)
        if ZEROTIER_NETWORK:
            if not is_zerotier_connected(ZEROTIER_NETWORK):
                log.warning(
                    "ZeroTier network %s not connected — skipping sync cycle",
                    ZEROTIER_NETWORK,
                )
                time.sleep(SYNC_INTERVAL)
                continue
            log.info("ZeroTier connected (network %s)", ZEROTIER_NETWORK)

        # 2. Fetch pending tasks from the server
        pending_tasks = fetch_tasks(device_id)
        if not pending_tasks:
            log.info("No pending tasks")
        else:
            log.info("Received %d task(s)", len(pending_tasks))

        # 3. Process each task
        completed_ids: list[str] = []
        for task in pending_tasks:
            task_id = task.get("task_id", "")
            if process_task(task, media_dir):
                completed_ids.append(task_id)

        # 4. Acknowledge completed tasks
        acknowledge_tasks(device_id, completed_ids)

        time.sleep(SYNC_INTERVAL)


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        log.info("Agent stopped by user")
