#!/usr/bin/env bash
# The sandbox act. Boots (or attaches to) the pre-warmed stack, captures
# initial state, then drops you into an interactive Claude Code session
# INSIDE the sandbox. Paste your prompt live so the audience sees it.
#
# Usage:
#   ./demo/40-good-path.sh
#   ./demo/40-good-path.sh "custom prompt here"
set -euo pipefail

cd "$(dirname "$0")/.."

# Auto-load token from .sandbox/.env if present (gitignored)
if [[ -f .sandbox/.env ]]; then
    set -a; . .sandbox/.env; set +a
fi

PROJECT=workshop-demo
DEFAULT_PROMPT="Add real Postgres persistence to this inventory app. Replace the in-memory store in src/database.py with a SQLAlchemy implementation backed by Postgres. The connection string is in \$DATABASE_URL. Create the schema with a migration. Update src/main.py if needed. All 24 tests in tests/ must still pass when you're done. Run the tests yourself with: uv run pytest"

PROMPT="${1:-$DEFAULT_PROMPT}"

# Make sure the stack is up (00-prewarm should have done this)
docker compose -f .sandbox/docker-compose.yml -p "$PROJECT" up -d --wait > /dev/null

# Start a rollout
ROLLOUT_ID="rollout-$(date +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${HOME}/.sandbox-runs/${ROLLOUT_ID}"
mkdir -p "$ARTIFACT_DIR"
echo "$ARTIFACT_DIR" > /tmp/workshop-artifact-dir
echo "$PROJECT"      > /tmp/workshop-project

echo "=== Rollout ${ROLLOUT_ID} ==="
echo

echo ">> Capturing before-state (tests + schema)..."
docker compose -p "$PROJECT" exec -T workspace uv run pytest --tb=no -q \
    > "$ARTIFACT_DIR/tests-before.txt" 2>&1 || true
docker compose -p "$PROJECT" exec -T postgres \
    pg_dump -U app -s inventory > "$ARTIFACT_DIR/schema-before.sql" 2>/dev/null || true

echo ">> The prompt being auto-fed (so you can stay composed and narrate):"
echo
echo "----------------------------------------------------------"
echo "$PROMPT"
echo "----------------------------------------------------------"
echo
echo ">> Launching Claude inside the sandbox with the prompt pre-submitted."
echo ">> When it finishes, exit and run: ./demo/50-show-artifact.sh"
echo

# Launch interactive Claude in the sandbox with the prompt as a positional
# argument (the `--` separator tells claude to treat what follows as the
# initial user message). This is the same pattern the fabric CLI uses
# (solutions_fabric_cli/workflows/run.py).
# --setting-sources user           : ignore the workshop's project-level hooks
# --dangerously-skip-permissions  : autonomous tool use — safe because we're in a sandbox
docker compose -p "$PROJECT" exec workspace \
    claude --setting-sources user --dangerously-skip-permissions -- "$PROMPT"
