#!/usr/bin/env bash
# Sync dev/shared/*.source.md into each consuming skill's local reference file.
# Re-run after editing a source; then verify with:
#   ./scripts/sync-shared-refs.sh && git diff --exit-code
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# source_file|skill_dir:relative_output_path ...
MAPPINGS=(
  "stack-detect.source.md|feature:reference.md adjust:reference.md find-component-render-path:reference.md quick-debug:reference.md refactor:reference-stack.md fix:reference-stack.md"
  "test-value-gate.source.md|feature:reference-test-gate.md unit-test:reference-test-gate.md vue-integration-test:reference-test-gate.md react-integration-test:reference-test-gate.md e2e-test:reference-test-gate.md fix:reference-test-gate.md adjust:reference-test-gate.md refactor:reference-test-gate.md test-audit:reference-test-gate.md"
)

count=0
for mapping in "${MAPPINGS[@]}"; do
  src_name="${mapping%%|*}"
  src="$ROOT/dev/shared/$src_name"
  if [[ ! -f "$src" ]]; then
    echo "Missing source: $src" >&2
    exit 1
  fi
  header="# GENERATED — do not edit the body by hand."$'\n'"# Source: dev/shared/$src_name"$'\n'"# Regenerate: ./scripts/sync-shared-refs.sh"$'\n\n'
  body="$(cat "$src")"
  for entry in ${mapping#*|}; do
    skill="${entry%%:*}"
    rel="${entry#*:}"
    dest="$ROOT/.claude/skills/$skill/$rel"
    mkdir -p "$(dirname "$dest")"
    printf '%s%s\n' "$header" "$body" > "$dest"
    echo "wrote $dest"
    count=$((count + 1))
  done
done

echo "OK: synced $count files"
