"""VIDLOOP Backend Server.

Exposes the REST API consumed by the Raspberry Pi agents:

    POST /api/device/sync
        Body : { "device_id": str, "local_files": [str, …] }
        Auto-registers unknown devices and returns the list of files the
        device does not yet have.

    GET  /api/device/files/<filename>
        Serves a media file for download by the agents.

    POST /api/upload
        Accepts a multipart/form-data upload.  Images are automatically
        converted to 20-second MP4 videos via ffmpeg_service before being
        stored in the media directory.

Environment variables:
    MEDIA_DIR   Directory where media files are stored
                (default: /app/media)
    DATABASE    SQLite database file path
                (default: /app/vidloop.db)
    SECRET_KEY  Flask secret key (default: change-me-in-production)
"""

import logging
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, abort, jsonify, request, send_from_directory
from werkzeug.utils import secure_filename

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MEDIA_DIR = os.getenv("MEDIA_DIR", "/app/media")
DATABASE = os.getenv("DATABASE", "/app/vidloop.db")
SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")

ALLOWED_VIDEO_EXTENSIONS = {".mp4", ".avi", ".mov", ".mkv", ".m4v", ".webm"}
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"}
ALLOWED_EXTENSIONS = ALLOWED_VIDEO_EXTENSIONS | ALLOWED_IMAGE_EXTENSIONS

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------

app = Flask(__name__)
app.config["SECRET_KEY"] = SECRET_KEY
app.config["MAX_CONTENT_LENGTH"] = 500 * 1024 * 1024  # 500 MB

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

Path(MEDIA_DIR).mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------


def get_db() -> sqlite3.Connection:
    """Return a new SQLite connection."""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create database tables if they do not exist."""
    with get_db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS devices (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id  TEXT    NOT NULL UNIQUE,
                last_seen  TEXT    NOT NULL,
                created_at TEXT    NOT NULL
            );

            CREATE TABLE IF NOT EXISTS media_files (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                filename      TEXT NOT NULL UNIQUE,
                original_name TEXT NOT NULL,
                created_at    TEXT NOT NULL
            );
            """
        )


def register_device(device_id: str) -> None:
    """Insert or update a device record."""
    now = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        conn.execute(
            """
            INSERT INTO devices (device_id, last_seen, created_at)
            VALUES (?, ?, ?)
            ON CONFLICT(device_id) DO UPDATE SET last_seen = excluded.last_seen
            """,
            (device_id, now, now),
        )


def list_media_files() -> list:
    """Return all media filenames stored on the server."""
    with get_db() as conn:
        rows = conn.execute("SELECT filename FROM media_files ORDER BY created_at").fetchall()
    return [row["filename"] for row in rows]


def add_media_file(filename: str, original_name: str) -> None:
    """Record a newly uploaded media file in the database."""
    now = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        conn.execute(
            """
            INSERT INTO media_files (filename, original_name, created_at)
            VALUES (?, ?, ?)
            ON CONFLICT(filename) DO NOTHING
            """,
            (filename, original_name, now),
        )


def _allowed_extension(filename: str) -> bool:
    suffix = Path(filename).suffix.lower()
    return suffix in ALLOWED_EXTENSIONS


# ---------------------------------------------------------------------------
# API endpoints
# ---------------------------------------------------------------------------


@app.route("/api/device/sync", methods=["POST"])
def device_sync():
    """Sync endpoint called by each Raspberry Pi agent.

    Registers the device on first contact and returns the list of files
    the device is missing.
    """
    body = request.get_json(silent=True) or {}
    device_id = body.get("device_id", "").strip()

    if not device_id:
        return jsonify({"error": "device_id is required"}), 400

    register_device(device_id)

    local_files = set(body.get("local_files", []))
    all_files = list_media_files()
    new_files = [{"filename": f} for f in all_files if f not in local_files]

    logger.info(
        "Sync: device=%s local=%d server=%d new=%d",
        device_id,
        len(local_files),
        len(all_files),
        len(new_files),
    )
    return jsonify({"new_files": new_files}), 200


@app.route("/api/device/files/<path:filename>", methods=["GET"])
def serve_file(filename: str):
    """Serve a media file for download by an agent."""
    # Reject filenames that try to escape the media directory
    safe = secure_filename(filename)
    if not safe or safe != filename:
        abort(400)
    file_path = Path(MEDIA_DIR) / safe
    if not file_path.is_file():
        abort(404)
    return send_from_directory(MEDIA_DIR, safe, as_attachment=True)


@app.route("/api/upload", methods=["POST"])
def upload_file():
    """Accept a media upload.

    Images are converted to 20-second MP4 videos automatically.
    Only video files are stored in the media directory and made available
    for device sync.
    """
    if "file" not in request.files:
        return jsonify({"error": "No file part in request"}), 400

    uploaded = request.files["file"]
    if not uploaded.filename:
        return jsonify({"error": "No file selected"}), 400

    original_name = uploaded.filename
    if not _allowed_extension(original_name):
        return jsonify({"error": "File type not allowed"}), 415

    safe_name = secure_filename(original_name)
    save_path = os.path.join(MEDIA_DIR, safe_name)
    uploaded.save(save_path)

    # Convert images → video
    from services.ffmpeg_service import process_upload  # local import avoids circular deps

    try:
        final_path = process_upload(save_path)
    except (RuntimeError, FileNotFoundError, OSError) as exc:
        logger.error("Media processing failed for %s: %s", safe_name, exc)
        if os.path.exists(save_path):
            os.remove(save_path)
        return jsonify({"error": "Media processing failed. Check server logs for details."}), 500
    except Exception as exc:  # noqa: BLE001
        logger.error("Unexpected processing error for %s: %s", safe_name, exc)
        if os.path.exists(save_path):
            os.remove(save_path)
        return jsonify({"error": "An unexpected error occurred during upload processing."}), 500

    final_filename = Path(final_path).name
    add_media_file(final_filename, original_name)

    return jsonify({"filename": final_filename, "original": original_name}), 201


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
