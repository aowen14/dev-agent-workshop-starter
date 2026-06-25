# Demo Runbook

Copy-paste each numbered block as one unit. Comments live outside the blocks so nothing breaks when pasted into a shell.

Working directory for everything below:

```
cd /Users/alexowen/Company/Events/Claude-Code-Meetups/Meetup-02-25-26/dev-agent-workshop-starter
```

---

## 0. Setup (run ~60 seconds before walking on stage)

Builds the image if needed, brings up postgres + workspace, runs smoke checks, confirms the OAuth token is loaded.

```
./demo/00-prewarm.sh
```

If you see `>> Pre-warmed.`, you're good.

---

## 1. Show the in-memory app (Act 1)

Starts the FastAPI on host port 8001 with the in-memory dictionary backend. This is the "before" state.

```
./demo/10-show-app.sh
```

Open in browser:

```
http://localhost:8001/api/products
```

Notes for the audience: 28 products, in-memory dict, every restart wipes the data.

---

## 2. Reset host before going into the sandbox (Act 3)

Stops the host FastAPI and reverts any speculative host edits. Sandbox stays warm.

```
./demo/30-reset.sh
```

---

## 3. The sandbox act (Act 4)

Launches interactive Claude inside the workspace container with the prompt auto-submitted.

```
./demo/40-good-path.sh
```

Stand back, narrate. ~5-8 minutes. When Claude finishes, Ctrl-D out of the session.

---

## 4. Capture the artifact

```
./demo/50-show-artifact.sh
```

Prints diff size, tests-after tail, and bundles a tarball under `~/.sandbox-runs/`.

---

## 5. The five verifications (do these on stage to prove Claude didn't fake it)

### 5a. Confirm the products table exists in Postgres

```
docker compose -p workshop-demo exec postgres psql -U app inventory -c '\dt'
```

You should see `products` and `alembic_version` tables.

### 5b. Confirm 28 rows are loaded

```
docker compose -p workshop-demo exec postgres psql -U app inventory -c 'SELECT COUNT(*) FROM products;'
```

### 5c. Peek at the data

```
docker compose -p workshop-demo exec postgres psql -U app inventory -c 'SELECT id, name, category, stock FROM products LIMIT 5;'
```

### 5d. Run the test suite yourself

```
docker compose -p workshop-demo exec workspace uv run pytest -v
```

Watch 24 PASSes scroll. This is the "Claude isn't lying" check.

### 5e. Read the migration Claude wrote

```
docker compose -p workshop-demo exec workspace cat alembic/versions/001_create_products_table.py
```

(Path may vary if Claude picks a different naming.)

### 5f. Read the rewritten Database class

```
docker compose -p workshop-demo exec workspace bash -c 'cd /workspace && git diff --cached src/database.py | head -60'
```

---

## 6. The killer demo — kill Postgres on stage

This is the moment that proves Claude built real persistence, not a clever in-memory fake.

### 6a. Start the API inside the sandbox

```
docker compose -p workshop-demo exec -d workspace bash -c 'cd /workspace && uv run uvicorn src.main:app --host 0.0.0.0 --port 8000'
```

Wait a beat, then:

### 6b. Confirm real data through real DB

```
sleep 2 && curl -s http://localhost:8000/api/products | jq 'length'
```

Expected: `28`

### 6c. Pull the rug — stop Postgres

```
docker compose -p workshop-demo stop postgres
```

### 6d. Watch the API break

```
curl -i http://localhost:8000/api/products
```

Expected: connection error / 500. Audience sees the failure live.

### 6e. Put it back

```
docker compose -p workshop-demo start postgres
```

### 6f. Confirm it's healed

```
sleep 2 && curl -s http://localhost:8000/api/products | jq 'length'
```

Expected: `28` again. The room exhales.

---

## 7. Live shell inside the sandbox (the "review artifact" pitch)

If you want to drop in and poke around while the sandbox is still alive:

```
docker compose -p workshop-demo exec workspace bash
```

Or open psql directly:

```
docker compose -p workshop-demo exec postgres psql -U app inventory
```

Common psql commands once in: `\dt` to list tables, `SELECT * FROM products LIMIT 3;` to see rows, `\q` to exit.

---

## 8. Reset between dry runs (between rehearsals)

Fast reset — wipe Claude's code changes, drop the table, but keep the sandbox running.

```
docker compose -p workshop-demo exec -T workspace bash -c 'cd /workspace && git stash && git stash drop 2>/dev/null'
```

```
docker compose -p workshop-demo exec -T postgres psql -U app inventory -c 'DROP TABLE IF EXISTS products CASCADE; DROP TABLE IF EXISTS alembic_version CASCADE;'
```

Nuclear reset — tear the whole stack down and rebuild from scratch.

```
docker compose -p workshop-demo down -v
```

```
./demo/00-prewarm.sh
```

---

## The default prompt (in case you want to edit it live)

This is what `40-good-path.sh` auto-feeds. To customize for a given run:

```
./demo/40-good-path.sh "your custom prompt here"
```

The default:

> Add real Postgres persistence to this inventory app. Replace the in-memory store in src/database.py with a SQLAlchemy implementation backed by Postgres. The connection string is in $DATABASE_URL. Create the schema with a migration. Update src/main.py if needed. All 24 tests in tests/ must still pass when you're done. Run the tests yourself with: uv run pytest

---

## Tear down completely after the talk

```
docker compose -p workshop-demo down -v
```

```
pkill -f 'uvicorn src.main' 2>/dev/null
```
