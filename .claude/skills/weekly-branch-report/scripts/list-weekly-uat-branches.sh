#!/usr/bin/env bash
# List feature branches where author has commits in date range,
# split into merged-to-uat and in-progress (unmerged) tickets.
# Output: commits with ticket attribution + deduplicated ticket lists.
set -euo pipefail

AUTHOR=""
SINCE=""
UNTIL=""
TARGET="origin/uat"
TICKET_PATTERN='(SPRD|SOPS)-[0-9]+'
BRANCH_PREFIX="feature/"

usage() {
  cat <<EOF
Usage: $0 --author NAME --since YYYY-MM-DD --until YYYY-MM-DD \\
  [--target BRANCH] [--ticket-pattern REGEX] [--branch-prefix PREFIX]

Required:
  --author          Git author (substring match, same as git log --author)
  --since           Range start (inclusive), YYYY-MM-DD
  --until           Range end (exclusive), YYYY-MM-DD — commits before until 00:00:00

Optional:
  --target          Merge target ref (default: origin/uat)
  --ticket-pattern  Ticket regex (default: (SPRD|SOPS)-[0-9]+)
  --branch-prefix   Feature branch prefix in merge messages (default: feature/)
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --author) AUTHOR="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --until) UNTIL="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --ticket-pattern) TICKET_PATTERN="$2"; shift 2 ;;
    --branch-prefix) BRANCH_PREFIX="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -z "$AUTHOR" || -z "$SINCE" || -z "$UNTIL" ]] && usage

if ! fetch_err=$(git fetch --all 2>&1); then
  echo "WARNING: git fetch --all failed; results may be stale (using local $TARGET)." >&2
  echo "$fetch_err" >&2
fi

TMP_COMMITS=$(mktemp)
TMP_RESULTS=$(mktemp)
TMP_TICKETS=$(mktemp)
TMP_IN_PROGRESS_RESULTS=$(mktemp)
TMP_IN_PROGRESS_TICKETS=$(mktemp)
TMP_MERGES=$(mktemp)
trap 'rm -f "$TMP_COMMITS" "$TMP_RESULTS" "$TMP_TICKETS" "$TMP_IN_PROGRESS_RESULTS" "$TMP_IN_PROGRESS_TICKETS" "$TMP_MERGES"' EXIT

# Cache uat merge commits (full history for attribution; date filter applied separately)
build_merge_cache() {
  git log "$TARGET" --merges --format="%H %s" 2>/dev/null \
    | grep -E "${BRANCH_PREFIX}(${TICKET_PATTERN})" > "$TMP_MERGES" || true
}

ticket_from_text() {
  echo "$1" | grep -oE "$TICKET_PATTERN" | head -1 || true
}

ticket_from_merge_subject() {
  echo "$1" | grep -oE "${BRANCH_PREFIX}(${TICKET_PATTERN})" | head -1 \
    | sed "s|^${BRANCH_PREFIX}||" || true
}

read_merges_for_ticket() {
  local hash="$1"
  local merge_source="$2"
  local merge_hash merge_subject merge_ticket parent2

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    merge_hash="${line%% *}"
    merge_subject="${line#* }"
    merge_ticket=$(ticket_from_merge_subject "$merge_subject")
    [[ -z "$merge_ticket" ]] && continue

    parent2=$(git rev-parse "${merge_hash}^2" 2>/dev/null || true)
    [[ -z "$parent2" ]] && continue

    if git merge-base --is-ancestor "$hash" "$parent2" 2>/dev/null; then
      echo "$merge_ticket"
      return 0
    fi
  done < "$merge_source"

  return 1
}

# Resolve ticket from uat merge commits where hash is ancestor of merged branch tip (^2)
ticket_from_uat_merge() {
  local hash="$1"
  local range_filter="${2:-}"

  if [[ "$range_filter" == "range" ]]; then
    local ranged_merges
    ranged_merges=$(mktemp)
    git log "$TARGET" --merges \
      --since="${SINCE} 00:00:00" \
      --until="${UNTIL} 00:00:00" \
      --format="%H %s" 2>/dev/null \
      | grep -E "${BRANCH_PREFIX}(${TICKET_PATTERN})" > "$ranged_merges" || true
    read_merges_for_ticket "$hash" "$ranged_merges" || { rm -f "$ranged_merges"; return 1; }
    rm -f "$ranged_merges"
    return 0
  fi

  read_merges_for_ticket "$hash" "$TMP_MERGES"
}

