#!/usr/bin/env bash
#
# install.sh — install the pis-todo skill (and the OpenCode slash command).
#
# Works two ways:
#   curl -fsSL https://raw.githubusercontent.com/Raruu/skills/main/skills/pis-todo/install.sh | bash
#   bash install.sh                     # from inside this skill folder
#
# Installs:
#   <skill folder>/            -> ~/.agents/skills/pis-todo/
#   <skill folder>/opencode/   -> ~/.config/opencode/command/pis-todo.md
#
# Exit codes: 0 ok | 1 failure
#
set -euo pipefail

REPO_TARBALL="https://codeload.github.com/Raruu/skills/tar.gz/refs/heads/main"

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- destinations ------------------------------------------------------------
SKILL_DEST="$HOME/.agents/skills/pis-todo"
COMMAND_DEST_DIR="$HOME/.config/opencode/command"
COMMAND_DEST="$COMMAND_DEST_DIR/pis-todo.md"

# Backups live outside ~/.agents/skills so the agent's skill scanner does not
# pick up the old copy (it would log a name-mismatch error on every start).
BACKUP_DIR="$HOME/.agents/skill-backups"

# --- locate the source files -------------------------------------------------
# Local mode: this script sits inside the skill folder, next to SKILL.md.
# Remote mode: piped through `curl | bash`, so download the repo first.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

TMP_DIR=""
cleanup() { [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/SKILL.md" ]; then
  SRC="$SCRIPT_DIR"
  say "Using local checkout: $SRC"
else
  command -v curl >/dev/null 2>&1 || die "curl is required to download the repo"
  command -v tar  >/dev/null 2>&1 || die "tar is required to extract the repo"
  TMP_DIR="$(mktemp -d)"
  say "Downloading Raruu/skills..."
  curl -fsSL "$REPO_TARBALL" | tar -xz -C "$TMP_DIR" || die "download or extraction failed"
  ROOT="$(find "$TMP_DIR" -maxdepth 1 -mindepth 1 -type d | head -1)"
  SRC="$ROOT/skills/pis-todo"
  [ -f "$SRC/SKILL.md" ] || die "unexpected archive layout"
fi

# --- guard: refuse to install onto itself ------------------------------------
# The skills CLI copies this whole folder, installer included. Running it from
# the installed location would back the folder up and then copy nothing.
SRC_REAL="$(cd "$SRC" && pwd -P)"
DEST_REAL="$(cd "$SKILL_DEST" 2>/dev/null && pwd -P || printf '')"
if [ -n "$DEST_REAL" ] && [ "$SRC_REAL" = "$DEST_REAL" ]; then
  die "this installer is already running from $SKILL_DEST; nothing to do"
fi

backup_if_exists() { # backup_if_exists <path> <label>
  local target="$1" label="$2"
  if [ -e "$target" ]; then
    local stamp
    stamp="$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/${label}.bak-${stamp}"
    say "Backed up existing ${label} -> $BACKUP_DIR/${label}.bak-${stamp}"
  fi
}

# --- install the skill -------------------------------------------------------
mkdir -p "$(dirname "$SKILL_DEST")"
backup_if_exists "$SKILL_DEST" "pis-todo"
mkdir -p "$SKILL_DEST"
cp -R "$SRC/." "$SKILL_DEST/"
chmod +x "$SKILL_DEST/scripts/collect-commits.sh" 2>/dev/null || true
chmod +x "$SKILL_DEST/scripts/collect-commits.mjs" 2>/dev/null || true
say "Installed skill -> $SKILL_DEST"

# --- install the slash command ----------------------------------------------
if [ -f "$SRC/opencode/command/pis-todo.md" ]; then
  mkdir -p "$COMMAND_DEST_DIR"
  backup_if_exists "$COMMAND_DEST" "pis-todo.md"
  cp "$SRC/opencode/command/pis-todo.md" "$COMMAND_DEST"
  say "Installed command -> $COMMAND_DEST"
fi

# --- duplicate detection -----------------------------------------------------
DUP="$HOME/.config/opencode/skills/pis-todo"
if [ -d "$DUP" ]; then
  warn "Found a second copy at $DUP"
  warn "OpenCode reads both locations, which logs a 'duplicate skill name' warning."
  warn "Remove it with: rm -rf \"$DUP\""
fi

# --- requirements check ------------------------------------------------------
command -v git >/dev/null 2>&1 || warn "git not found on PATH — the collector needs it."
if command -v node >/dev/null 2>&1; then
  say "Node $(node --version) detected — collect-commits.mjs will be used."
else
  warn "Node not found — the Bash fallback (collect-commits.sh) will be used instead."
fi

say ""
say "Done. Next steps:"
say "  1. Make sure the profile-plus MCP server is configured in OpenCode."
say "  2. Run:  /pis-todo <Module>, <git range>, <date>, <mark-complete>"
say "  3. Example:  /pis-todo My Project, HEAD~5 -> HEAD, done"
