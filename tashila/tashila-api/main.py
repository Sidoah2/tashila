"""
Local entrypoint shim.

Production (Railway / Procfile) uses: uvicorn app.main:app
"""

from app.main import app  # noqa: F401
