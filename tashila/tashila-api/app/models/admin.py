from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field


class AdminDoc(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    email: str
    passwordHash: str
    name: str
    role: str = "admin"
    status: str = "active"  # "active" | "suspended"
    createdAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class AdminLoginRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    email: str
    password: str


class AdminSummary(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    email: str
    name: str
    role: str


class AdminLoginResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    accessToken: str
    refreshToken: str
    admin: AdminSummary


class AdminCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    email: str
    password: str
    name: str
    role: str = "admin"


class AdminUserStatusUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str


class AdminDriverStatusUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str


class AdminDriverCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    phone: str
    name: str
    truckType: str
    vehiclePlate: str
    vehicleColor: str
    vehicleModel: str


class AdminDriverApprovalUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str
    reason: str | None = None


class AdminDocumentStatusUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str
    rejectionReason: str | None = None


class AdminDriverAvailabilityUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    availability: str


class AdminDriverPaymentCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    amountDzd: float
    note: str | None = None


class AdminProfileUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    email: str | None = None
    password: str | None = None
    name: str | None = None


class AdminAccountStatusUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str
