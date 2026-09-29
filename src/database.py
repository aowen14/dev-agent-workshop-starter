import uuid
from datetime import datetime, timezone

from src.models import Category, Product, ProductCreate, ProductUpdate, Status
from src.seed_data import SEED_PRODUCTS


class Database:
    _instance: "Database | None" = None

    def __init__(self) -> None:
        self._products: dict[str, dict] = {}
        self._load_seed_data()

    @classmethod
    def get(cls) -> "Database":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    @classmethod
    def reset(cls) -> None:
        cls._instance = None

    def _load_seed_data(self) -> None:
        for item in SEED_PRODUCTS:
            product_id = str(uuid.uuid4())
            now = datetime.now(timezone.utc)
            self._products[product_id] = {
                "id": product_id,
                "name": item["name"],
                "category": item["category"],
                "price": item["price"],
                "stock": item["stock"],
                "sku": item["sku"],
                "created_at": now,
                "updated_at": now,
            }

    def _to_product(self, data: dict) -> Product:
        return Product(**data)

    def list_products(
        self,
        category: Category | None = None,
        status: Status | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int | None = None,
    ) -> list[Product]:
        products = [self._to_product(p) for p in self._products.values()]

        if category:
            products = [p for p in products if p.category == category]
        if status:
            products = [p for p in products if p.status == status]
        if search:
            search_lower = search.lower()
            products = [p for p in products if search_lower in p.name.lower()]

        products = sorted(products, key=lambda p: p.name)
        if page_size is not None:
            # Pages are 1-based.
            start = page * page_size
            products = products[start : start + page_size]
        return products

    def get_product(self, product_id: str) -> Product | None:
        data = self._products.get(product_id)
        if data is None:
            return None
        return self._to_product(data)

    def create_product(self, product_data: ProductCreate) -> Product:
        product_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc)
        data = {
            "id": product_id,
            "name": product_data.name,
            "category": product_data.category,
            "price": product_data.price,
            "stock": product_data.stock,
            "sku": product_data.sku,
            "created_at": now,
            "updated_at": now,
        }
        self._products[product_id] = data
        return self._to_product(data)

    def update_product(self, product_id: str, updates: ProductUpdate) -> Product | None:
        if product_id not in self._products:
            return None
        data = self._products[product_id]
        update_fields = updates.model_dump(exclude_unset=True)
        for key, value in update_fields.items():
            data[key] = value
        data["updated_at"] = datetime.now(timezone.utc)
        return self._to_product(data)

    def delete_product(self, product_id: str) -> bool:
        if product_id not in self._products:
            return False
        del self._products[product_id]
        return True

    def get_stats(self) -> dict[str, int]:
        products = [self._to_product(p) for p in self._products.values()]
        return {
            "total": len(products),
            "in_stock": sum(1 for p in products if p.status == Status.IN_STOCK),
            "low_stock": sum(1 for p in products if p.status == Status.LOW_STOCK),
            "out_of_stock": sum(1 for p in products if p.status == Status.OUT_OF_STOCK),
        }
