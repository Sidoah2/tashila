from pathlib import Path

from fastapi import APIRouter, Depends, File, UploadFile
from fastapi.responses import FileResponse

from app.core.config import settings
from app.core.deps import get_authenticated_principal
from app.core.exceptions import NotFoundError
from app.services import upload_service

router = APIRouter(prefix="/uploads", tags=["uploads"])


def _safe_path_part(value: str) -> bool:
    return value not in ("", ".", "..") and "/" not in value and "\\" not in value


@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    _principal: dict = Depends(get_authenticated_principal),
) -> dict[str, str]:
    return await upload_service.save_upload(file, subfolder="images")


@router.get("/{filepath:path}")
async def get_upload(
    filepath: str,
    _principal: dict = Depends(get_authenticated_principal),
) -> FileResponse:
    # Protect against path traversal
    clean_parts = [p for p in filepath.replace("\\", "/").split("/") if p]
    if any(p in (".", "..") for p in clean_parts):
        raise NotFoundError("File not found")

    base_dir = Path(settings.upload_dir).resolve()
    file_path = (base_dir / Path(*clean_parts)).resolve()

    try:
        if not file_path.is_relative_to(base_dir):
            raise NotFoundError("File not found")
    except AttributeError:
        # Fallback for older python Path compatibility
        if not str(file_path).startswith(str(base_dir)):
            raise NotFoundError("File not found")

    if not file_path.is_file():
        raise NotFoundError("File not found")

    filename = file_path.name
    media_type = "application/octet-stream"
    if filename.lower().endswith((".jpg", ".jpeg")):
        media_type = "image/jpeg"
    elif filename.lower().endswith(".png"):
        media_type = "image/png"
    elif filename.lower().endswith(".webp"):
        media_type = "image/webp"

    return FileResponse(
        path=file_path,
        media_type=media_type,
        headers={"Cache-Control": "max-age=86400"},
    )
