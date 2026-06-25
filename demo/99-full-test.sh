#!/usr/bin/env bash
# End-to-end test: build + spin up an isolated stack, run the Postgres-migration
# task autonomously with --print, capture the artifact, then tear everything
# down. Uses its own compose project name (workshop-test) so it never collides
# with the on-stage `workshop-demo` instance.
#
# Cost note: this runs Opus by default and the task takes ~5-10 minutes.
# Expect $1-2 per run. Override with: CLAUDE_MODEL=sonnet ./demo/99-full-test.sh
#
# Usage:
#   ./demo/99-full-test.sh                     # use default prompt + Opus
#   ./demo/99-full-test.sh "custom prompt"     # custom task
#   CLAUDE_MODEL=sonnet ./demo/99-full-test.sh # use Sonnet instead
#   KEEP_STACK=1 ./demo/99-full-test.sh        # leave stack running for inspection
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .sandbox/.env ]]; then
    set -a; . .sandbox/.env; set +a
fi

if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    echo "ERROR: CLAUDE_CODE_OAUTH_TOKEN not set." >&2
    echo "  See .sandbox/README.md for setup-token instructions." >&2
    exit 1
fi

PROJECT="workshop-test"
MODEL="${CLAUDE_MODEL:-opus}"
DEFAULT_PROMPT="Add real Postgres persistence to this inventory app. Replace the in-memory store in src/database.py with a SQLAlchemy implementation backed by Postgres. The connection string is in \$DATABASE_URL. Create the schema with a migration. Update src/main.py if needed. All 24 tests in tests/ must still pass when you're done. Run the tests yourself with: uv run pytest"
PROMPT="${1:-$DEFAULT_PROMPT}"

ROLLOUT_ID="fulltest-$(date +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${HOME}/.sandbox-runs/${ROLLOUT_ID}"
mkdir -p "$ARTIFACT_DIR"

echo "=================================================================="
echo "  Full end-to-end test"
echo "  Rollout : $ROLLOUT_ID"
echo "  Project : $PROJECT  (isolated from workshop-demo)"
echo "  Model   : $MODEL"
echo "  Artifact: $ARTIFACT_DIR"
echo "=================================================================="
echo

# Tear down any leftover from a previous failed run
trap 'teardown' INT TERM

teardown() {
    if [[ "${KEEP_STACK:-0}" != "1" ]]; then
        echo
        echo ">> Tearing down stack..."
        docker compose -f .sandbox/docker-compose.yml -p "$PROJECT" down -v --remove-orphans 2>&1 | tail -3 || true
    else
        echo
        echo ">> KEEP_STACK=1 set — leaving stack alive for inspection."
        echo "   Inspect : docker compose -p $PROJECT exec workspace bash"
        echo "   Teardown: docker compose -p $PROJECT down -v"
    fi
}

START_TS=$(date +%s)

echo ">> [1/6] Building + booting sandbox stack..."
docker compose -f .sandbox/docker-compose.yml -p "$PROJECT" up -d --build --wait 2>&1 | tail -5

echo
echo ">> [2/6] Smoke checks..."
docker compose -p "$PROJECT" exec -T postgres pg_isready -U app -d inventory > /dev/null
docker compose -p "$PROJECT" exec -T workspace claude --version
docker compose -p "$PROJECT" exec -T workspace bash -c 'ls /workspace/src > /dev/null'

echo
echo ">> [3/6] Capturing before-state..."
docker compose -p "$PROJECT" exec -T workspace uv run pytest --tb=no -q \
    > "$ARTIFACT_DIR/tests-before.txt" 2>&1 || true
docker compose -p "$PROJECT" exec -T postgres pg_dump -U app -s inventory \
    > "$ARTIFACT_DIR/schema-before.sql" 2>/dev/null || true
echo "   tests-before: $(tail -1 $ARTIFACT_DIR/tests-before.txt)"

echo
echo ">> [4/6] Running Claude autonomously (model: $MODEL)..."
echo "         Task: ${PROMPT:0:120}..."
TASK_START=$(date +%s)
docker compose -p "$PROJECT" exec -T workspace bash -c "cd /workspace && claude --print --dangerously-skip-permissions --setting-sources user --model '$MODEL' -- \"\$1\" < /dev/null" _ "$PROMPT" \
    > "$ARTIFACT_DIR/claude-transcript.txt" 2>&1 || {
        echo "   Claude exited non-zero — continuing capture anyway"
    }
TASK_END=$(date +%s)
echo "   Claude finished in $((TASK_END-TASK_START))s"

echo
echo ">> [5/6] Capturing after-state + artifact bundle..."
docker compose -p "$PROJECT" exec -T workspace uv run pytest --tb=short -q \
    > "$ARTIFACT_DIR/tests-after.txt" 2>&1 || true
docker compose -p "$PROJECT" exec -T postgres pg_dump -U app -s inventory \
    > "$ARTIFACT_DIR/schema-after.sql" 2>/dev/null || true
docker compose -p "$PROJECT" exec -T workspace bash -c \
    'cd /workspace && git add -A && git diff --cached' \
    > "$ARTIFACT_DIR/diff.patch" 2>/dev/null || true
docker compose -p "$PROJECT" logs --no-color > "$ARTIFACT_DIR/container-logs.txt" 2>&1 || true
tar -czf "${ARTIFACT_DIR}.tar.gz" -C "$(dirname "$ARTIFACT_DIR")" "$(basename "$ARTIFACT_DIR")"

END_TS=$(date +%s)
TOTAL=$((END_TS - START_TS))

echo
echo ">> [6/6] Results"
echo "   Total wall-clock      : ${TOTAL}s"
echo "   Claude run            : $((TASK_END-TASK_START))s"
echo "   Diff size             : $(wc -l < $ARTIFACT_DIR/diff.patch) lines"
echo "   Tests-after (tail)    :"
tail -3 "$ARTIFACT_DIR/tests-after.txt" | sed 's/^/     /'
echo "   Schema-after tables   : $(grep -cE '^CREATE TABLE' $ARTIFACT_DIR/schema-after.sql || echo 0)"
echo "   Artifact bundle       : ${ARTIFACT_DIR}.tar.gz ($(du -h ${ARTIFACT_DIR}.tar.gz | cut -f1))"

# Pass/fail evaluation
PASS_LINE=$(grep -E "passed|failed" "$ARTIFACT_DIR/tests-after.txt" | tail -1 || echo "")
if echo "$PASS_LINE" | grep -qE "24 passed" ; then
    echo
    echo "✅ PASS — all 24 tests passing after Claude's changes"
    RESULT=0
else
    echo
    echo "❌ FAIL — tests not all green after Claude's changes"
    echo "   Last test line: $PASS_LINE"
    RESULT=1
fi

teardown
exit $RESULT
