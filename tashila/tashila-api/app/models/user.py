from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field


class UserDoc(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    phone: str
    name: str | None = None
    avatarUrl: str | None = None
    locale: str = "ar"
    profileComplete: bool = False
    status: str = "active"
    createdAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updatedAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class UserResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    phone: str
    name: str | None = None
    avatarUrl: str | None = None
    locale: str
    profileComplete: bool
    status: str
    createdAt: datetime


class UserProfileSetup(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: str
    locale: str | None = None


class UserUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: str | None = None
    locale: str | None = None
    avatarUrl: str | None = None
