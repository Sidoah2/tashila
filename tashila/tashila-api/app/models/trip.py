from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field


class TripCoord(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    lat: float
    lng: float
    address: str = ""


class TripDoc(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    status: str
    clientId: str
    driverId: str | None = None
    pickup: TripCoord
    dropoff: TripCoord
    truckType: str
    fare: float
    finalFare: float | None = None
    paymentMethod: str
    notes: str | None = None
    driverRating: int | None = None
    clientRating: int | None = None
    driverRatingComment: str | None = None
    cancelledReason: str | None = None
    createdAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updatedAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    completedAt: datetime | None = None


class TripEstimateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    pickup: TripCoord
    dropoff: TripCoord
    truckType: str


class TripEstimateResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    distanceKm: float
    estimatedMinutes: int
    fare: float
    currency: str = "DZD"


class TripCreateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    pickup: TripCoord
    dropoff: TripCoord
    truckType: str
    paymentMethod: str
    notes: str | None = None


class TripCreateResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    status: str
    clientId: str
    pickup: TripCoord
    dropoff: TripCoord
    truckType: str
    fare: float
    paymentMethod: str
    createdAt: datetime


class TripStatusUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str


class RatingRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    rating: int = Field(ge=1, le=5)
    comment: str | None = None


class AdminTripDispatchRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    pickup: TripCoord
    dropoff: TripCoord
    truckType: str
    driverId: str
    clientId: str | None = None
    externalLabel: str | None = None
    notes: str | None = None
    paymentMethod: str = "cash"


class AdminTripStatusUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str


class TripResponse(BaseModel):
    """Full trip details for API responses."""

    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    status: str
    clientId: str
    driverId: str | None = None
    pickup: TripCoord
    dropoff: TripCoord
    truckType: str
    fare: float
    finalFare: float | None = None
    paymentMethod: str
    notes: str | None = None
    driverRating: int | None = None
    clientRating: int | None = None
    driverRatingComment: str | None = None
    cancelledReason: str | None = None
    createdAt: datetime
    updatedAt: datetime
    completedAt: datetime | None = None
