# Sandbox

Give Claude Code an isolated copy of this stack to work in. Run a task,
capture the rollout, optionally keep the sandbox alive for review.

## Why

Your laptop is not a safe place for an autonomous agent to migrate a
database, install dependencies, or restructure code. The sandbox gives
the agent something it *can* break — and gives you a captured artifact
of exactly what it did.

## Prereqs

- Docker Desktop running
- Claude Code installed and logged in on the host (`claude` CLI works
  and `~/.claude/.credentials.json` exists)

## Quick start

```bash
./demo/00-prewarm.sh           # 60s before the demo: build + warm
./demo/40-good-path.sh         # boot + drop into Claude inside sandbox
./demo/50-show-artifact.sh     # after Claude exits: capture & inspect
```

## What gets captured

After a rollout, look in `~/.sandbox-runs/<rollout-id>/`:

- `tests-before.txt` / `tests-after.txt` — pytest output bracketing the change
- `schema-before.sql` / `schema-after.sql` — pg_dump of the public schema
- `diff.patch` — `git diff` of the agent's code changes
- `container-logs.txt` — postgres + workspace stdout/stderr
- The whole folder is also bundled to `<rollout-id>.tar.gz`

## Substrate choice

This demo uses plain `docker compose`. The same recipe can be lifted
onto Docker sbx, Microsandbox, or Daytona — see `stack.yaml`.

## Authentication

The container needs a long-lived OAuth token. One-time setup:

```bash
# Clear any local proxy env vars and mint a token (opens browser)
env -u ANTHROPIC_BASE_URL -u CLAUDE_CODE_CMD claude setup-token

# Export the printed token (or save to .sandbox/.env)
export CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
```

The token is long-lived and works headlessly. Don't commit it — `.sandbox/.env`
is gitignored.
