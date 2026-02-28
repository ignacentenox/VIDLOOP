"""
VIDLOOP Backend Server
Desarrollado por IGNACE - Powered By: 44 Contenidos

Exposes a REST API for Raspberry Pi agents to pull their pending tasks
and register themselves when connecting for the first time.
"""

import os
import uuid
from datetime import datetime, timezone

from flask import Flask, jsonify, request

app = Flask(__name__)

# ---------------------------------------------------------------------------
# In-memory storage (replace with a proper DB in production)
# ---------------------------------------------------------------------------

# devices[device_id] = {"ip": str, "registered_at": str, "last_seen": str}
devices: dict = {}

# tasks[device_id] = [{"task_id": str, "type": str, "files": [...], ...}, ...]
# Seeded with a demo entry so the endpoint returns something meaningful out-of-the-box.
tasks: dict = {}


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _register_device(device_id: str, ip: str) -> None:
    """Register a device if it has not been seen before, otherwise update last_seen."""
    if device_id not in devices:
        devices[device_id] = {
            "device_id": device_id,
            "ip": ip,
            "registered_at": _now(),
            "last_seen": _now(),
        }
    else:
        devices[device_id]["ip"] = ip
        devices[device_id]["last_seen"] = _now()


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/health", methods=["GET"])
def health():
    """Simple health-check endpoint."""
    return jsonify({"status": "ok", "timestamp": _now()})


@app.route("/api/device/sync", methods=["GET"])
def device_sync():
    """
    Pull endpoint for Raspberry Pi agents.

    Query parameters
    ----------------
    device_id : str
        Unique identifier of the device (e.g. ZeroTier node ID or UUID).

    The caller's IP is extracted from the request and used to register /
    update the device record.

    Returns
    -------
    JSON with the list of pending tasks for the device.  Each task is an
    object with at least the fields:
      - task_id   : unique identifier for the task
      - type      : "video" | "images"
      - files     : list of URLs to download
      - processed : False (agent marks it True after completion)
    """
    device_id = request.args.get("device_id", "").strip()
    if not device_id:
        return jsonify({"error": "device_id query parameter is required"}), 400

    # Determine the caller IP (support reverse-proxy headers)
    client_ip = (
        request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
        or request.remote_addr
        or "unknown"
    )

    _register_device(device_id, client_ip)

    pending = tasks.get(device_id, [])
    return jsonify(
        {
            "device_id": device_id,
            "timestamp": _now(),
            "tasks": pending,
        }
    )


@app.route("/api/device/sync", methods=["POST"])
def device_sync_post():
    """
    Allow an agent to acknowledge / mark tasks as processed.

    Body (JSON)
    -----------
    {
        "device_id": "...",
        "completed_task_ids": ["task_id_1", "task_id_2", ...]
    }
    """
    data = request.get_json(silent=True) or {}
    device_id = data.get("device_id", "").strip()
    completed_ids = data.get("completed_task_ids", [])

    if not device_id:
        return jsonify({"error": "device_id is required"}), 400

    client_ip = (
        request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
        or request.remote_addr
        or "unknown"
    )
    _register_device(device_id, client_ip)

    if device_id in tasks:
        tasks[device_id] = [
            t for t in tasks[device_id] if t["task_id"] not in completed_ids
        ]

    return jsonify({"status": "ok", "device_id": device_id, "timestamp": _now()})


@app.route("/api/device/task", methods=["POST"])
def add_task():
    """
    Add a new task for a specific device.

    Body (JSON)
    -----------
    {
        "device_id": "...",
        "type": "video" | "images",
        "files": ["https://...", "https://..."]
    }
    """
    data = request.get_json(silent=True) or {}
    device_id = data.get("device_id", "").strip()
    task_type = data.get("type", "video")
    files = data.get("files", [])

    if not device_id:
        return jsonify({"error": "device_id is required"}), 400
    if not files:
        return jsonify({"error": "files list is required"}), 400

    task = {
        "task_id": str(uuid.uuid4()),
        "type": task_type,
        "files": files,
        "created_at": _now(),
        "processed": False,
    }
    tasks.setdefault(device_id, []).append(task)

    return jsonify({"status": "created", "task": task}), 201


@app.route("/api/devices", methods=["GET"])
def list_devices():
    """Return all registered devices."""
    return jsonify({"devices": list(devices.values())})


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