resolve_ticket() {
  local hash="$1"
  local subject="$2"
  local source_ref="$3"
  local ticket=""

  ticket=$(ticket_from_text "$subject")
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  ticket=$(ticket_from_text "$source_ref")
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  ticket=$(git name-rev --name-only "$hash" 2>/dev/null | ticket_from_text || true)
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  # Prefer merges in date range, then fall back to any merge (cross-week attribution)
  ticket=$(ticket_from_uat_merge "$hash" "range" || true)
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  ticket=$(ticket_from_uat_merge "$hash" "" || true)
  [[ -n "$ticket" ]] && { echo "$ticket"; return 0; }

  return 1
}

# SKILL §1.4 condition 2: commit belongs to a branch merged into target via merge commit
is_merged_via_branch_merge() {
  local hash="$1"
  local ticket="$2"
  local merge_hash merge_subject merge_ticket parent2

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    merge_hash="${line%% *}"
    merge_subject="${line#* }"
    merge_ticket=$(ticket_from_merge_subject "$merge_subject")
    [[ "$merge_ticket" != "$ticket" ]] && continue

    parent2=$(git rev-parse "${merge_hash}^2" 2>/dev/null || true)
    [[ -z "$parent2" ]] && continue

    if git merge-base --is-ancestor "$hash" "$parent2" 2>/dev/null; then
      return 0
    fi
  done < "$TMP_MERGES"

  return 1
}

is_merged_to_uat() {
  local hash="$1"
  local ticket="$2"

  # Condition 1: commit hash is ancestor of target
  if git merge-base --is-ancestor "$hash" "$TARGET" 2>/dev/null; then
    return 0
  fi

  # Condition 2: commit belongs to a feature branch that was merge-committed into target
  [[ -n "$ticket" ]] && is_merged_via_branch_merge "$hash" "$ticket"
}

is_stash_commit() {
  echo "$1" | grep -qE '^(index|WIP) on '
}

build_merge_cache

git log --all --source --remotes \
  --author="$AUTHOR" \
  --since="${SINCE} 00:00:00" \
  --until="${UNTIL} 00:00:00" \
  --no-merges \
  --format='%H%x09%s%x09%S' > "$TMP_COMMITS"

while IFS=$'\t' read -r hash subject source_ref; do
  [[ -z "$hash" ]] && continue
  is_stash_commit "$subject" && continue

  ticket=$(resolve_ticket "$hash" "$subject" "$source_ref" || true)
  [[ -z "$ticket" ]] && continue

  short=$(git rev-parse --short "$hash")
  date=$(git log -1 --format="%cd" --date=format:"%Y-%m-%d %H:%M" "$hash")

  if is_merged_to_uat "$hash" "$ticket"; then
    printf '%s|%s|%s|%s\n' "$ticket" "$short" "$date" "$subject" >> "$TMP_RESULTS"
    echo "$ticket" >> "$TMP_TICKETS"
  else
    printf '%s|%s|%s|%s\n' "$ticket" "$short" "$date" "$subject" >> "$TMP_IN_PROGRESS_RESULTS"
    echo "$ticket" >> "$TMP_IN_PROGRESS_TICKETS"
  fi
done < "$TMP_COMMITS"

echo "Commits:"
if [[ -s "$TMP_RESULTS" ]]; then
  sort -t'|' -k1,1 -k3,3 "$TMP_RESULTS"
else
  echo "(none)"
fi

echo "---"
echo "TICKETS:"
if [[ -s "$TMP_TICKETS" ]]; then
  sort -u "$TMP_TICKETS"
else
  echo "(none — no branches merged to uat in this range)"
fi

echo "---"
echo "In progress commits:"
if [[ -s "$TMP_IN_PROGRESS_RESULTS" ]]; then
  sort -t'|' -k1,1 -k3,3 "$TMP_IN_PROGRESS_RESULTS"
else
  echo "(none)"
fi

echo "---"
echo "IN_PROGRESS:"
if [[ -s "$TMP_IN_PROGRESS_TICKETS" ]]; then
  sort -u "$TMP_IN_PROGRESS_TICKETS"
else
  echo "(none — no in-progress branches in this range)"
fi
