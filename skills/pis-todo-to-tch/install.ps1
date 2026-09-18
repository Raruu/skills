# install.ps1 — install the pis-todo-to-tch skill (and the OpenCode slash command).
#
# Works two ways:
#   irm https://raw.githubusercontent.com/Raruu/skills/main/skills/pis-todo-to-tch/install.ps1 | iex
#   powershell -ExecutionPolicy Bypass -File install.ps1    # from inside this skill folder
#
# Installs:
#   <skill folder>\            -> ~\.agents\skills\pis-todo-to-tch\
#   <skill folder>\opencode\   -> ~\.config\opencode\command\pis-todo-to-tch.md
#
# Exit codes: 0 ok | 1 failure

$ErrorActionPreference = 'Stop'

function Write-Say  { param([string]$Message) Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Warning $Message }
function Fail       { param([string]$Message) Write-Error $Message; exit 1 }

$Repo = 'Raruu/skills'

# --- destinations ------------------------------------------------------------
$HomeDir         = $env:USERPROFILE
$SkillDest       = Join-Path $HomeDir '.agents\skills\pis-todo-to-tch'
$CommandDestDir  = Join-Path $HomeDir '.config\opencode\command'
$CommandDest     = Join-Path $CommandDestDir 'pis-todo-to-tch.md'

# --- locate the source files -------------------------------------------------
# Local mode: this script sits inside the skill folder, next to SKILL.md.
# Remote mode: piped through `irm | iex`, so download the repo first.
$Src = $PSScriptRoot
if (-not $Src -or -not (Test-Path (Join-Path $Src 'SKILL.md'))) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pis-todo-to-tch-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $zip = Join-Path $tmp 'repo.zip'
    Write-Say "Downloading $Repo..."
    try {
        Invoke-WebRequest -Uri "https://codeload.github.com/$Repo/zip/refs/heads/main" -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
    }
    catch {
        Fail "download or extraction failed: $($_.Exception.Message)"
    }
    $root = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
    $Src = Join-Path $root.FullName 'skills\pis-todo-to-tch'
    if (-not (Test-Path (Join-Path $Src 'SKILL.md'))) { Fail 'unexpected archive layout' }
}
else {
    Write-Say "Using local checkout: $Src"
}

# --- guard: refuse to install onto itself ------------------------------------
# The skills CLI copies this whole folder, installer included. Running it from
# the installed location would delete the folder it is reading from.
$SrcReal  = (Resolve-Path $Src -ErrorAction SilentlyContinue).Path
$DestReal = (Resolve-Path $SkillDest -ErrorAction SilentlyContinue).Path
if ($SrcReal -and $DestReal -and ($SrcReal.TrimEnd('\') -ieq $DestReal.TrimEnd('\'))) {
    Fail "this installer is already running from $SkillDest; nothing to do"
}

# --- install the skill -------------------------------------------------------
try {
    New-Item -ItemType Directory -Path (Split-Path $SkillDest -Parent) -Force | Out-Null
    if (Test-Path $SkillDest) { Remove-Item -Path $SkillDest -Recurse -Force }
    New-Item -ItemType Directory -Path $SkillDest -Force | Out-Null
    Copy-Item -Path (Join-Path $Src '*') -Destination $SkillDest -Recurse -Force
    Write-Say "Installed skill -> $SkillDest"
}
catch {
    Fail "could not install the skill: $($_.Exception.Message)"
}

# --- install the slash command ----------------------------------------------
$commandSource = Join-Path $Src 'opencode\command\pis-todo-to-tch.md'
if (Test-Path $commandSource) {
    try {
        New-Item -ItemType Directory -Path $CommandDestDir -Force | Out-Null
        if (Test-Path $CommandDest) { Remove-Item -Path $CommandDest -Force }
        Copy-Item -Path $commandSource -Destination $CommandDest -Force
        Write-Say "Installed command -> $CommandDest"
    }
    catch {
        Fail "could not install the slash command: $($_.Exception.Message)"
    }
}

# --- duplicate detection -----------------------------------------------------
$dup = Join-Path $HomeDir '.config\opencode\skills\pis-todo-to-tch'
if (Test-Path $dup) {
    Write-Warn "Found a second copy at $dup"
    Write-Warn "OpenCode reads both locations, which logs a 'duplicate skill name' warning."
    Write-Warn "Remove it with: Remove-Item -Recurse -Force '$dup'"
}

# --- config ------------------------------------------------------------------
Write-Say "Personal config is created automatically as .pis-todo-to-tch.json"
Write-Say "in your working folder the first time you run the skill."

# --- requirements check ------------------------------------------------------
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if ($py) {
    Write-Say "Python detected: $($py.Source)"
    & $py.Source -c "import importlib.util; [print(f'WARN: {p} not found — pip install {p}') for m,p in (('docx','python-docx'),('fpdf','fpdf2')) if importlib.util.find_spec(m) is None]" 2>$null
}
else {
    Write-Warn "python not found — the builder needs Python 3 with python-docx and fpdf2."
}

Write-Say ""
Write-Say "Done. Next steps:"
Write-Say "  1. Make sure the profile-plus MCP server is configured in OpenCode."
Write-Say "  2. Run:  /pis-todo-to-tch <periode>, <word|pdf>"
Write-Say "  3. Example:  /pis-todo-to-tch September"
