# nvm-exec: Execution wrapper for nvm (PowerShell 7+)
# Ported from nvm-exec (bash)
#
# This script sources nvm without activating a default version,
# then switches to the specified NODE_VERSION (or .nvmrc version),
# and executes the given command.

$ErrorActionPreference = 'Stop'

# Import nvm module without auto-use
$scriptDir = $PSScriptRoot
$nvmModule = Join-Path $scriptDir 'nvm.psm1'

# Temporarily set no-use mode
$env:NVM_AUTO_MODE = 'none'
Import-Module $nvmModule -Force -DisableNameChecking
$env:NVM_AUTO_MODE = $null

if (-not [string]::IsNullOrEmpty($env:NODE_VERSION)) {
    nvm use $env:NODE_VERSION 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -and -not $?) {
        Write-Error "Failed to switch to node version $env:NODE_VERSION"
        exit 127
    }
} else {
    # Try .nvmrc
    try {
        $rcVersion = nvm_rc_version 2>$null
        if (-not [string]::IsNullOrEmpty($rcVersion)) {
            nvm_ensure_version_installed $rcVersion | Out-Null
        }
        nvm use 2>&1 | Out-Null
    } catch {
        Write-Error 'No NODE_VERSION provided; no .nvmrc file found'
        exit 127
    }
}

# Execute the remaining arguments
if ($args.Count -gt 0) {
    $cmd = $args[0]
    $cmdArgs = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }
    & $cmd @cmdArgs
    exit $LASTEXITCODE
}
