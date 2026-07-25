"""File upload service.

When ``CLOUDINARY_URL`` is set the service uploads to Cloudinary and returns
an absolute ``secure_url``.  When it is not set (local development) it falls
back to writing files to the local ``UPLOAD_DIR`` and returns a relative
``/uploads/…`` URL.
"""

import asyncio
import re
from pathlib import Path
from uuid import uuid4

import aiofiles
from fastapi import UploadFile

from app.core.config import settings
from app.core.exceptions import ValidationError

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SIZE_BYTES = 5 * 1024 * 1024
_CLOUDINARY_PREFIX = "tashila"


def _secure_filename(filename: str | None) -> str:
    if not filename:
        return "file"
    name = filename.replace("\\", "/").split("/")[-1]
    name = re.sub(r"[^A-Za-z0-9._-]", "_", name)
    return name[:255] or "file"


def _use_cloudinary() -> bool:
    return bool(settings.cloudinary_url)


def _configure_cloudinary() -> None:
    import cloudinary  # type: ignore[import-untyped]

    cloudinary.config(cloudinary_url=settings.cloudinary_url)


async def save_upload(file: UploadFile, subfolder: str = "general") -> dict[str, str]:
    content_type = file.content_type or ""
    if content_type not in ALLOWED_TYPES:
        raise ValidationError(
            f"Invalid file type. Allowed: {', '.join(sorted(ALLOWED_TYPES))}",
        )

    content = await file.read(MAX_SIZE_BYTES + 1)
    if len(content) > MAX_SIZE_BYTES:
        raise ValidationError("File size exceeds 5MB limit")

    if _use_cloudinary():
        return await _upload_to_cloudinary(content, subfolder)
    return await _upload_to_disk(content, file.filename, subfolder)


async def delete_upload(key: str, subfolder: str = "general") -> None:
    """Delete a previously uploaded file.

    *key* is either:
    - the Cloudinary ``public_id`` (when Cloudinary is/was in use), e.g.
      ``tashila/avatars/abc123``
    - just the filename on disk (local fallback), e.g. ``abc123_avatar.jpg``
    """
    if not key:
        return
    if _use_cloudinary() or key.startswith(_CLOUDINARY_PREFIX + "/"):
        await _delete_from_cloudinary(key)
    else:
        await _delete_from_disk(key, subfolder)


# ---------------------------------------------------------------------------
# Cloudinary helpers
# ---------------------------------------------------------------------------

async def _upload_to_cloudinary(content: bytes, subfolder: str) -> dict[str, str]:
    import cloudinary.uploader  # type: ignore[import-untyped]

    _configure_cloudinary()
    public_id = f"{_CLOUDINARY_PREFIX}/{subfolder}/{uuid4().hex}"

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        None,
        lambda: cloudinary.uploader.upload(
            content,
            public_id=public_id,
            resource_type="image",
            overwrite=True,
        ),
    )
    return {
        "url": result["secure_url"],
        "key": result["public_id"],
    }


async def _delete_from_cloudinary(public_id: str) -> None:
    import cloudinary.uploader  # type: ignore[import-untyped]

    _configure_cloudinary()
    loop = asyncio.get_event_loop()
    try:
        await loop.run_in_executor(
            None,
            lambda: cloudinary.uploader.destroy(public_id, resource_type="image"),
        )
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Local-disk helpers (development fallback)
# ---------------------------------------------------------------------------

async def _upload_to_disk(
    content: bytes, filename: str | None, subfolder: str
) -> dict[str, str]:
    unique_name = f"{uuid4().hex}_{_secure_filename(filename)}"
    target_dir = Path(settings.upload_dir) / subfolder
    target_dir.mkdir(parents=True, exist_ok=True)
    file_path = target_dir / unique_name

    async with aiofiles.open(file_path, "wb") as out_file:
        await out_file.write(content)

    return {
        "url": f"/uploads/{subfolder}/{unique_name}",
        "key": unique_name,
    }


async def _delete_from_disk(key: str, subfolder: str) -> None:
    file_path = Path(settings.upload_dir) / subfolder / key
    try:
        file_path.unlink(missing_ok=True)
    except OSError:
        pass
