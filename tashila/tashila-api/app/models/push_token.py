from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class PushTokenDoc(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str | None = Field(default=None, alias="_id")
    ownerId: str
    role: str
    token: str
    platform: str
    createdAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class PushTokenRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    token: str
    platform: Literal["fcm", "apns"] = "fcm"


class PushTokenResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    ownerId: str
    role: str
    token: str
    platform: str
    createdAt: datetime
