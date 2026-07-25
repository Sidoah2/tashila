from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field


class PricingDoc(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str | None = Field(default=None, alias="_id")
    truckType: str
    label: str
    baseFareDzd: float
    pricePerKmDzd: float
    updatedAt: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class PricingUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    label: str | None = None
    baseFareDzd: float | None = None
    pricePerKmDzd: float | None = None


class PricingResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    truckType: str
    label: str
    baseFareDzd: float
    pricePerKmDzd: float
    updatedAt: datetime
