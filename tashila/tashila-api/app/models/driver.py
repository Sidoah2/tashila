from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field


class DriverLocation(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    type: str = "Point"
    coordinates: list[float]  # [lng, lat]


class DocumentEntry(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    url: str
    status: str = "pending"
    rejectionReason: str | None = None
    uploadedAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class EarningsInfo(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    totalEarnedDzd: float = 0.0
    platformDueDzd: float = 0.0
    paidDzd: float = 0.0


class DriverDoc(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    phone: str
    email: str | None = None
    name: str | None = None
    avatarUrl: str | None = None
    truckType: str
    vehiclePlate: str | None = None
    vehicleColor: str | None = None
    vehicleModel: str | None = None
    location: DriverLocation | None = None
    availability: str = "offline"
    approvalStatus: str = "pending"
    rejectionReason: str | None = None
    documents: dict[str, DocumentEntry] = Field(default_factory=dict)
    earnings: EarningsInfo = Field(default_factory=EarningsInfo)
    profileComplete: bool = False
    status: str = "active"
    createdAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updatedAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class DriverResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    phone: str
    email: str | None = None
    name: str | None = None
    avatarUrl: str | None = None
    truckType: str
    vehiclePlate: str | None = None
    vehicleColor: str | None = None
    vehicleModel: str | None = None
    location: DriverLocation | None = None
    availability: str
    approvalStatus: str
    rejectionReason: str | None = None
    profileComplete: bool
    status: str
    createdAt: datetime


class DriverProfileSetup(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: str
    email: str | None = None
    truckType: str
    vehiclePlate: str
    vehicleColor: str
    vehicleModel: str


class DriverUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: str | None = None
    email: str | None = None
    avatarUrl: str | None = None
    truckType: str | None = None
    vehiclePlate: str | None = None
    vehicleColor: str | None = None
    vehicleModel: str | None = None


class DriverAvailabilityUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    availability: str


class DriverLocationUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    lat: float
    lng: float
