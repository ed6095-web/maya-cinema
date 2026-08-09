"""
MAYA Backend — File Utilities
Safe server-side filename generation and file type validation.
Never trust client-provided filenames or MIME types.
"""
import hashlib
import mimetypes
import os
import uuid
from pathlib import Path

# Allowed video MIME types
ALLOWED_VIDEO_TYPES = {
    "video/mp4",
    "video/x-matroska",
    "video/webm",
    "video/quicktime",
    "video/x-msvideo",
    "video/mpeg",
}

# Allowed image MIME types (for posters)
ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
}

# Max file sizes
MAX_POSTER_SIZE_MB = 10
MAX_VIDEO_SIZE_GB = 50

VIDEO_EXTENSIONS = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".mpeg", ".mpg"}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def generate_safe_filename(original_filename: str, prefix: str = "") -> str:
    """
    Generate a unique, safe server-side filename.
    Never uses the client-provided filename directly.
    Format: {prefix}_{uuid}.{ext}
    """
    suffix = Path(original_filename).suffix.lower()
    unique_id = uuid.uuid4().hex
    name = f"{prefix}_{unique_id}{suffix}" if prefix else f"{unique_id}{suffix}"
    return name


def validate_video_file(filename: str, content_type: str | None, file_size: int) -> None:
    """
    Validate uploaded video file.
    Raises ValueError with a user-friendly message on failure.
    """
    ext = Path(filename).suffix.lower()
    if ext not in VIDEO_EXTENSIONS:
        raise ValueError(f"Unsupported video format '{ext}'. Allowed: {', '.join(VIDEO_EXTENSIONS)}")

    max_bytes = MAX_VIDEO_SIZE_GB * 1024 * 1024 * 1024
    if file_size > max_bytes:
        raise ValueError(f"Video file too large. Maximum size is {MAX_VIDEO_SIZE_GB} GB.")


def validate_image_file(filename: str, content_type: str | None, file_size: int) -> None:
    """
    Validate uploaded image/poster file.
    Raises ValueError with a user-friendly message on failure.
    """
    ext = Path(filename).suffix.lower()
    if ext not in IMAGE_EXTENSIONS:
        raise ValueError(f"Unsupported image format '{ext}'. Allowed: {', '.join(IMAGE_EXTENSIONS)}")

    max_bytes = MAX_POSTER_SIZE_MB * 1024 * 1024
    if file_size > max_bytes:
        raise ValueError(f"Image file too large. Maximum size is {MAX_POSTER_SIZE_MB} MB.")


def ensure_directory(path: str) -> Path:
    """Create directory if it doesn't exist, return Path object."""
    p = Path(path)
    p.mkdir(parents=True, exist_ok=True)
    return p


def get_file_size(path: str) -> int:
    """Return file size in bytes. Returns 0 if file doesn't exist."""
    try:
        return os.path.getsize(path)
    except OSError:
        return 0


def safe_delete_file(path: str) -> bool:
    """Safely delete a file. Returns True on success, False if not found."""
    try:
        Path(path).unlink(missing_ok=True)
        return True
    except OSError:
        return False
