# Demo Runbook

Copy-paste each numbered block as one unit. Comments live outside the blocks so nothing breaks when pasted into a shell.

Working directory for everything below:

```
cd /Users/alexowen/Company/Events/Claude-Code-Meetups/Meetup-02-25-26/dev-agent-workshop-starter
```

---

## 0. Setup (run ~60 seconds before walking on stage)

Pre-builds the workspace image so the on-stage spin-up is fast (~5-10s instead of ~90s).

```
./demo/00-prewarm.sh
```

If you see `>> Pre-warmed.`, you're good. The pre-warm leaves a stack running; `40-good-path.sh` will tear it down and bring up a fresh one, but the cached image makes that boot near-instant.

---

## 1. Show the in-memory app (Act 1)

Starts the FastAPI on host port 8001 with the in-memory dictionary backend. The React frontend is at `http://localhost:5177` (proxies to 8001). This is the "before" state — point the audience at the styled UI.

```
./demo/10-show-app.sh
```

Notes for the audience: 28 products, in-memory dict, every restart wipes the data.

---

## 2. Reset host before going into the sandbox

Stops the host FastAPI and reverts any speculative host edits.

```
./demo/30-reset.sh
```

---

## 3. The sandbox act — full lifecycle (Act 4)

One command. Five visible phases the audience walks through with you:

1. **SPIN UP** — `docker compose up --build --wait` runs live; smoke-checks print the agent's hostname / pwd / `$DATABASE_URL` so the boundary is tangible
2. **CAPTURE BEFORE** — pytest + pg_dump snapshot of the in-memory baseline
3. **CLAUDE WORKING INSIDE** — interactive Claude (default model: Opus) with the prompt auto-submitted
4. **CAPTURE AFTER** — pytest + pg_dump + git diff, bundled to `~/.sandbox-runs/<id>.tar.gz`
5. **TEAR DOWN** — script *pauses* (`Press Enter to tear down…`). Run §4 verifications and §5 killer demo *during the pause*. When you press Enter, the sandbox is destroyed on screen.

```
./demo/40-good-path.sh
```

Knobs:
- `./demo/40-good-path.sh "custom prompt"` — override the default task
- `CLAUDE_MODEL=sonnet ./demo/40-good-path.sh` — drop to Sonnet for cost/speed
- `KEEP_STACK=1 ./demo/40-good-path.sh` — skip the teardown pause, leave it alive

When Claude finishes, Ctrl-D out of the session. The script keeps going automatically.

---

## 4. Verifications during the teardown pause (prove Claude didn't fake it)

### 4a. Confirm the products table exists in Postgres

```
docker compose -p workshop-demo exec postgres psql -U app inventory -c '\dt'
```

You should see `products` and `alembic_version` tables.

### 4b. Confirm 28 rows are loaded

```
docker compose -p workshop-demo exec postgres psql -U app inventory -c 'SELECT COUNT(*) FROM products;'
```

### 4c. Peek at the data

```
docker compose -p workshop-demo exec postgres psql -U app inventory -c 'SELECT id, name, category, stock FROM products LIMIT 5;'
```

### 4d. Run the test suite yourself

```
docker compose -p workshop-demo exec workspace uv run pytest -v
```

Watch 24 PASSes scroll. This is the "Claude isn't lying" check.

### 4e. Read the migration Claude wrote

```
docker compose -p workshop-demo exec workspace cat alembic/versions/001_create_products_table.py
```

(Path may vary if Claude picks different naming.)

### 4f. Read the rewritten Database class

```
docker compose -p workshop-demo exec workspace bash -c 'cd /workspace && git diff src/database.py | head -60'
```

---

## 5. The killer demo — kill Postgres on stage (during the teardown pause)

This is the moment that proves Claude built real persistence, not a clever in-memory fake.

### 5a. Start the API inside the sandbox

```
docker compose -p workshop-demo exec -d workspace bash -c 'cd /workspace && uv run uvicorn src.main:app --host 0.0.0.0 --port 8000'
```

Wait a beat, then:

### 5b. Confirm real data through real DB

```
sleep 2 && curl -s http://localhost:8000/api/products | jq 'length'
```

Expected: `28`

### 5c. Pull the rug — stop Postgres

```
docker compose -p workshop-demo stop postgres
```

### 5d. Watch the API break

```
curl -i http://localhost:8000/api/products
```

Expected: connection error / 500. Audience sees the failure live.

### 5e. Put it back

```
docker compose -p workshop-demo start postgres
```

### 5f. Confirm it's healed

```
sleep 2 && curl -s http://localhost:8000/api/products | jq 'length'
```

Expected: `28` again. The room exhales.

---

## 6. Finish — press Enter at the teardown prompt

Return to the terminal where `40-good-path.sh` is paused and press Enter. The sandbox tears down on screen — volumes, network, container — and the script confirms your laptop is unchanged.

If you want to abort the teardown and leave the sandbox alive, Ctrl-C at the prompt.

---

## 7. Reset between dry runs (between rehearsals)

If you ran the demo with `KEEP_STACK=1` or Ctrl-C'd the teardown, reset state for the next pass:

```
docker compose -p workshop-demo exec -T workspace bash -c 'cd /workspace && git reset --hard HEAD && git clean -fd && uv sync --frozen --extra dev'
```

```
docker compose -p workshop-demo exec -T postgres psql -U app inventory -c 'DROP TABLE IF EXISTS products CASCADE; DROP TABLE IF EXISTS alembic_version CASCADE;'
```

Or nuclear — tear everything down and rebuild:

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

If anything's still running (the host API, a leftover sandbox, etc.):

```
docker compose -p workshop-demo down -v
```

```
pkill -f 'uvicorn src.main' 2>/dev/null
```

---

## Confidence run (off-stage, before the talk)

Same flow as on-stage but non-interactive (`--print`), in its own isolated compose project (`workshop-test`), with auto-teardown. Use this to verify Opus still produces 24 passing tests on the latest prompt.

```
./demo/99-full-test.sh
```

~8–12 min, ~$4 on Opus. Set `CLAUDE_MODEL=sonnet` to drop to ~$1 and ~7 min.
