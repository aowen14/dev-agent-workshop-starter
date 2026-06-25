# Product Inventory Tracker

## Build & Run

```bash
# Backend
uv sync --all-extras          # Install all dependencies
uv run uvicorn src.main:app --reload --port 8000

# Frontend
cd frontend && pnpm install
pnpm dev                      # Starts on :5173, proxies /api to :8000

# Both at once
./scripts/run-dev.sh

# Tests
uv run pytest                 # Run all tests
uv run pytest -v              # Verbose output
uv run pytest tests/test_products.py  # Run specific file

# Lint
uv run ruff check src/        # Check for issues
uv run ruff format src/       # Auto-format
```

## Architecture

- **Backend**: FastAPI (Python) — `src/` directory
  - `src/models.py` — Pydantic models (Product, ProductCreate, ProductUpdate, StatsResponse)
  - `src/database.py` — In-memory dict-based store (singleton pattern)
  - `src/seed_data.py` — 28 seed products across 4 categories
  - `src/main.py` — FastAPI app with CORS and all endpoints
- **Frontend**: React + Vite + Tailwind — `frontend/src/` directory
- **Tests**: pytest + httpx — `tests/` directory

## API Reference

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/health | Health check |
| GET | /api/products | List products (?category=, ?status=, ?search=) |
| GET | /api/products/{id} | Get single product |
| POST | /api/products | Create product (201) |
| PATCH | /api/products/{id} | Partial update |
| DELETE | /api/products/{id} | Delete product (204) |
| GET | /api/stats | Inventory stats (total, in_stock, low_stock, out_of_stock) |

## Conventions

- Use type hints on all function signatures
- Use Pydantic models for request/response validation
- Run `uv run pytest` after making changes to verify tests pass
- Product status is always computed from stock, never stored:
  - stock > 10 → "In Stock"
  - stock 1-10 → "Low Stock"
  - stock 0 → "Out of Stock"
- Categories: Electronics, Software, Hardware, Accessories

## UI Verification via Sub-Agent

For context-efficient UI checking, delegate to the `ui-checker` sub-agent (Sonnet) instead of running agent-browser directly. This keeps browser output out of the main context.

### When to Use
- After backend/frontend changes that should reflect in the UI
- When verifying API/UI consistency without consuming context on browser output
- Prefer this over running agent-browser directly in the main session

### Handoff Protocol
1. Write `/tmp/check-ui-request.json`:
   ```json
   {"url": "http://localhost:5174", "checks": ["stats", "products", "rendering"], "context": "what changed"}
   ```
2. Launch the sub-agent with `model: sonnet`:
   ```
   prompt: "You are the ui-checker agent. Read .claude/agents/ui-checker.md for your full instructions, then execute the protocol."
   ```
3. Read `/tmp/check-ui-result.md` for the structured verdict.

### Check Types
- `stats` — Verify stats bar matches /api/stats
- `products` — Verify product table row count matches /api/products
- `rendering` — Check for HTML entity issues, broken layout
