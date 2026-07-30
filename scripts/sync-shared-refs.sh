#!/usr/bin/env bash
# Sync stack-detect.source.md into each consuming skill's local reference file.
# Re-run after editing dev/shared/stack-detect.source.md; then verify with:
#   ./scripts/sync-shared-refs.sh && git diff --exit-code
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/dev/shared/stack-detect.source.md"

if [[ ! -f "$SRC" ]]; then
  echo "Missing source: $SRC" >&2
  exit 1
fi

HEADER=$'# GENERATED — do not edit the body by hand.\n# Source: dev/shared/stack-detect.source.md\n# Regenerate: ./scripts/sync-shared-refs.sh\n\n'

# skill_dir:relative_output_path
TARGETS=(
  "feature:reference.md"
  "adjust:reference.md"
  "find-component-render-path:reference.md"
  "quick-debug:reference.md"
  "refactor:reference-stack.md"
  "fix:reference-stack.md"
)

BODY="$(cat "$SRC")"

for entry in "${TARGETS[@]}"; do
  skill="${entry%%:*}"
  rel="${entry#*:}"
  dest="$ROOT/.claude/skills/$skill/$rel"
  mkdir -p "$(dirname "$dest")"
  printf '%s%s\n' "$HEADER" "$BODY" > "$dest"
  echo "wrote $dest"
done

echo "OK: synced ${#TARGETS[@]} files from $SRC"
