#!/usr/bin/env bash
# Full live demo: SPIN UP the sandbox loudly, drop into Claude inside it,
# capture what happened, then TEAR IT DOWN — all in front of the audience.
# The point is to make the sandbox boundary tangible: they watch it come
# into existence, do its work, and disappear.
#
# Usage:
#   ./demo/40-good-path.sh                            # default Postgres prompt + Opus
#   ./demo/40-good-path.sh "custom prompt here"       # custom task
#   CLAUDE_MODEL=sonnet ./demo/40-good-path.sh        # use Sonnet instead of Opus
#   KEEP_STACK=1 ./demo/40-good-path.sh               # skip teardown, leave alive
set -uo pipefail

cd "$(dirname "$0")/.."

if [[ -f .sandbox/.env ]]; then
    set -a; . .sandbox/.env; set +a
fi

if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    echo "ERROR: CLAUDE_CODE_OAUTH_TOKEN is not set." >&2
    echo "  See .sandbox/README.md for setup-token instructions." >&2
    exit 1
fi

PROJECT=workshop-demo
MODEL="${CLAUDE_MODEL:-opus}"
DEFAULT_PROMPT="Add real Postgres persistence to this inventory app. Replace the in-memory store in src/database.py with a SQLAlchemy implementation backed by Postgres. The connection string is in \$DATABASE_URL. Create the schema with a migration. Update src/main.py if needed. All 24 tests in tests/ must still pass when you're done. Run the tests yourself with: uv run pytest"
PROMPT="${1:-$DEFAULT_PROMPT}"

ROLLOUT_ID="rollout-$(date +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${HOME}/.sandbox-runs/${ROLLOUT_ID}"
mkdir -p "$ARTIFACT_DIR"

banner() {
    echo
    echo "======================================================================"
    echo "  $1"
    echo "======================================================================"
}

# ── 1/5  SPIN UP ──────────────────────────────────────────────────────
banner "1/5  SPINNING UP THE SANDBOX"
echo ">> Building image if needed, booting postgres + workspace..."
docker compose -f .sandbox/docker-compose.yml -p "$PROJECT" up -d --build --wait

echo
echo ">> Inside the sandbox (proving the boundary is real):"
docker compose -p "$PROJECT" exec -T workspace bash -c \
    'echo "   hostname : $(hostname)" ; echo "   user     : $(whoami)" ; echo "   pwd      : $(pwd)" ; echo "   db URL   : $DATABASE_URL"'

# ── 2/5  CAPTURE BEFORE-STATE ─────────────────────────────────────────
banner "2/5  CAPTURING BEFORE-STATE"
docker compose -p "$PROJECT" exec -T workspace uv run pytest --tb=no -q \
    > "$ARTIFACT_DIR/tests-before.txt" 2>&1 || true
docker compose -p "$PROJECT" exec -T postgres pg_dump -U app -s inventory \
    > "$ARTIFACT_DIR/schema-before.sql" 2>/dev/null || true
echo "   tests  : $(tail -1 $ARTIFACT_DIR/tests-before.txt)"
echo "   schema : $(grep -cE '^CREATE TABLE' $ARTIFACT_DIR/schema-before.sql || echo 0) table(s)"

# ── 3/5  CLAUDE INSIDE THE SANDBOX ────────────────────────────────────
banner "3/5  CLAUDE WORKING INSIDE THE SANDBOX   (model: $MODEL)"
echo "   Agent has /workspace + the postgres service. Nothing else."
echo "   It cannot reach your laptop. Watch."
echo

# Don't let claude's exit code kill the script — we still want to capture
docker compose -p "$PROJECT" exec workspace \
    claude --model "$MODEL" --setting-sources user --dangerously-skip-permissions -- "$PROMPT" \
    || echo "(claude exited non-zero — continuing to capture anyway)"

# ── 4/5  CAPTURE ARTIFACT ─────────────────────────────────────────────
banner "4/5  CAPTURING THE ROLLOUT ARTIFACT"
docker compose -p "$PROJECT" exec -T workspace uv run pytest --tb=short -q \
    > "$ARTIFACT_DIR/tests-after.txt" 2>&1 || true
docker compose -p "$PROJECT" exec -T postgres pg_dump -U app -s inventory \
    > "$ARTIFACT_DIR/schema-after.sql" 2>/dev/null || true
docker compose -p "$PROJECT" exec -T workspace bash -c \
    'cd /workspace && git add -A && git diff --cached' \
    > "$ARTIFACT_DIR/diff.patch" 2>/dev/null || true
docker compose -p "$PROJECT" logs --no-color > "$ARTIFACT_DIR/container-logs.txt" 2>&1 || true
tar -czf "${ARTIFACT_DIR}.tar.gz" -C "$(dirname "$ARTIFACT_DIR")" "$(basename "$ARTIFACT_DIR")"

echo "   bundle : ${ARTIFACT_DIR}.tar.gz ($(du -h ${ARTIFACT_DIR}.tar.gz | cut -f1))"
echo "   diff   : $(wc -l < $ARTIFACT_DIR/diff.patch) lines"
echo "   tests  : $(tail -1 $ARTIFACT_DIR/tests-after.txt)"
echo "   schema : $(grep -cE '^CREATE TABLE' $ARTIFACT_DIR/schema-after.sql || echo 0) table(s)"

# ── 5/5  SPIN DOWN ────────────────────────────────────────────────────
banner "5/5  TEAR DOWN"

if [[ "${KEEP_STACK:-0}" == "1" ]]; then
    echo "   KEEP_STACK=1 — leaving the sandbox alive for inspection."
    echo "   Tear down later with:"
    echo "     docker compose -p $PROJECT down -v"
    exit 0
fi

echo "   Sandbox is still alive. Inspect it / run the killer Postgres demo"
echo "   if you want. When ready, press Enter to tear it down."
echo "   (Ctrl-C to leave it alive instead.)"
read -r -p "   ⏎ " _

echo
echo ">> Tearing the sandbox down — volumes, network, the whole thing..."
docker compose -f .sandbox/docker-compose.yml -p "$PROJECT" down -v --remove-orphans

echo
echo ">> Gone. Your laptop is unchanged."
echo "   Artifact persisted: ${ARTIFACT_DIR}.tar.gz"
