#
# install.ps1 - install the pis-todo skill (and the OpenCode slash command).
#
# Usage:
#   irm https://raw.githubusercontent.com/Raruu/skills/main/skills/pis-todo/install.ps1 | iex
#   powershell -ExecutionPolicy Bypass -File install.ps1    # from inside this skill folder
#
# Installs:
#   <skill folder>\            -> %USERPROFILE%\.agents\skills\pis-todo\
#   <skill folder>\opencode\   -> %USERPROFILE%\.config\opencode\command\pis-todo.md
#
# Exit codes: 0 ok | 1 failure
#
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Say  { param([string]$Message) Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Warning $Message }
function Fail       { param([string]$Message) Write-Error $Message; exit 1 }

$RepoZip = 'https://codeload.github.com/Raruu/skills/zip/refs/heads/main'

# --- destinations ------------------------------------------------------------
$HomeDir         = $env:USERPROFILE
$SkillDest       = Join-Path $HomeDir '.agents\skills\pis-todo'
$CommandDestDir  = Join-Path $HomeDir '.config\opencode\command'
$CommandDest     = Join-Path $CommandDestDir 'pis-todo.md'

# Backups live outside ~\.agents\skills so the agent's skill scanner does not
# pick up the old copy (it would log a name-mismatch error on every start).
$BackupDir       = Join-Path $HomeDir '.agents\skill-backups'

# --- locate the source files -------------------------------------------------
# Local mode: this script sits inside the skill folder, next to SKILL.md.
# Remote mode: piped through `irm | iex`, so download the repo first.
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = (Get-Location).Path }

$TmpDir = $null

if (Test-Path (Join-Path $ScriptDir 'SKILL.md')) {
    $Src = $ScriptDir
    Write-Say "Using local checkout: $Src"
}
else {
    $TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("pis-todo-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
    $zipPath = Join-Path $TmpDir 'skills.zip'
    Write-Say 'Downloading Raruu/skills...'
    try {
        Invoke-WebRequest -Uri $RepoZip -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $TmpDir -Force
    }
    catch {
        Fail "download or extraction failed: $($_.Exception.Message)"
    }
    $extracted = Get-ChildItem -Path $TmpDir -Directory | Select-Object -First 1
    if ($null -eq $extracted) { Fail 'unexpected archive layout' }
    $Src = Join-Path $extracted.FullName 'skills\pis-todo'
    if (-not (Test-Path (Join-Path $Src 'SKILL.md'))) { Fail 'unexpected archive layout' }
}

# --- guard: refuse to install onto itself ------------------------------------
# The skills CLI copies this whole folder, installer included. Running it from
# the installed location would back the folder up and then copy nothing.
$SrcReal  = (Resolve-Path $Src -ErrorAction SilentlyContinue).Path
$DestReal = (Resolve-Path $SkillDest -ErrorAction SilentlyContinue).Path
if ($SrcReal -and $DestReal -and ($SrcReal.TrimEnd('\') -ieq $DestReal.TrimEnd('\'))) {
    Fail "this installer is already running from $SkillDest; nothing to do"
}

function Backup-IfExists {
    param([string]$Target, [string]$Label)
    if (Test-Path $Target) {
        $stamp = Get-Date -Format 'yyyyMMddHHmmss'
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }
        $backup = Join-Path $BackupDir "$Label.bak-$stamp"
        Move-Item -Path $Target -Destination $backup -Force
        Write-Say "Backed up existing $Label -> $backup"
    }
}

# --- install the skill -------------------------------------------------------
try {
    New-Item -ItemType Directory -Path (Split-Path $SkillDest -Parent) -Force | Out-Null
    Backup-IfExists -Target $SkillDest -Label 'pis-todo'
    New-Item -ItemType Directory -Path $SkillDest -Force | Out-Null
    Copy-Item -Path (Join-Path $Src '*') -Destination $SkillDest -Recurse -Force
    Write-Say "Installed skill -> $SkillDest"
}
catch {
    Fail "could not install the skill: $($_.Exception.Message)"
}

# --- install the slash command ----------------------------------------------
$commandSource = Join-Path $Src 'opencode\command\pis-todo.md'
if (Test-Path $commandSource) {
    try {
        New-Item -ItemType Directory -Path $CommandDestDir -Force | Out-Null
        Backup-IfExists -Target $CommandDest -Label 'pis-todo.md'
        Copy-Item -Path $commandSource -Destination $CommandDest -Force
        Write-Say "Installed command -> $CommandDest"
    }
    catch {
        Fail "could not install the slash command: $($_.Exception.Message)"
    }
}

# --- duplicate detection -----------------------------------------------------
$dup = Join-Path $HomeDir '.config\opencode\skills\pis-todo'
if (Test-Path $dup) {
    Write-Warn "Found a second copy at $dup"
    Write-Warn "OpenCode reads both locations, which logs a 'duplicate skill name' warning."
    Write-Warn "Remove it with: Remove-Item -Recurse -Force `"$dup`""
}

# --- requirements check ------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn 'git not found on PATH - the collector needs it (install Git for Windows).'
}
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $nodeVersion = (& node --version) 2>$null
    Write-Say "Node $nodeVersion detected - collect-commits.mjs will be used."
}
else {
    Write-Warn 'Node not found - install Node.js 18+ to use collect-commits.mjs.'
}

# --- cleanup -----------------------------------------------------------------
if ($TmpDir -and (Test-Path $TmpDir)) {
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Say ''
Write-Say 'Done. Next steps:'
Write-Say '  1. Make sure the profile-plus MCP server is configured in OpenCode.'
Write-Say '  2. Run:  /pis-todo <Module>, <git range>, <date>, <mark-complete>'
Write-Say '  3. Example:  /pis-todo My Project, HEAD~5 -> HEAD, done'
