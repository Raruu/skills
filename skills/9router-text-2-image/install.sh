#!/usr/bin/env bash
#
# install.sh — install the 9router-text-2-image skill (and the OpenCode slash command).
#
# Works two ways:
#   curl -fsSL https://raw.githubusercontent.com/Raruu/skills/main/skills/9router-text-2-image/install.sh | bash
#   bash install.sh                     # from inside this skill folder
#
# Installs:
#   <skill folder>/            -> ~/.agents/skills/9router-text-2-image/
#   <skill folder>/opencode/   -> ~/.config/opencode/command/9router-text-2-image.md
#
# Exit codes: 0 ok | 1 failure
#
set -euo pipefail

REPO_TARBALL="https://codeload.github.com/Raruu/skills/tar.gz/refs/heads/main"

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- destinations ------------------------------------------------------------
SKILL_DEST="$HOME/.agents/skills/9router-text-2-image"
COMMAND_DEST_DIR="$HOME/.config/opencode/command"
COMMAND_DEST="$COMMAND_DEST_DIR/9router-text-2-image.md"

# --- locate the source files -------------------------------------------------
# Local mode: this script sits inside the skill folder, next to SKILL.md.
# Remote mode: piped through `curl | bash`, so download the repo first.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

TMP_DIR=""
cleanup() { if [ -n "$TMP_DIR" ]; then rm -rf "$TMP_DIR"; fi; }
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
  SRC="$ROOT/skills/9router-text-2-image"
  [ -f "$SRC/SKILL.md" ] || die "unexpected archive layout"
fi

# --- guard: refuse to install onto itself ------------------------------------
# The skills CLI copies this whole folder, installer included. Running it from
# the installed location would delete the folder it is reading from.
SRC_REAL="$(cd "$SRC" && pwd -P)"
DEST_REAL="$(cd "$SKILL_DEST" 2>/dev/null && pwd -P || printf '')"
if [ -n "$DEST_REAL" ] && [ "$SRC_REAL" = "$DEST_REAL" ]; then
  die "this installer is already running from $SKILL_DEST; nothing to do"
fi

# --- install the skill -------------------------------------------------------
mkdir -p "$(dirname "$SKILL_DEST")"
rm -rf "$SKILL_DEST"
mkdir -p "$SKILL_DEST"
cp -R "$SRC/." "$SKILL_DEST/"
say "Installed skill -> $SKILL_DEST"

# --- install the slash command ----------------------------------------------
if [ -f "$SRC/opencode/command/9router-text-2-image.md" ]; then
  mkdir -p "$COMMAND_DEST_DIR"
  rm -f "$COMMAND_DEST"
  cp "$SRC/opencode/command/9router-text-2-image.md" "$COMMAND_DEST"
  say "Installed command -> $COMMAND_DEST"
fi

# --- duplicate detection -----------------------------------------------------
DUP="$HOME/.config/opencode/skills/9router-text-2-image"
if [ -d "$DUP" ]; then
  warn "Found a second copy at $DUP"
  warn "OpenCode reads both locations, which logs a 'duplicate skill name' warning."
  warn "Remove it with: rm -rf \"$DUP\""
fi

# --- requirements check ------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  say "curl detected — used to call the 9Router gateway and download results."
else
  warn "curl not found — the skill needs it to call 9Router and save images."
fi

if [ -n "${NINEROUTER_URL:-}" ]; then
  say "NINEROUTER_URL=$NINEROUTER_URL"
else
  warn "NINEROUTER_URL is not set — export it before running the skill."
fi

say ""
say "Done. Next steps:"
say "  1. Export NINEROUTER_URL (and NINEROUTER_KEY if auth is enabled)."
say "  2. Save your models:  /9router-text-2-image SET >MODEL:<id>; MODEL1:<id><"
say "  3. Generate:  /9router-text-2-image a watercolor mountain range at sunrise"
