# `demo/` — Notes for humans and agents

This folder is the on-stage demo for the **Sandboxes for Agents** talk. Read this before running anything or working in here.

## Audience

- **Human operators** running the live demo: jump to [`RUNBOOK.md`](RUNBOOK.md) for the copy-paste playbook
- **Agents (Claude or other) invoked inside the sandbox during the demo**: read the [Your job](#your-job-if-youre-an-agent-invoked-from-40-good-pathsh) section below
- **Engineers reading later**: read [The thesis tension](#the-thesis-tension) so you understand why this is structured the way it is

---

## What the demo does

End-to-end task: give Claude an isolated docker-compose stack (Postgres + a workspace container with the FastAPI source) and ask it to replace the in-memory product store with real Postgres persistence — autonomously, with no babysitting, and with the full sandbox lifecycle visible to the audience.

The full live flow lives in [`RUNBOOK.md`](RUNBOOK.md). The off-stage non-interactive confidence runner is `99-full-test.sh`.

## The scripts at a glance

| Script | Purpose | When to run |
|---|---|---|
| `00-prewarm.sh` | Pre-build the workspace image so on-stage boot is ~5s instead of ~90s | Once, ~60s before the talk |
| `10-show-app.sh` | Boot the workshop FastAPI on host port 8001 (in-memory, "before" state) | During Act 1 narration |
| `30-reset.sh` | Stop the host API + revert host source edits | Between acts |
| `40-good-path.sh` | **The main on-stage demo.** Five visible phases: spin up sandbox → snapshot → Claude works inside → snapshot → teardown (with pause for the Postgres-kill demo) | Act 4 |
| `50-show-artifact.sh` | *Legacy* — manual artifact capture. `40-good-path.sh` does this inline now. Kept as a fallback | Optional |
| `99-full-test.sh` | Off-stage confidence run in an isolated compose project, with auto-teardown and pass/fail evaluation | Before the talk, as a smoke test |
| `RUNBOOK.md` | Human-operator playbook with copy-paste blocks for every act | On stage |

## How the sandbox is built

Outside this folder, at the repo root, `.sandbox/` holds:

- `docker-compose.yml` — `postgres:16-alpine` + a `workspace` container (built from the next file)
- `Dockerfile.workspace` — Python 3.12 + Node 22 + Claude Code CLI + `uv` + git + psql client, runs as a non-root `agent` user (uid 1000) so `--dangerously-skip-permissions` is allowed
- `Dockerfile.workspace.dockerignore` — keeps build context clean (excludes `.venv`, `.git`, caches, etc.)
- `stack.yaml` — recipe metadata
- `.env` (gitignored) — holds `CLAUDE_CODE_OAUTH_TOKEN` minted via `claude setup-token`

The `40-good-path.sh` script handles the outer lifecycle: `docker compose up`, capture, exec into the workspace container, capture again, `docker compose down -v`.

---

## Your job (if you're an agent invoked from `40-good-path.sh`)

You're running **inside** the workspace container. Specifically:

- You're `agent` (uid 1000), `pwd=/workspace`, in a Linux container
- The host filesystem is not reachable. Your edits stay inside this container
- A Postgres service is running as a sibling container at `$DATABASE_URL` (`postgresql://app:app@postgres:5432/inventory`). It's empty when you start
- Your changes will be captured by the host script after you exit (`git diff`, `pg_dump`, `pytest` output, container logs, all bundled into a tarball)
- You were launched with `--dangerously-skip-permissions` and `--setting-sources user`, so workshop-level hooks are disabled and you can run tool calls without prompting

Default task: **add real Postgres persistence to this inventory app.** Specifically:
- Replace the in-memory dict in `src/database.py` with a real ORM-backed implementation (SQLAlchemy is the conventional choice)
- Use `$DATABASE_URL` from the environment
- Create the schema (Alembic migration is fine — `alembic init`, write the migration, `alembic upgrade head`)
- The 28 products from `src/seed_data.py` must still load on startup
- All 24 existing tests in `tests/` must still pass — run them yourself with `uv run pytest`

When you're done, exit (Ctrl-D or `/exit`). The host script picks up from there.

### What you SHOULDN'T do

- Don't try to start additional Docker daemons — there's no DinD inside this workspace
- Don't try to reach the host network — the only reachable services are `postgres` (the sibling container) and the standard internet (which is allowed for `pip`, `uv`, `npm`, etc.)
- Don't worry about cleanup — the entire container is destroyed at the end of the rollout
- Don't ask for permission — `--dangerously-skip-permissions` is set deliberately because we're already in the sandbox

---

## The thesis tension

The talk this demo supports argues:

> Agents inherit the environment you give them. The team with the best DevOps wins. The sandbox is your isolation, audit, and policy-enforcement point — one primitive, three jobs.

In other words: **the agent should manage its environment, not have it babysat by external scaffolding.** That's the lesson.

So why does `40-good-path.sh` orchestrate the Postgres lifecycle from the outside? Honest answer: pragmatism. The demo was built fast and `docker compose` was the easiest way to get a service the agent could talk to. The bash script bringing up Postgres is a thesis violation — the talk argues *agents do this kind of thing*, and the script doing it instead is the opposite.

What's *not* a violation: bash bringing up the **outer sandbox boundary**. Something has to create the workspace container before there's a "Claude inside" to ask. Bootstrap.

### The intended next iteration

Drop Postgres from `docker-compose.yml`. Bake `postgresql-server` into `Dockerfile.workspace`. Rewrite the prompt: *"This sandbox has Postgres installed but not running. Start it. Add real Postgres persistence to the inventory app. Run the tests. Stop Postgres when done."* The agent's transcript becomes the whole environmental lifecycle: `pg_ctlcluster start`, `createdb`, migration, tests, `pg_ctlcluster stop`. The bash shrinks to: boot workspace → run Claude → tear down workspace. The slide that says *"the team with the best DevOps wins"* is followed by a demo where **the agent does the DevOps**.

That refactor isn't shipped here yet. The current demo is honest scaffolding, not the destination.

---

## Customizing

- **Override the prompt**: `./demo/40-good-path.sh "your custom task"` or `./demo/99-full-test.sh "..."`
- **Switch model**: `CLAUDE_MODEL=sonnet ./demo/40-good-path.sh` (default is `opus`)
- **Skip teardown** (leave sandbox alive): `KEEP_STACK=1 ./demo/40-good-path.sh`

## Auth

Each operator mints their own long-lived OAuth token via `claude setup-token` and stores it in `.sandbox/.env`. The file is gitignored. See [`../.sandbox/README.md`](../.sandbox/README.md) for the one-time setup.
