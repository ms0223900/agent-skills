#!/usr/bin/env bash
# List feature branches where author has commits in date range
# and at least one such commit is merged into origin/uat.
# Output: commits with correct ticket attribution + deduplicated ticket list.
set -euo pipefail

AUTHOR="penguin"
SINCE=""
UNTIL=""
TARGET="origin/uat"

usage() {
  echo "Usage: $0 --since YYYY-MM-DD --until YYYY-MM-DD [--author NAME] [--target BRANCH]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --author) AUTHOR="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --until) UNTIL="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$SINCE" || -z "$UNTIL" ]] && usage

git fetch --all --quiet 2>/dev/null || true

TMP_COMMITS=$(mktemp)
TMP_RESULTS=$(mktemp)
TMP_TICKETS=$(mktemp)
trap 'rm -f "$TMP_COMMITS" "$TMP_RESULTS" "$TMP_TICKETS"' EXIT

ticket_from_subject() {
  echo "$1" | grep -oE '(SPRD|SOPS)-[0-9]+' | head -1 || true
}

ticket_from_source() {
  echo "$1" | grep -oE '(SPRD|SOPS)-[0-9]+' | head -1 || true
}

ticket_from_uat_merge() {
  local hash="$1"
  local merge_hash merge_subject merge_ticket parent2

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    merge_hash="${line%% *}"
    merge_subject="${line#* }"
    merge_ticket=$(echo "$merge_subject" | grep -oE "feature/((SPRD|SOPS)-[0-9]+)" | head -1 | sed 's|feature/||' || true)
    [[ -z "$merge_ticket" ]] && continue

    parent2=$(git rev-parse "${merge_hash}^2" 2>/dev/null || true)
    [[ -z "$parent2" ]] && continue

    if git merge-base --is-ancestor "$hash" "$parent2" 2>/dev/null; then
      echo "$merge_ticket"
      return 0
    fi
  done < <(git log "$TARGET" --merges \
    --since="${SINCE} 00:00:00" \
    --until="${UNTIL} 00:00:00" \
    --format="%H %s" 2>/dev/null \
    | grep -E "feature/(SPRD|SOPS)-[0-9]+" || true)

  return 1
}

resolve_ticket() {
  local hash="$1"
  local subject="$2"
  local source_ref="$3"
  local ticket=""

  ticket=$(ticket_from_subject "$subject")
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  ticket=$(ticket_from_source "$source_ref")
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  ticket=$(git name-rev --name-only "$hash" 2>/dev/null | grep -oE '(SPRD|SOPS)-[0-9]+' | head -1 || true)
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  ticket=$(ticket_from_uat_merge "$hash" || true)
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  return 1
}

is_chore_commit() {
  echo "$1" | grep -qE '^chore(\(|:)'
}

is_stash_commit() {
  echo "$1" | grep -qE '^(index|WIP) on '
}

git log --all --source --remotes \
  --author="$AUTHOR" \
  --since="${SINCE} 00:00:00" \
  --until="${UNTIL} 00:00:00" \
  --no-merges \
  --format='%H%x09%s%x09%S' > "$TMP_COMMITS"

while IFS=$'\t' read -r hash subject source_ref; do
  [[ -z "$hash" ]] && continue
  is_stash_commit "$subject" && continue

  if ! git merge-base --is-ancestor "$hash" "$TARGET" 2>/dev/null; then
    continue
  fi

  ticket=$(resolve_ticket "$hash" "$subject" "$source_ref" || true)
  [[ -z "$ticket" ]] && continue

  short=$(git rev-parse --short "$hash")
  date=$(git log -1 --format="%ad" --date=format:"%Y-%m-%d %H:%M" "$hash")
  printf '%s|%s|%s|%s\n' "$ticket" "$short" "$date" "$subject" >> "$TMP_RESULTS"

  if ! is_chore_commit "$subject"; then
    echo "$ticket" >> "$TMP_TICKETS"
  fi
done < "$TMP_COMMITS"

sort -t'|' -k1,1 -k3,3 "$TMP_RESULTS" 2>/dev/null || true

echo "---"
echo "TICKETS:"
sort -u "$TMP_TICKETS" 2>/dev/null || true
