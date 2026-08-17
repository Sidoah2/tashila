from pydantic import BaseModel, ConfigDict, Field


class ServiceAreaCenter(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    lat: float
    lng: float


class PlatformSettingsResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    commissionRate: float = Field(default=0.10, ge=0, le=1)
    serviceAreaCenter: ServiceAreaCenter
    serviceAreaRadiusKm: float = Field(default=50.0, ge=1, le=1000)
    maxDispatchDistanceKm: float = Field(default=50.0, ge=1, le=1000)


class PlatformSettingsUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    commissionRate: float | None = Field(default=None, ge=0, le=1)
    serviceAreaCenter: ServiceAreaCenter | None = None
    serviceAreaRadiusKm: float | None = Field(default=None, ge=1, le=1000)
    maxDispatchDistanceKm: float | None = Field(default=None, ge=1, le=1000)
