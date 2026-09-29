from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from src.database import Database
from src.models import Category, Product, ProductCreate, ProductUpdate, StatsResponse, Status

app = FastAPI(title="Product Inventory Tracker", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db() -> Database:
    return Database.get()


@app.get("/api/health")
def health_check() -> dict:
    x = app.version
    return {"status": "healthy", "version": x}


@app.get("/api/products")
def list_products(
    category: Category | None = None,
    status: Status | None = None,
    search: str | None = None,
) -> list[Product]:
    db = get_db()
    return db.list_products(category=category, status=status, search=search)


@app.get("/api/products/{product_id}")
def get_product(product_id: str) -> Product:
    db = get_db()
    product = db.get_product(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@app.post("/api/products", status_code=201)
def create_product(product_data: ProductCreate) -> Product:
    db = get_db()
    return db.create_product(product_data)


@app.patch("/api/products/{product_id}")
def update_product(product_id: str, updates: ProductUpdate) -> Product:
    db = get_db()
    product = db.update_product(product_id, updates)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@app.delete("/api/products/{product_id}", status_code=204)
def delete_product(product_id: str) -> None:
    db = get_db()
    if not db.delete_product(product_id):
        raise HTTPException(status_code=404, detail="Product not found")


@app.get("/api/stats")
def get_stats() -> StatsResponse:
    db = get_db()
    return StatsResponse(**db.get_stats())
