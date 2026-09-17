#!/usr/bin/env bash
#
# collect-commits.sh — deterministic git history collector for the `pis-todo` skill.
#
# Emits a stable, line-oriented report of commits in a range so an agent can
# translate them into human-readable todos without guessing at stats or paths.
#
# Usage:
#   collect-commits.sh --repo <path> --range "A -> B"          # start & end inclusive
#   collect-commits.sh --repo <path> --from <ref> [--to <ref>]
#   collect-commits.sh --repo <path> --since <yyyy-MM-dd> [--until <yyyy-MM-dd>]
#
# Options:
#   --repo <path>        Repository path (default: current directory)
#   --range "<A -> B>"   Commit range; accepts "A -> B", "A..B", "A...B", or "A"
#   --from <ref>         Start ref (inclusive)
#   --to <ref>           End ref (default: HEAD)
#   --since <date>       Only commits after this date (when no range/from given)
#   --until <date>       Only commits up to this date
#   --author <email>     Filter by author email (default: git config user.email)
#   --all-authors        Do not filter by author
#   --max-files <n>      Max file paths listed per commit (default: 12)
#   --mark-from <date>   Mark commits with date >= <date> as possible duplicates
#   -h, --help           Show this help
#
# Exit codes: 0 ok | 2 bad usage | 3 author unknown | 4 bad repo/ref
#
set -euo pipefail

usage() {
  sed -n '3,26p' "$0" | sed -e 's/^# \{0,1\}//'
}

die() { # die <exit-code> <message...>
  local code="$1"; shift
  printf 'ERROR: %s\n' "$*" >&2
  exit "$code"
}

REPO="."
RANGE=""
FROM=""
TO=""
SINCE=""
UNTIL=""
AUTHOR=""
ALL_AUTHORS=0
MAX_FILES=12
MARK_FROM=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)        [ $# -ge 2 ] || die 2 "--repo requires a value";      REPO="$2"; shift 2 ;;
    --range)       [ $# -ge 2 ] || die 2 "--range requires a value";     RANGE="$2"; shift 2 ;;
    --from)        [ $# -ge 2 ] || die 2 "--from requires a value";      FROM="$2"; shift 2 ;;
    --to)          [ $# -ge 2 ] || die 2 "--to requires a value";        TO="$2"; shift 2 ;;
    --since)       [ $# -ge 2 ] || die 2 "--since requires a value";     SINCE="$2"; shift 2 ;;
    --until)       [ $# -ge 2 ] || die 2 "--until requires a value";     UNTIL="$2"; shift 2 ;;
    --author)      [ $# -ge 2 ] || die 2 "--author requires a value";    AUTHOR="$2"; shift 2 ;;
    --max-files)   [ $# -ge 2 ] || die 2 "--max-files requires a value"; MAX_FILES="$2"; shift 2 ;;
    --mark-from)   [ $# -ge 2 ] || die 2 "--mark-from requires a value"; MARK_FROM="$2"; shift 2 ;;
    --all-authors) ALL_AUTHORS=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             die 2 "unknown option: $1 (see --help)" ;;
  esac
done

git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die 4 "not a git repository: $REPO"
git -C "$REPO" rev-parse --verify --quiet HEAD >/dev/null 2>&1 || die 4 "repository has no commits yet: $REPO"

# --- author filter -----------------------------------------------------------
if [ "$ALL_AUTHORS" -eq 0 ]; then
  if [ -z "$AUTHOR" ]; then
    AUTHOR="$(git -C "$REPO" config user.email 2>/dev/null || true)"
  fi
  [ -n "$AUTHOR" ] || die 3 "author email unknown; pass --author <email> or --all-authors"
fi

# --- normalize --range -------------------------------------------------------
if [ -n "$RANGE" ]; then
  r="$(printf '%s' "$RANGE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  if [[ "$r" == *"..."* ]]; then
    FROM="${r%%...*}"; TO="${r#*...}"
  elif [[ "$r" == *".."* ]]; then
    FROM="${r%%..*}"; TO="${r#*..}"
  elif [[ "$r" == *"->"* ]]; then
    FROM="${r%%->*}"; TO="${r#*->}"
  else
    FROM="$r"
  fi
  FROM="$(printf '%s' "$FROM" | sed -e 's/[[:space:]]*$//')"
  TO="$(printf '%s' "$TO" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
fi

# --- resolve commit list -----------------------------------------------------
HASHES=()
RANGE_DESC=""
MODE=""

