#!/usr/bin/env bash
# Pre-warm the sandbox stack ~60s before the demo so cold boot doesn't eat
# stage time. Builds the workspace image, brings up postgres, runs smoke
# checks. Idempotent.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT=workshop-demo

# Auto-load token from .sandbox/.env if present (gitignored)
if [[ -f .sandbox/.env ]]; then
    set -a; . .sandbox/.env; set +a
fi

if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    echo "ERROR: CLAUDE_CODE_OAUTH_TOKEN is not set." >&2
    echo "" >&2
    echo "  Mint one (interactive, one-time):" >&2
    echo "      env -u ANTHROPIC_BASE_URL -u CLAUDE_CODE_CMD claude setup-token" >&2
    echo "" >&2
    echo "  Then export it:" >&2
    echo "      export CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-..." >&2
    echo "" >&2
    echo "  Or persist it for this repo:" >&2
    echo "      echo 'CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...' > .sandbox/.env" >&2
    exit 1
fi

echo ">> Building & pre-warming sandbox stack..."
docker compose -f .sandbox/docker-compose.yml -p "$PROJECT" up -d --build --wait

echo ">> Smoke check: Postgres ready"
docker compose -p "$PROJECT" exec -T postgres pg_isready -U app -d inventory > /dev/null

echo ">> Smoke check: Python environment"
docker compose -p "$PROJECT" exec -T workspace uv run python -c "import fastapi, pydantic" > /dev/null

echo ">> Smoke check: Claude Code present and credentials mounted"
docker compose -p "$PROJECT" exec -T workspace claude --version
docker compose -p "$PROJECT" exec -T workspace ls -l /root/.claude/.credentials.json > /dev/null

echo
echo ">> Pre-warmed. Sandbox project: $PROJECT"
echo ">>   Enter shell : docker compose -p $PROJECT exec workspace bash"
echo ">>   Enter Claude: docker compose -p $PROJECT exec workspace claude"
echo ">>   API port    : 8000 (mapped to host)"
