import logging
import traceback
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)


class TashilaException(Exception):
    def __init__(self, message: str, status_code: int = status.HTTP_400_BAD_REQUEST) -> None:
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class NotFoundError(TashilaException):
    def __init__(self, message: str = "Resource not found") -> None:
        super().__init__(message, status_code=status.HTTP_404_NOT_FOUND)


class ForbiddenError(TashilaException):
    def __init__(self, message: str = "Forbidden") -> None:
        super().__init__(message, status_code=status.HTTP_403_FORBIDDEN)


class ValidationError(TashilaException):
    def __init__(self, message: str = "Validation failed") -> None:
        super().__init__(message, status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)


class ConflictError(TashilaException):
    def __init__(self, message: str = "Conflict", *, code: str | None = None) -> None:
        self.code = code
        super().__init__(message, status_code=status.HTTP_409_CONFLICT)


def _format_validation_errors(exc: RequestValidationError) -> list[dict[str, Any]]:
    errors: list[dict[str, Any]] = []
    for error in exc.errors():
        location = ".".join(str(part) for part in error.get("loc", ()))
        errors.append(
            {
                "field": location,
                "message": error.get("msg", "Invalid value"),
                "type": error.get("type"),
            },
        )
    return errors


async def tashila_exception_handler(_request: Request, exc: TashilaException) -> JSONResponse:
    content: dict[str, Any] = {"detail": exc.message}
    if isinstance(exc, ConflictError) and exc.code:
        content["code"] = exc.code
    return JSONResponse(
        status_code=exc.status_code,
        content=content,
    )


async def generic_exception_handler(_request: Request, exc: Exception) -> JSONResponse:
    traceback.print_exception(type(exc), exc, exc.__traceback__)
    logger.exception("Unhandled exception")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"},
    )


async def request_validation_exception_handler(
    _request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "detail": "Validation failed",
            "errors": _format_validation_errors(exc),
        },
    )


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(TashilaException, tashila_exception_handler)
    app.add_exception_handler(RequestValidationError, request_validation_exception_handler)
    app.add_exception_handler(Exception, generic_exception_handler)
