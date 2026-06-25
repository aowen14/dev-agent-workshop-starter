#!/usr/bin/env bash
# After Claude exits, capture the after-state, bundle the artifact, and
# print a quick summary. Sandbox stays alive for review SSH.
set -euo pipefail

cd "$(dirname "$0")/.."

ARTIFACT_DIR=$(cat /tmp/workshop-artifact-dir 2>/dev/null || echo "")
PROJECT=$(cat /tmp/workshop-project 2>/dev/null || echo "workshop-demo")

if [[ -z "$ARTIFACT_DIR" || ! -d "$ARTIFACT_DIR" ]]; then
    echo "ERROR: no active rollout. Run ./demo/40-good-path.sh first." >&2
    exit 1
fi

echo ">> Capturing after-state..."
docker compose -p "$PROJECT" exec -T workspace uv run pytest --tb=short -q \
    > "$ARTIFACT_DIR/tests-after.txt" 2>&1 || true
docker compose -p "$PROJECT" exec -T postgres \
    pg_dump -U app -s inventory > "$ARTIFACT_DIR/schema-after.sql" 2>/dev/null || true

docker compose -p "$PROJECT" exec -T workspace bash -c "git add -A && git diff --cached" \
    > "$ARTIFACT_DIR/diff.patch" 2>/dev/null || true

docker compose -p "$PROJECT" logs --no-color > "$ARTIFACT_DIR/container-logs.txt" 2>&1 || true

echo ">> Bundling..."
tar -czf "${ARTIFACT_DIR}.tar.gz" -C "$(dirname "$ARTIFACT_DIR")" "$(basename "$ARTIFACT_DIR")"

echo
echo "=== Captured rollout ==="
echo "Folder:  $ARTIFACT_DIR"
echo "Bundle:  ${ARTIFACT_DIR}.tar.gz ($(du -h "${ARTIFACT_DIR}.tar.gz" | cut -f1))"
echo
echo "--- diff.patch ($(wc -l < "$ARTIFACT_DIR/diff.patch") lines) ---"
head -20 "$ARTIFACT_DIR/diff.patch" || true
echo "..."
echo
echo "--- tests-after.txt (tail) ---"
tail -10 "$ARTIFACT_DIR/tests-after.txt" || true
echo
echo "Sandbox kept alive for review."
echo "  Inspect      : docker compose -p $PROJECT exec workspace bash"
echo "  Live psql    : docker compose -p $PROJECT exec postgres psql -U app inventory"
echo "  Tear down    : docker compose -p $PROJECT down -v"
