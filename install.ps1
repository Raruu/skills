#
# install.ps1 - install the pis-todo skill (and the OpenCode slash command).
#
# Usage:
#   irm https://raw.githubusercontent.com/Raruu/skills/main/install.ps1 | iex
#   powershell -ExecutionPolicy Bypass -File install.ps1    # from a local clone
#
# Installs:
#   skills\pis-todo\             -> %USERPROFILE%\.agents\skills\pis-todo\
#   opencode\command\pis-todo.md -> %USERPROFILE%\.config\opencode\command\pis-todo.md
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

# --- locate the source files -------------------------------------------------
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = (Get-Location).Path }

$TmpDir = $null

if (Test-Path (Join-Path $ScriptDir 'skills\pis-todo')) {
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
    $Src = $extracted.FullName
    if (-not (Test-Path (Join-Path $Src 'skills\pis-todo'))) { Fail 'unexpected archive layout' }
}

# --- destinations ------------------------------------------------------------
$HomeDir         = $env:USERPROFILE
$SkillDest       = Join-Path $HomeDir '.agents\skills\pis-todo'
$CommandDestDir  = Join-Path $HomeDir '.config\opencode\command'
$CommandDest     = Join-Path $CommandDestDir 'pis-todo.md'

function Backup-IfExists {
    param([string]$Target)
    if (Test-Path $Target) {
        $stamp = Get-Date -Format 'yyyyMMddHHmmss'
        $backup = "$Target.bak-$stamp"
        Move-Item -Path $Target -Destination $backup -Force
        Write-Say "Backed up existing $(Split-Path $Target -Leaf) -> $(Split-Path $backup -Leaf)"
    }
}

# --- install the skill -------------------------------------------------------
try {
    New-Item -ItemType Directory -Path (Split-Path $SkillDest -Parent) -Force | Out-Null
    Backup-IfExists -Target $SkillDest
    New-Item -ItemType Directory -Path $SkillDest -Force | Out-Null
    Copy-Item -Path (Join-Path $Src 'skills\pis-todo\*') -Destination $SkillDest -Recurse -Force
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
        Backup-IfExists -Target $CommandDest
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
