"""VIDLOOP FFmpeg service.

Provides helper functions to process uploaded media files before they are
made available for device sync.  Images are automatically converted to a
20-second MP4 video so that only video files are ever distributed to the
Raspberry Pi devices.
"""

import logging
import os
import subprocess
from pathlib import Path

logger = logging.getLogger(__name__)

# Supported image extensions that should be converted to video
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tiff", ".tif"}

# Duration (seconds) for each image when converted to video
IMAGE_VIDEO_DURATION = 20


def is_image(filename: str) -> bool:
    """Return True if *filename* has a recognised image extension."""
    return Path(filename).suffix.lower() in IMAGE_EXTENSIONS


def convert_image_to_video(image_path: str, output_path: str | None = None) -> str:
    """Convert an image file to a 20-second MP4 video using FFmpeg.

    Parameters
    ----------
    image_path:
        Absolute path to the source image.
    output_path:
        Destination path for the output video.  If *None*, the output is
        placed alongside the source image with an ``.mp4`` extension.

    Returns
    -------
    str
        Path to the generated MP4 video file.

    Raises
    ------
    RuntimeError
        If FFmpeg exits with a non-zero return code.
    FileNotFoundError
        If *image_path* does not exist.
    """
    image_path = str(image_path)
    if not os.path.isfile(image_path):
        raise FileNotFoundError(f"Image not found: {image_path}")

    if output_path is None:
        stem = Path(image_path).stem
        output_path = str(Path(image_path).parent / f"{stem}.mp4")

    cmd = [
        "ffmpeg",
        "-y",                          # overwrite output if it exists
        "-loop", "1",                  # loop the still image
        "-i", image_path,              # input file
        "-t", str(IMAGE_VIDEO_DURATION),  # duration in seconds
        "-vf", "scale=1920:1080:force_original_aspect_ratio=decrease,"
               "pad=1920:1080:(ow-iw)/2:(oh-ih)/2",
        "-c:v", "libx264",
        "-preset", "fast",
        "-pix_fmt", "yuv420p",         # maximum compatibility
        "-an",                         # no audio track
        output_path,
    ]

    logger.info("Converting image to video: %s → %s", image_path, output_path)
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        logger.error("FFmpeg error: %s", result.stderr)
        raise RuntimeError(
            f"FFmpeg failed (exit {result.returncode}): {result.stderr}"
        )

    logger.info("Conversion complete: %s", output_path)
    return output_path


def process_upload(upload_path: str) -> str:
    """Process an uploaded file.

    If the file is an image it is converted to a 20-second MP4 video and
    the original image is removed.  Video files are returned unchanged.

    Parameters
    ----------
    upload_path:
        Absolute path to the uploaded file.

    Returns
    -------
    str
        Path to the file ready for distribution (always a video).
    """
    if is_image(upload_path):
        video_path = convert_image_to_video(upload_path)
        os.remove(upload_path)
        logger.info("Removed original image: %s", upload_path)
        return video_path
    return upload_path
