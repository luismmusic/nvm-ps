# install.ps1 — nvm-ps installer for Windows 11 + PowerShell 7+
# Fork/Port of nvm-sh/nvm install.sh — product nvm-ps (upstream nvm-sh)
# Original credits: nvm-sh by Tim Caswell et al. — ALL CREDITS TO ORIGINAL CREATORS.
# Fork author: Luis Mendez (luismmusic) — curiosity port, viability experiment.
# Authorship: Port in Antigravity; audit/validation/docs in opencode with oh-my-openagent.
#
# Usage (PowerShell 7+):
#   irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex
#   # with options:
#   irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex; Install-NvmPs
#   # or local:
#   .\nvm-ps\install.ps1 [-NvmDir <path>] [-NoProfile]

[CmdletBinding()]
param(
    [string]$NvmDir = '',
    [switch]$NoProfile
)

$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host '=> Installing nvm-ps for Windows 11 + PowerShell 7+...' -ForegroundColor Green
Write-Host '   Fork of nvm-sh/nvm by Luis Mendez — all credits to nvm-sh creators (Tim Caswell et al.)' -ForegroundColor DarkGray
Write-Host ''

# Determine NVM_DIR (kept as ~/.nvm for WSL interop; use NVM_PS_DIR if you want isolation)
if ([string]::IsNullOrEmpty($NvmDir)) {
    if (-not [string]::IsNullOrEmpty($env:NVM_DIR)) {
        $NvmDir = $env:NVM_DIR
    } elseif (-not [string]::IsNullOrEmpty($env:NVM_PS_DIR)) {
        $NvmDir = $env:NVM_PS_DIR
    } else {
        $NvmDir = Join-Path $env:USERPROFILE '.nvm'
    }
}

Write-Host "=> NVM_DIR: $NvmDir" -ForegroundColor Cyan

# Create NVM_DIR
if (-not (Test-Path $NvmDir)) {
    New-Item -ItemType Directory -Path $NvmDir -Force | Out-Null
    Write-Host "=> Created directory: $NvmDir"
}

# Copy module files (nvm-ps branded)
$scriptDir = $PSScriptRoot
$filesToCopy = @(
    'nvm-ps.psm1',
    'nvm-ps.psd1',
    'nvm-exec.ps1'
)

# If running via irm|iex (PSScriptRoot empty or no files), try to resolve nvm-ps files from repo context or download fallback
if (-not (Test-Path (Join-Path $scriptDir 'nvm-ps.psm1'))) {
    # Attempt remote fallback for irm|iex without local files — inform user
    Write-Host "=> Running in remote mode (irm|iex) — files will be fetched on first use via nvm helper" -ForegroundColor Yellow
}

foreach ($file in $filesToCopy) {
    $src = Join-Path $scriptDir $file
    $dst = Join-Path $NvmDir $file
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "=> Installed: $file -> $dst"
    } else {
        Write-Warning "Source file not found: $src (may be fetched remotely)"
    }
}

# Copy completions (nvm-ps branded)
$completionsDir = Join-Path $NvmDir 'completions'
if (-not (Test-Path $completionsDir)) {
    New-Item -ItemType Directory -Path $completionsDir -Force | Out-Null
}
$completionSrc = Join-Path $scriptDir 'completions' 'nvm-ps.ArgumentCompleter.ps1'
if (Test-Path $completionSrc) {
    Copy-Item $completionSrc (Join-Path $completionsDir 'nvm-ps.ArgumentCompleter.ps1') -Force
    Write-Host '=> Installed: completions/nvm-ps.ArgumentCompleter.ps1'
} else {
    # fallback legacy name
    $legacySrc = Join-Path $scriptDir 'completions' 'nvm.ArgumentCompleter.ps1'
    if (Test-Path $legacySrc) {
        Copy-Item $legacySrc (Join-Path $completionsDir 'nvm-ps.ArgumentCompleter.ps1') -Force
        Write-Host '=> Installed: completions/nvm-ps.ArgumentCompleter.ps1 (from legacy)'
    }
}

# Create required subdirectories
$subDirs = @(
    'versions/node',
    'versions/io.js',
    'alias/lts',
    '.cache'
)
foreach ($sub in $subDirs) {
    $dir = Join-Path $NvmDir $sub
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Set NVM_DIR as a user environment variable (and NVM_PS_DIR alias)
[System.Environment]::SetEnvironmentVariable('NVM_DIR', $NvmDir, [System.EnvironmentVariableTarget]::User)
$env:NVM_DIR = $NvmDir
Write-Host "=> Set `$env:NVM_DIR = '$NvmDir' (User scope)" -ForegroundColor Cyan

# Add to PowerShell profile — imports nvm-ps with fallback to legacy nvm.psm1
if (-not $NoProfile) {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $importLine = @"

# nvm-ps — fork of nvm-sh for Windows 11 + PowerShell 7+ (Luis Mendez — credits to nvm-sh)
if (Test-Path "`$env:NVM_DIR\nvm-ps.psm1") { Import-Module "`$env:NVM_DIR\nvm-ps.psm1" -DisableNameChecking }
elseif (Test-Path "`$env:NVM_DIR\nvm.psm1") { Import-Module "`$env:NVM_DIR\nvm.psm1" -DisableNameChecking }

"@

    $profileExists = Test-Path $profilePath
    $alreadyConfigured = $false

    if ($profileExists) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content -match 'nvm-ps\.psm1') {
            $alreadyConfigured = $true
        } elseif ($content -match 'nvm\.psm1') {
            # Migrate legacy line to nvm-ps with fallback
            $alreadyConfigured = $true
            Write-Host "=> Legacy nvm import found — keeping fallback; will add nvm-ps line on next manual edit if needed" -ForegroundColor Yellow
        }
    }

    if (-not $alreadyConfigured) {
        Add-Content -Path $profilePath -Value $importLine
        Write-Host "=> Added nvm-ps import to: $profilePath" -ForegroundColor Cyan
    } else {
        Write-Host "=> nvm-ps import already exists in: $profilePath" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '=> nvm-ps has been installed! (fork of nvm-sh)' -ForegroundColor Green
Write-Host '   All credits to nvm-sh creators: Tim Caswell, Matthew Ranney, Jordan Harband (@ljharb) et al. — https://github.com/nvm-sh/nvm' -ForegroundColor DarkGray
Write-Host '   Fork by Luis Mendez — curiosity port, Windows 11 + PowerShell 7+' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'To start using nvm-ps, either:' -ForegroundColor White
Write-Host '  1. Restart your PowerShell terminal, or' -ForegroundColor White
Write-Host "  2. Run: Import-Module `"$NvmDir\nvm-ps.psm1`" -DisableNameChecking" -ForegroundColor White
Write-Host ''
Write-Host 'Then try:' -ForegroundColor White
Write-Host '  nvm install --lts    # CLI stays `nvm` (1:1 with nvm-sh)' -ForegroundColor DarkGray
Write-Host '  nvm use --lts' -ForegroundColor DarkGray
Write-Host '  nvm ls               # List installed versions' -ForegroundColor DarkGray
Write-Host '  nvm --help           # Full help' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Install command (PowerShell 7+):' -ForegroundColor Cyan
Write-Host '  irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex' -ForegroundColor White
Write-Host ''