if [ -n "$FROM" ]; then
  MODE="range"
  from_full="$(git -C "$REPO" rev-parse --verify --quiet "${FROM}^{commit}" || true)"
  [ -n "$from_full" ] || die 4 "start ref not found: $FROM"
  to_ref="${TO:-HEAD}"
  to_full="$(git -C "$REPO" rev-parse --verify --quiet "${to_ref}^{commit}" || true)"
  [ -n "$to_full" ] || die 4 "end ref not found: $to_ref"

  if git -C "$REPO" merge-base --is-ancestor "$from_full" "$to_full"; then
    parent="$(git -C "$REPO" rev-parse --verify --quiet "${from_full}^" || true)"
    if [ -n "$parent" ]; then
      RANGE_DESC="${FROM}^..${to_ref} (start inclusive)"
      mapfile -t HASHES < <(git -C "$REPO" rev-list "${parent}..${to_full}")
    else
      # root commit: A^ does not exist, walk from the end and stop at A (inclusive)
      RANGE_DESC="${FROM}..${to_ref} + root commit ${FROM} (start inclusive)"
      mapfile -t HASHES < <(git -C "$REPO" rev-list "$to_full" | awk -v stop="$from_full" '{print} $0==stop {exit}')
    fi
  else
    printf 'WARN: start ref is not an ancestor of end ref; using exclusive range %s..%s\n' "$FROM" "$to_ref" >&2
    RANGE_DESC="${FROM}..${to_ref} (exclusive, non-ancestor)"
    mapfile -t HASHES < <(git -C "$REPO" rev-list "${from_full}..${to_full}")
  fi

  if [ "${#HASHES[@]}" -eq 0 ]; then
    printf 'NO_COMMITS: no commits found in range (%s)\n' "$RANGE_DESC"
    exit 0
  fi
else
  MODE="date"
  if [ -n "$UNTIL" ] && [[ "$UNTIL" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    UNTIL="$UNTIL 23:59:59"   # include the whole end day
  fi
  RANGE_DESC="since=${SINCE:-beginning} until=${UNTIL:-HEAD}"
fi

# --- emit raw commit stream --------------------------------------------------
GIT_ARGS=(log --no-merges --numstat --format=$'@@@%h\t%ad\t%an\t%s' --date=format:%Y-%m-%d)
if [ "$ALL_AUTHORS" -eq 0 ]; then
  GIT_ARGS+=(--author="$AUTHOR")
fi

emit_stream() {
  if [ "$MODE" = "range" ]; then
    # rev-list is newest-first; reverse so the report reads chronologically
    local i
    for ((i = ${#HASHES[@]} - 1; i >= 0; i--)); do
      printf '%s\n' "${HASHES[i]}"
    done | git -C "$REPO" "${GIT_ARGS[@]}" --no-walk=unsorted --stdin
  else
    local date_args=()
    if [ -n "$SINCE" ]; then date_args+=(--since="$SINCE"); fi
    if [ -n "$UNTIL" ]; then date_args+=(--until="$UNTIL"); fi
    git -C "$REPO" "${GIT_ARGS[@]}" --reverse "${date_args[@]}"
  fi
}

# --- render report -----------------------------------------------------------
emit_stream | awk -v max_files="$MAX_FILES" -v mark_from="$MARK_FROM" \
    -v range_desc="$RANGE_DESC" -v author_desc="${AUTHOR:-(all authors)}" '
  BEGIN { FS = "\t"; n_commits = 0; tot_files = 0; tot_ins = 0; tot_del = 0; have = 0 }
  function flush() {
    if (!have) return
    printf "=== COMMIT %s\n", hash
    printf "DATE: %s\n", date
    printf "SUBJECT: %s\n", subject
    printf "STAT: %d files, +%d -%d\n", nfiles, ins, del
    if (warn) printf "WARN: possible duplicate — date overlaps last recorded todo\n"
    printf "FILES:\n"
    printf "%s", files
    if (more > 0) printf "  ... (+%d more files)\n", more
    printf "END\n\n"
    n_commits++; tot_files += nfiles; tot_ins += ins; tot_del += del
  }
  /^@@@/ {
    flush()
    hash = substr($1, 4); date = $2
    subject = $4
    for (i = 5; i <= NF; i++) subject = subject FS $i
    nfiles = 0; ins = 0; del = 0; files = ""; more = 0
    warn = (mark_from != "" && date >= mark_from)
    have = 1
    next
  }
  NF >= 3 && $3 != "" {
    nfiles++
    if ($1 ~ /^[0-9]+$/) ins += $1
    if ($2 ~ /^[0-9]+$/) del += $2
    if (nfiles <= max_files) files = files "  " $3 "\n"
    else more++
  }
  END {
    flush()
    if (n_commits == 0) printf "NO_COMMITS: no commits matched the filters in this range\n"
    printf "TOTAL: %d commits | %d file-changes | +%d -%d\n", n_commits, tot_files, tot_ins, tot_del
    printf "RANGE: %s\n", range_desc
    printf "AUTHOR: %s\n", author_desc
  }'
