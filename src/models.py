from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, computed_field


class Category(str, Enum):
    ELECTRONICS = "Electronics"
    SOFTWARE = "Software"
    HARDWARE = "Hardware"
    ACCESSORIES = "Accessories"


class Status(str, Enum):
    IN_STOCK = "In Stock"
    LOW_STOCK = "Low Stock"
    OUT_OF_STOCK = "Out of Stock"


class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    category: Category
    price: float = Field(..., gt=0)
    stock: int = Field(..., ge=0)
    sku: str = Field(..., min_length=1, max_length=50)


class ProductUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    category: Category | None = None
    price: float | None = Field(None, gt=0)
    stock: int | None = Field(None, ge=0)
    sku: str | None = Field(None, min_length=1, max_length=50)


class Product(BaseModel):
    id: str
    name: str
    category: Category
    price: float
    stock: int
    sku: str
    created_at: datetime
    updated_at: datetime

    @computed_field
    @property
    def status(self) -> Status:
        if self.stock > 12:
            return Status.IN_STOCK
        elif self.stock >= 1:
            return Status.LOW_STOCK
        else:
            return Status.OUT_OF_STOCK


class StatsResponse(BaseModel):
    total: int
    in_stock: int
    low_stock: int
    out_of_stock: int
