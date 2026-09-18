#!/usr/bin/env bash
#
# install.sh — install the pis-todo-to-tch skill (and the OpenCode slash command).
#
# Works two ways:
#   curl -fsSL https://raw.githubusercontent.com/Raruu/skills/main/skills/pis-todo-to-tch/install.sh | bash
#   bash install.sh                     # from inside this skill folder
#
# Installs:
#   <skill folder>/            -> ~/.agents/skills/pis-todo-to-tch/
#   <skill folder>/opencode/   -> ~/.config/opencode/command/pis-todo-to-tch.md
#
# Exit codes: 0 ok | 1 failure
#
set -euo pipefail

REPO_TARBALL="https://codeload.github.com/Raruu/skills/tar.gz/refs/heads/main"

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- destinations ------------------------------------------------------------
SKILL_DEST="$HOME/.agents/skills/pis-todo-to-tch"
COMMAND_DEST_DIR="$HOME/.config/opencode/command"
COMMAND_DEST="$COMMAND_DEST_DIR/pis-todo-to-tch.md"

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
  SRC="$ROOT/skills/pis-todo-to-tch"
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
chmod +x "$SKILL_DEST/scripts/build-logbook.py" 2>/dev/null || true
say "Installed skill -> $SKILL_DEST"

# --- install the slash command ----------------------------------------------
if [ -f "$SRC/opencode/command/pis-todo-to-tch.md" ]; then
  mkdir -p "$COMMAND_DEST_DIR"
  rm -f "$COMMAND_DEST"
  cp "$SRC/opencode/command/pis-todo-to-tch.md" "$COMMAND_DEST"
  say "Installed command -> $COMMAND_DEST"
fi

# --- duplicate detection -----------------------------------------------------
DUP="$HOME/.config/opencode/skills/pis-todo-to-tch"
if [ -d "$DUP" ]; then
  warn "Found a second copy at $DUP"
  warn "OpenCode reads both locations, which logs a 'duplicate skill name' warning."
  warn "Remove it with: rm -rf \"$DUP\""
fi

# --- config ------------------------------------------------------------------
say "Personal config is created automatically as .pis-todo-to-tch.json"
say "in your working folder the first time you run the skill."

# --- requirements check ------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  say "Python $(python3 --version 2>&1 | cut -d' ' -f2) detected."
  python3 - <<'PY' || true
import importlib.util
for mod, pkg in (("docx", "python-docx"), ("fpdf", "fpdf2")):
    if importlib.util.find_spec(mod) is None:
        print(f"WARN: {pkg} not found — pip install {pkg}")
PY
else
  warn "python3 not found — the builder needs Python 3 with python-docx and fpdf2."
fi

say ""
say "Done. Next steps:"
say "  1. Make sure the profile-plus MCP server is configured in OpenCode."
say "  2. Run:  /pis-todo-to-tch <periode>, <word|pdf>"
say "  3. Example:  /pis-todo-to-tch September"
