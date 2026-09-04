# ===========================================================================
# nvm-ps v0.40.7 — Node Version Manager for Windows 11 + PowerShell 7+
# Fork/Port of nvm-sh/nvm (https://github.com/nvm-sh/nvm) — nvm.sh v0.40.7
# Product: nvm-ps (Windows) — upstream: nvm-sh (Linux/macOS/WSL)
# CLI remains `nvm` for 1:1 parity (nvm install/use/ls, etc.)
#
# Implemented as a PowerShell module with a single exported function: nvm
# All internal helpers are module-private, prefixed nvm_
#
# Original credits — ALL TOOL CREDITS BELONG TO THE ORIGINAL CREATORS:
#   nvm-sh by Tim Caswell <tim@creationix.com>, Matthew Ranney,
#   Jordan Harband (@ljharb) and OpenJS Foundation contributors.
#   See https://github.com/nvm-sh/nvm and LICENSE.md.
#
# Fork/Port author: Luis Mendez (luismmusic) — this fork exists solely
#   as a curiosity experiment on the viability of porting nvm-sh to
#   native Windows 11 + PowerShell 7+. No credit claimed for the tool.
#
# How it was made (logical authorship):
#   - Initial port nvm.sh → nvm-ps: done in Antigravity.
#   - Adversarial audit, testing, final validation & publishing docs:
#     done in opencode with oh-my-openagent (hyperplan 4+plan, 3 rounds).
#
# Verdict auditoría hyperplan (opencode/oh-my-openagent): NO es 1:1 aún
#   (16 deltas, 8 P0) — ver .omo/plans/nvm-ps-port-audit.md. Header will
#   claim 1:1 only after P0-QA.
# ===========================================================================

Set-StrictMode -Version Latest

# --- Bilingual (en-US / es-ES) per BCP 47 / Microsoft Language Portal ---
# en-US: color, behavior, folder/file, customize — es-ES: color, comportamiento, carpeta/fichero, ordenador, personalizar
$script:NvmPsCulture = if ($env:NVM_PS_LANG) { $env:NVM_PS_LANG } else { try { (Get-Culture).Name } catch { 'en-US' } }
if ($env:LANG -like 'es*') { $script:NvmPsCulture = 'es-ES' }
$script:NvmIsEsES = $script:NvmPsCulture -like 'es-*'
$script:NvmMessages = @{
    'SourceNotSupported' = if ($script:NvmIsEsES) { 'Instalar desde el código fuente (-s) no es compatible en Windows. Usa la instalación binaria (predeterminada). Consulta nvm-ps/README.es-ES.md#source-fallback (ordenador con Windows 11)' } else { 'Installing from source (-s) is not supported on Windows. Use binary install (default). See nvm-ps/README.md#source-fallback' }
    'NvmNoSourceFallback' = if ($script:NvmIsEsES) { 'NVM_NO_SOURCE_FALLBACK=1 aborta si falla la descarga binaria (sin respaldo a código fuente)' } else { 'NVM_NO_SOURCE_FALLBACK=1 aborts on binary download failure (no source fallback)' }
}
function nvm_ps_t($key) { $script:NvmMessages[$key] }

# ===========================
# Section 1: Output & Utility
# ===========================

function nvm_echo {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Args_)
    $text = ($Args_ -join ' ')
    Write-Output $text
}

function nvm_echo_with_colors {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Args_)
    $text = ($Args_ -join ' ')
    # Write with ANSI escape interpretation
    [Console]::WriteLine($text)
}

function nvm_err {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Args_)
    $text = ($Args_ -join ' ')
    $Host.UI.WriteErrorLine($text)
}

function nvm_err_with_colors {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Args_)
    $text = ($Args_ -join ' ')
    $Host.UI.WriteErrorLine($text)
}

function nvm_has {
    param([string]$Command)
    if ([string]::IsNullOrEmpty($Command)) { return $false }
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function nvm_has_executable {
    param([string]$Command)
    if ([string]::IsNullOrEmpty($Command)) { return $false }
    $cmd = Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue
    $null -ne $cmd
}

function nvm_has_non_aliased {
    param([string]$Command)
    (nvm_has $Command) -and -not (nvm_is_alias $Command)
}

function nvm_is_alias {
    param([string]$Command)
    $null -ne (Get-Alias $Command -ErrorAction SilentlyContinue)
}

function nvm_command_info {
    param([string]$Command)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { return '' }
    if ($cmd.CommandType -eq 'Alias') {
        return "$($cmd.Definition) (alias for $($cmd.ReferencedCommand))"
    }
    return $cmd.Source
}

function nvm_has_colors {
    if ($env:NVM_NO_COLORS -eq '--no-colors') { return $false }
    # PowerShell 7+ on Windows Terminal supports VT sequences
    return $Host.UI.SupportsVirtualTerminal -or ($null -ne $env:WT_SESSION)
}

function nvm_stdout_is_terminal {
    return [Console]::IsOutputRedirected -eq $false
}

function nvm_is_natural_num {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return $false }
    if ($Value -eq '0') { return $false }
    return $Value -match '^\d+$'
}

function nvm_curl_libz_support { return $false }  # Not applicable on Windows
function nvm_curl_use_compression { return $false }
function nvm_curl_version { return '' }
function nvm_clang_version { return '' }

# ===================================
# Section 2: Version Comparison & Fmt
# ===================================

function nvm_version_greater {
    param([string]$V1, [string]$V2)
    if ([string]::IsNullOrEmpty($V1) -or [string]::IsNullOrEmpty($V2)) { return $false }
    $V1 = $V1.TrimStart('v')
    $V2 = $V2.TrimStart('v')
    $parts1 = $V1.Split('.')
    $parts2 = $V2.Split('.')
    for ($i = 0; $i -lt 3; $i++) {
        $a = if ($i -lt $parts1.Count -and $parts1[$i] -match '^\d+$') { [int]$parts1[$i] } else { 0 }
        $b = if ($i -lt $parts2.Count -and $parts2[$i] -match '^\d+$') { [int]$parts2[$i] } else { 0 }
        if ($a -lt $b) { return $false }
        if ($a -gt $b) { return $true }
    }
    return $false  # equal means not greater
}

function nvm_version_greater_than_or_equal_to {
    param([string]$V1, [string]$V2)
    if ([string]::IsNullOrEmpty($V1) -or [string]::IsNullOrEmpty($V2)) { return $false }
    $V1 = $V1.TrimStart('v')
    $V2 = $V2.TrimStart('v')
    $parts1 = $V1.Split('.')
    $parts2 = $V2.Split('.')
    for ($i = 0; $i -lt 3; $i++) {
        $a = if ($i -lt $parts1.Count -and $parts1[$i] -match '^\d+$') { [int]$parts1[$i] } else { 0 }
        $b = if ($i -lt $parts2.Count -and $parts2[$i] -match '^\d+$') { [int]$parts2[$i] } else { 0 }
        if ($a -lt $b) { return $false }
        if ($a -gt $b) { return $true }
    }
    return $true  # equal
}

function nvm_normalize_version {
    param([string]$Version)
    $Version = $Version.TrimStart('v')
    $parts = $Version.Split('.')
    $a = if ($parts.Count -ge 1 -and $parts[0] -match '^\d+$') { [int]$parts[0] } else { 0 }
    $b = if ($parts.Count -ge 2 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 0 }
    $c = if ($parts.Count -ge 3 -and $parts[2] -match '^\d+$') { [int]$parts[2] } else { 0 }
    return "{0}{1:D6}{2:D6}" -f $a, $b, $c
}

function nvm_normalize_lts {
    param([string]$LTS)
    if ($LTS -match '^lts/-(\d+)$') {
        $N = [int]$Matches[1] + 1
        $aliasDir = nvm_alias_path
        $ltsDir = Join-Path $aliasDir 'lts'
        if (Test-Path $ltsDir) {
            $items = @(Get-ChildItem $ltsDir -File | Sort-Object Name)
            if ($items.Count -ge $N) {
                $result = $items[$items.Count - $N].Name
                return "lts/$result"
            }
        }
        nvm_err 'That many LTS releases do not exist yet.'
        return $null
    }
    # LTS names must be lowercase
    if ($LTS -match '^lts/') {
        if ($LTS -cne $LTS.ToLower()) {
            nvm_err 'LTS names must be lowercase'
            return $null
        }
    }
    return $LTS
}

function nvm_ensure_version_prefix {
    param([string]$Version)
    $stripped = nvm_strip_iojs_prefix $Version
    if ($stripped -match '^(\d)') {
        $stripped = "v$stripped"
    }
    if (nvm_is_iojs_version $Version) {
        return (nvm_add_iojs_prefix $stripped)
    }
    return $stripped
}

function nvm_num_version_groups {
    param([string]$Version)
    $Version = $Version.TrimStart('v').TrimEnd('.')
    if ([string]::IsNullOrEmpty($Version)) { return 0 }
    return ($Version.Split('.').Count)
}

function nvm_format_version {
    param([string]$Version)
    $Version = nvm_ensure_version_prefix $Version
    $groups = nvm_num_version_groups $Version
    if ($groups -lt 3) {
        return (nvm_format_version "$($Version.TrimEnd('.')).0")
    }
    # Take first 3 groups
    $parts = $Version.Split('.')
    return ($parts[0..2] -join '.')
}

function nvm_is_valid_version {
    param([string]$Version)
    $isValid = nvm_validate_implicit_alias $Version 2>$null
    if ($isValid) { return $true }
    $iojsPrefix = nvm_iojs_prefix
    $nodePrefix = nvm_node_prefix
    if ($Version -eq $iojsPrefix -or $Version -eq $nodePrefix) { return $true }
    $stripped = nvm_strip_iojs_prefix $Version
    return (nvm_version_greater_than_or_equal_to $stripped '0')
}

function nvm_get_minor_version {
    param([string]$Version)
    if ([string]::IsNullOrEmpty($Version)) {
        nvm_err 'a version is required'
        return $null
    }
    $prefixed = nvm_format_version $Version
    if ($prefixed -match '^v(\d+\.\d+)') {
        return $Matches[1]
    }
    nvm_err 'invalid version number! (please report this)'
    return $null
}

# ==============================
# Section 3: Directory & Path
# ==============================

# Auto-detect NVM_DIR
if ([string]::IsNullOrEmpty($env:NVM_DIR)) {
    $env:NVM_DIR = Join-Path $env:USERPROFILE '.nvm'
}
# Remove trailing slashes
$env:NVM_DIR = $env:NVM_DIR.TrimEnd('\', '/')

function nvm_version_dir {
    param([string]$Which = '')
    if ([string]::IsNullOrEmpty($Which) -or $Which -eq 'new') {
        return (Join-Path $env:NVM_DIR 'versions' 'node')
    } elseif ($Which -eq 'iojs') {
        return (Join-Path $env:NVM_DIR 'versions' 'io.js')
    } elseif ($Which -eq 'old') {
        return $env:NVM_DIR
    } else {
        nvm_err 'unknown version dir'
        return $null
    }
}

function nvm_alias_path {
    return (Join-Path (nvm_version_dir 'old') 'alias')
}

function nvm_version_path {
    param([string]$Version)
    if ([string]::IsNullOrEmpty($Version)) {
        nvm_err 'version is required'
        return $null
    }
    if (nvm_is_iojs_version $Version) {
        $stripped = nvm_strip_iojs_prefix $Version
        return (Join-Path (nvm_version_dir 'iojs') $stripped)
    } elseif (nvm_version_greater '0.12.0' $Version) {
        return (Join-Path (nvm_version_dir 'old') $Version)
    } else {
        return (Join-Path (nvm_version_dir 'new') $Version)
    }
}

function nvm_tree_contains_path {
    param([string]$Tree, [string]$NodePath)
    if ([string]::IsNullOrEmpty($Tree) -or [string]::IsNullOrEmpty($NodePath)) {
        nvm_err 'both the tree and the node path are required'
        return $false
    }
    $Tree = $Tree.TrimEnd('\', '/')
    $NodePath = $NodePath.TrimEnd('\', '/')
    return $NodePath.StartsWith($Tree, [System.StringComparison]::OrdinalIgnoreCase)
}

function nvm_find_up {
    param([string]$Filename)
    $path_ = $PWD.Path
    while (-not [string]::IsNullOrEmpty($path_) -and $path_ -ne '.') {
        $candidate = Join-Path $path_ $Filename
        if (Test-Path $candidate -PathType Leaf) {
            return $path_
        }
        $parent = Split-Path $path_ -Parent
        if ($parent -eq $path_) { break }
        $path_ = $parent
    }
    return ''
}

function nvm_find_project_dir {
    $path_ = $PWD.Path
    while (-not [string]::IsNullOrEmpty($path_) -and $path_ -ne '.') {
        if ((Test-Path (Join-Path $path_ 'package.json') -PathType Leaf) -or
            (Test-Path (Join-Path $path_ 'node_modules') -PathType Container)) {
            return $path_
        }
        $parent = Split-Path $path_ -Parent
        if ($parent -eq $path_) { break }
        $path_ = $parent
    }
    return $path_
}

function nvm_find_nvmrc {
    $dir = nvm_find_up '.nvmrc'
    if (-not [string]::IsNullOrEmpty($dir)) {
        $nvmrcPath = Join-Path $dir '.nvmrc'
        if (Test-Path $nvmrcPath) {
            return $nvmrcPath
        }
    }
    return ''
}

function nvm_sanitize_path {
    param([string]$Path_)
    if ([string]::IsNullOrEmpty($Path_)) { return $Path_ }
    $result = $Path_
    if (-not [string]::IsNullOrEmpty($env:NVM_DIR) -and $result -ne $env:NVM_DIR) {
        $result = $result.Replace($env:NVM_DIR, '${NVM_DIR}')
    }
    $home_ = $env:USERPROFILE
    if (-not [string]::IsNullOrEmpty($home_) -and $result -ne $home_) {
        $result = $result.Replace($home_, '${HOME}')
    }
    return $result
}

function nvm_cache_dir {
    return (Join-Path $env:NVM_DIR '.cache')
}

function nvm_strip_path {
    param([string]$PathVar, [string]$Suffix)
    if ([string]::IsNullOrEmpty($env:NVM_DIR)) {
        nvm_err '${NVM_DIR} not set!'
        return $PathVar
    }

    $parts = $PathVar.Split(';')
    $filtered = @()
    foreach ($p in $parts) {
        $normalized = $p.Replace('/', '\')
        if ($normalized -match [regex]::Escape($env:NVM_DIR)) {
            # Check if this is an nvm-managed path
            $relative = $normalized.Substring($env:NVM_DIR.Length)
            if ($relative -match '^(\\versions\\[^\\]*)?\\[^\\]*$' -or
                $relative -match "^\\[^\\]+$") {
                continue  # skip this path entry
            }
        }
        $filtered += $p
    }
    return ($filtered -join ';')
}

function nvm_change_path {
    param([string]$CurrentPath, [string]$Suffix, [string]$NewDir)
    # On Windows, the suffix for node is empty (node.exe lives directly in version dir)
    # But we keep the parameter for API compatibility
    $nvmDir = $env:NVM_DIR

    if ([string]::IsNullOrEmpty($CurrentPath)) {
        return $NewDir
    }

    $parts = $CurrentPath.Split(';')
    $found = $false
    $result = @()

    foreach ($p in $parts) {
        $normalized = $p.Replace('/', '\')
        if ($normalized.StartsWith($nvmDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            if (-not $found) {
                $result += $NewDir
                $found = $true
            }
            # Skip old nvm path entries
        } else {
            $result += $p
        }
    }

    if (-not $found) {
        # Prepend
        $result = @($NewDir) + $result
    }

    return ($result -join ';')
}

function nvm_check_file_permissions {
    param([string]$Dir)
    # On Windows, we just check if we can write to the directory
    if (-not (Test-Path $Dir)) { return $true }
    try {
        $testFile = Join-Path $Dir ".nvm_perm_test_$(Get-Random)"
        [System.IO.File]::WriteAllText($testFile, 'test')
        Remove-Item $testFile -Force
        return $true
    } catch {
        return $false
    }
}

# ============================
# Section 4: .nvmrc Processing
# ============================

function nvm_nvmrc_invalid_msg {
    param([string]$Lines)
    $errorText = @"
invalid .nvmrc!
all non-commented content (anything after # is a comment) must be either:
  - a single bare nvm-recognized version-ish
  - or, multiple distinct key-value pairs, each key/value separated by a single equals sign (=)

additionally, a single bare nvm-recognized version-ish must be present (after stripping comments).
"@
    $warnText = "non-commented content parsed:`n$Lines"
    nvm_err (nvm_wrap_with_color_code 'r' $errorText)
    nvm_err ''
    nvm_err (nvm_wrap_with_color_code 'y' $warnText)
}

function nvm_process_nvmrc_content {
    param([string]$Content)

    # Strip comments, trim whitespace, remove empty lines
    $lines = @()
    foreach ($rawLine in $Content.Split("`n")) {
        $line = ($rawLine -replace '#.*$', '').Trim()
        if (-not [string]::IsNullOrEmpty($line)) {
            $lines += $line
        }
    }

    if ($lines.Count -eq 0) {
        nvm_nvmrc_invalid_msg ''
        return $null
    }

    $keys = @()
    $unpairedLine = ''

    foreach ($line in $lines) {
        if ([string]::IsNullOrEmpty($line)) { continue }

        if ($line.Contains('=')) {
            $eqIdx = $line.IndexOf('=')
            $key = $line.Substring(0, $eqIdx).Trim()


            if ([string]::IsNullOrEmpty($key)) {
                # Line starts with =, treat as unpaired
                if (-not [string]::IsNullOrEmpty($unpairedLine)) {
                    nvm_nvmrc_invalid_msg ($lines -join "`n")
                    return $null
                }
                $unpairedLine = $line
                continue
            }

            if ($key -eq 'node') {
                nvm_nvmrc_invalid_msg ($lines -join "`n")
                return $null
            }

            if ($key -in $keys) {
                nvm_nvmrc_invalid_msg ($lines -join "`n")
                return $null
            }
            $keys += $key
        } else {
            if (-not [string]::IsNullOrEmpty($unpairedLine)) {
                nvm_nvmrc_invalid_msg ($lines -join "`n")
                return $null
            }
            $unpairedLine = $line
        }
    }

    if ([string]::IsNullOrEmpty($unpairedLine)) {
        nvm_nvmrc_invalid_msg ($lines -join "`n")
        return $null
    }

    return $unpairedLine
}

function nvm_process_nvmrc {
    param([string]$NvmrcPath)
    $content = Get-Content $NvmrcPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { return $null }
    return (nvm_process_nvmrc_content $content)
}

function nvm_rc_version {
    $nvmrcPath = nvm_find_nvmrc
    if ([string]::IsNullOrEmpty($nvmrcPath) -or -not (Test-Path $nvmrcPath)) {
        if ($env:NVM_SILENT -ne '1') {
            nvm_err 'No version provided and no .nvmrc file found'
        }
        return $null
    }

    $rcVersion = nvm_process_nvmrc $nvmrcPath
    if ($null -eq $rcVersion) { return $null }

    if ([string]::IsNullOrEmpty($rcVersion)) {
        if ($env:NVM_SILENT -ne '1') {
            nvm_err "Warning: empty .nvmrc file found at `"$nvmrcPath`""
        }
        return $null
    }

    if ($env:NVM_SILENT -ne '1') {
        nvm_echo "Found '$nvmrcPath' with version <$rcVersion>"
    }
    return $rcVersion
}

function nvm_write_nvmrc {
    param([string]$Version)
    $versionString = nvm_version $Version
    if ($versionString -eq ([char]0x221E).ToString() -or $versionString -eq 'N/A') {
        return $false
    }
    $nvmrcFile = Join-Path $PWD.Path '.nvmrc'
    try {
        [System.IO.File]::WriteAllText($nvmrcFile, $versionString)
        if ($env:NVM_SILENT -ne '1') {
            nvm_echo "Wrote version number ($versionString) to .nvmrc"
        }
        return $true
    } catch {
        if ($env:NVM_SILENT -ne '1') {
            nvm_err "Warning: Unable to write version number ($versionString) to .nvmrc"
        }
        return $false
    }
}

# ==========================
# Section 5: Alias Management
# ==========================

function nvm_make_alias {
    param([string]$AliasName, [string]$Version)
    if ([string]::IsNullOrEmpty($AliasName)) {
        nvm_err 'an alias name is required'
        return $false
    }
    if ([string]::IsNullOrEmpty($Version)) {
        nvm_err 'an alias target version is required'
        return $false
    }
    # Reject path traversal
    if ($AliasName -match '\.\.[\\/]') {
        nvm_err "invalid alias name: $AliasName"
        return $false
    }
    
    $safeAliasName = if ($AliasName -eq 'lts/*') { 'lts/latest' } else { $AliasName }
    $aliasPath = Join-Path (nvm_alias_path) $safeAliasName
    $aliasDir = Split-Path $aliasPath -Parent
    if (-not (Test-Path $aliasDir)) {
        New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($aliasPath, $Version)
    return $true
}

function nvm_alias {
    param([string]$AliasName)
    if ([string]::IsNullOrEmpty($AliasName)) {
        nvm_err 'An alias is required.'
        return $null
    }
    $normalized = nvm_normalize_lts $AliasName
    if ($null -eq $normalized) { return $null }
    $AliasName = $normalized
    if ([string]::IsNullOrEmpty($AliasName)) { return $null }

    $safeAliasName = if ($AliasName -eq 'lts/*') { 'lts/latest' } else { $AliasName }
    $aliasFile = Join-Path (nvm_alias_path) $safeAliasName
    if (-not (Test-Path $aliasFile -PathType Leaf)) {
        return $null
    }

    $content = Get-Content $aliasFile -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) {
        nvm_err "Alias file is not readable: $aliasFile"
        return ''
    }

    # Process: strip comments, trim, return first non-empty line
    foreach ($rawLine in $content.Split("`n")) {
        $line = ($rawLine -replace '#.*$', '').Trim()
        if (-not [string]::IsNullOrEmpty($line)) {
            return $line
        }
    }
    return ''
}

function nvm_resolve_alias {
    param([string]$Pattern)
    if ([string]::IsNullOrEmpty($Pattern)) { return $null }

    $alias_ = $Pattern
    $seenAliases = @($alias_)

    while ($true) {
        $aliasOutput = nvm_alias $alias_ 2>$null
        if ([string]::IsNullOrEmpty($aliasOutput)) { break }

        $aliasTemp = ($aliasOutput.Split("`n") | Select-Object -First 1).Trim()
        if ([string]::IsNullOrEmpty($aliasTemp)) { break }

        if ($aliasTemp -in $seenAliases) {
            $alias_ = [char]0x221E  # ∞
            break
        }

        $seenAliases += $aliasTemp
        $alias_ = $aliasTemp
    }

    $infinity = [char]0x221E
    if (-not [string]::IsNullOrEmpty($alias_) -and $alias_ -ne $Pattern) {
        $iojsPrefix = nvm_iojs_prefix
        $nodePrefix = nvm_node_prefix
        if ($alias_ -eq $infinity -or $alias_ -eq $iojsPrefix -or $alias_ -eq "$iojsPrefix-" -or $alias_ -eq $nodePrefix) {
            return $alias_
        }
        return (nvm_ensure_version_prefix $alias_)
    }

    $isValid = nvm_validate_implicit_alias $Pattern 2>$null
    if ($isValid) {
        $implicit = nvm_print_implicit_alias 'local' $Pattern 2>$null
        if (-not [string]::IsNullOrEmpty($implicit)) {
            return (nvm_ensure_version_prefix $implicit)
        }
    }

    return $null
}

function nvm_resolve_local_alias {
    param([string]$AliasName)
    if ([string]::IsNullOrEmpty($AliasName)) { return $null }
    $version = nvm_resolve_alias $AliasName
    if ([string]::IsNullOrEmpty($version)) { return $null }
    $infinity = [char]0x221E
    if ($version -ne $infinity) {
        return (nvm_version $version)
    }
    return $version
}

function nvm_ensure_default_set {
    param([string]$Version)
    if ([string]::IsNullOrEmpty($Version)) {
        nvm_err 'nvm_ensure_default_set: a version is required'
        return $false
    }
    $existing = nvm_alias 'default' 2>$null
    if (-not [string]::IsNullOrEmpty($existing)) { return $true }

    nvm_echo "Creating default alias: default -> $Version"
    nvm_make_alias 'default' $Version | Out-Null
    return $true
}

function nvm_validate_implicit_alias {
    param([string]$Name)
    $iojsPrefix = nvm_iojs_prefix
    $nodePrefix = nvm_node_prefix
    if ($Name -in @('stable', 'unstable', $iojsPrefix, $nodePrefix)) {
        return $true
    }
    return $false
}

function nvm_print_implicit_alias {
    param([string]$Scope, [string]$ImplicitName)
    if ($Scope -ne 'local' -and $Scope -ne 'remote') {
        nvm_err 'nvm_print_implicit_alias must be specified with local or remote as the first argument.'
        return $null
    }
    if (-not (nvm_validate_implicit_alias $ImplicitName)) { return $null }

    $iojsPrefix = nvm_iojs_prefix
    $nodePrefix = nvm_node_prefix

    if ($ImplicitName -eq $nodePrefix) {
        return 'stable'
    }

    if ($ImplicitName -eq $iojsPrefix) {
        if ($Scope -eq 'local') {
            $versions = nvm_ls $iojsPrefix
        } else {
            $versions = nvm_ls_remote_iojs
        }
        if ($null -eq $versions -or $versions -eq 'N/A') { return 'N/A' }
        $versionLines = @($versions) | Where-Object { $_ -match '^v' }
        if ($versionLines.Count -eq 0) { return 'N/A' }
        $last = ($versionLines | Select-Object -Last 1).TrimStart("$iojsPrefix-")
        $minor = ($last.TrimStart('v').Split('.')[0..1]) -join '.'
        return (nvm_add_iojs_prefix $minor)
    }

    # stable / unstable
    if ($Scope -eq 'local') {
        $versions = nvm_ls 'node'
    } else {
        $versions = nvm_ls_remote
    }
    $versionLines = @($versions) | Where-Object { $_ -match '^v' }
    $lastTwo = @()
    foreach ($v in $versionLines) {
        $vParts = $v.TrimStart('v').Split('.')
        $minor = if ($vParts.Count -ge 2) { $vParts[0..1] -join '.' } else { $vParts[0] }
        if ($minor -notin $lastTwo) { $lastTwo += $minor }
    }

    $stable = ''
    $unstable = ''
    foreach ($minor in $lastTwo) {
        $normalized = nvm_normalize_version $minor
        $majorPart = [int]($normalized.Substring(0, $normalized.Length - 12))
        if ($majorPart -gt 0 -or ($majorPart % 2) -eq 0) {
            $stable = $minor
        } else {
            $unstable = $minor
        }
    }

    if ($ImplicitName -eq 'stable') { return $stable }
    if ($ImplicitName -eq 'unstable') {
        if ([string]::IsNullOrEmpty($unstable)) { return 'N/A' }
        return $unstable
    }
    return $null
}

function nvm_list_aliases {
    param([string]$Pattern = '')
    $aliasDir = nvm_alias_path
    $ltsDir = Join-Path $aliasDir 'lts'
    if (-not (Test-Path $aliasDir)) { New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null }
    if (-not (Test-Path $ltsDir)) { New-Item -ItemType Directory -Path $ltsDir -Force | Out-Null }

    $nvmCurrent = nvm_ls_current

    # List user aliases
    $searchPattern = if ([string]::IsNullOrEmpty($Pattern)) { '*' } else { "$Pattern*" }

    # Skip lts/ subdirectory for regular aliases
    $aliasFiles = Get-ChildItem $aliasDir -File -Filter $searchPattern -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -ne 'lts' }

    foreach ($f in ($aliasFiles | Sort-Object Name)) {
        $aliasName = $f.Name
        $dest = nvm_alias $aliasName 2>$null
        if (-not [string]::IsNullOrEmpty($dest)) {
            $version = nvm_version $dest 2>$null
            nvm_print_formatted_alias $aliasName $dest $version $false $nvmCurrent
        }
    }

    # List implicit aliases (if no file overrides)
    $nodePrefix = nvm_node_prefix
    $iojsPrefix = nvm_iojs_prefix
    foreach ($implName in @($nodePrefix, 'stable', 'unstable', $iojsPrefix)) {
        $implFile = Join-Path $aliasDir $implName
        if (-not (Test-Path $implFile) -and ([string]::IsNullOrEmpty($Pattern) -or $implName -like "$Pattern*")) {
            $dest = nvm_print_implicit_alias 'local' $implName 2>$null
            if (-not [string]::IsNullOrEmpty($dest)) {
                nvm_print_formatted_alias $implName $dest '' $true $nvmCurrent
            }
        }
    }

    # List LTS aliases
    $ltsFiles = Get-ChildItem $ltsDir -File -Filter $searchPattern -ErrorAction SilentlyContinue
    foreach ($f in ($ltsFiles | Sort-Object Name)) {
        $aliasName = if ($f.Name -eq 'latest') { 'lts/*' } else { "lts/$($f.Name)" }
        $dest = nvm_alias $aliasName 2>$null
        if (-not [string]::IsNullOrEmpty($dest)) {
            $version = nvm_version $dest 2>$null
            nvm_print_formatted_alias $aliasName $dest $version $false $nvmCurrent $true
        }
    }
}

# ====================
# Section 6: Colors
# ====================

function nvm_print_color_code {
    param([string]$Code)
    switch ($Code) {
        '0' { return '' }
        'r' { return '0;31m' }
        'R' { return '1;31m' }
        'g' { return '0;32m' }
        'G' { return '1;32m' }
        'b' { return '0;34m' }
        'B' { return '1;34m' }
        'c' { return '0;36m' }
        'C' { return '1;36m' }
        'm' { return '0;35m' }
        'M' { return '1;35m' }
        'y' { return '0;33m' }
        'Y' { return '1;33m' }
        'k' { return '0;30m' }
        'K' { return '1;30m' }
        'e' { return '0;37m' }
        'W' { return '1;37m' }
        default { return '' }
    }
}

function nvm_wrap_with_color_code {
    param([string]$ColorChar, [string]$Text)
    $code = nvm_print_color_code $ColorChar
    if ((nvm_has_colors) -and -not [string]::IsNullOrEmpty($code)) {
        return "$([char]27)[${code}${Text}$([char]27)[0m"
    }
    return $Text
}

function nvm_set_colors {
    param([string]$Colors)
    if ($Colors.Length -eq 5 -and $Colors -match '^[rRgGbBcCyYmMkKeW]{5}$') {
        $env:NVM_COLORS = $Colors
        if (nvm_has_colors) {
            $display = ''
            foreach ($c in $Colors.ToCharArray()) {
                $display += (nvm_wrap_with_color_code ([string]$c) ([string]$c))
            }
            nvm_echo "Setting colors to: $display"
        } else {
            nvm_echo "Setting colors to: $Colors"
            nvm_echo 'WARNING: Colors may not display because they are not supported in this shell.'
        }
        return $true
    }
    return $false
}

function nvm_get_colors {
    param([int]$Index)
    $colors = if (-not [string]::IsNullOrEmpty($env:NVM_COLORS)) { $env:NVM_COLORS } else { 'bygre' }
    if ($Index -ge 1 -and $Index -le 5) {
        return (nvm_print_color_code ([string]$colors[$Index - 1]))
    }
    if ($Index -eq 6) {
        $sysColor = nvm_print_color_code ([string]$colors[1])
        return ($sysColor -replace '0;', '1;')
    }
    return ''
}

function nvm_print_formatted_alias {
    param(
        [string]$AliasName,
        [string]$Dest,
        [string]$Version = '',
        [bool]$IsDefault = $false,
        [string]$NvmCurrent = '',
        [bool]$IsLTS = $false
    )
    if ([string]::IsNullOrEmpty($Version)) {
        $Version = nvm_version $Dest 2>$null
        if ($null -eq $Version) { $Version = 'N/A' }
    }

    $esc = [char]27
    $infinity = [char]0x221E
    $hasColors = nvm_has_colors

    $installedColor = nvm_get_colors 1
    $currentColor = nvm_get_colors 3
    $notInstalledColor = nvm_get_colors 4
    $defaultColor = nvm_get_colors 5
    $ltsColor = nvm_get_colors 6

    $arrow = if ($hasColors) { "${esc}[0;90m->${esc}[0m" } else { '->' }
    $defaultSuffix = ''
    if ($IsDefault) {
        $defaultSuffix = if ($hasColors) { " ${esc}[${defaultColor}(default)${esc}[0m" } else { ' (default)' }
    }

    # Determine color
    $colorCode = ''
    if ($hasColors) {
        if ($Version -eq $NvmCurrent -and -not [string]::IsNullOrEmpty($NvmCurrent)) {
            $colorCode = $currentColor
        } elseif (nvm_is_version_installed $Version) {
            $colorCode = $installedColor
        } elseif ($Version -eq $infinity -or $Version -eq 'N/A') {
            $colorCode = $notInstalledColor
        }
    }

    $aliasDisplay = $AliasName
    $destDisplay = $Dest
    $versionDisplay = $Version

    if ($hasColors -and -not [string]::IsNullOrEmpty($colorCode)) {
        $aliasDisplay = "${esc}[${colorCode}${AliasName}${esc}[0m"
        $destDisplay = "${esc}[${colorCode}${Dest}${esc}[0m"
        $versionDisplay = "${esc}[${colorCode}${Version}${esc}[0m"
    }

    if ($IsLTS -and $hasColors) {
        $aliasDisplay = "${esc}[${ltsColor}${AliasName}${esc}[0m"
    }
    if ($Dest -match '^lts/' -and $hasColors) {
        $destDisplay = "${esc}[${ltsColor}${Dest}${esc}[0m"
    }

    if ($Dest -eq $Version) {
        nvm_echo "$aliasDisplay $arrow $versionDisplay$defaultSuffix"
    } else {
        nvm_echo "$aliasDisplay $arrow $destDisplay ($arrow $versionDisplay)$defaultSuffix"
    }
}

# ====================================
# Section 7: Version Listing & Current
# ====================================

function nvm_is_version_installed {
    param([string]$Version)
    if ([string]::IsNullOrEmpty($Version)) { return $false }
    $versionPath = nvm_version_path $Version 2>$null
    if ([string]::IsNullOrEmpty($versionPath)) { return $false }
    $nodeBin = Join-Path $versionPath 'node.exe'
    return (Test-Path $nodeBin -PathType Leaf)
}

function nvm_validate_install {
    param([string]$Version)
    if ([string]::IsNullOrEmpty($Version)) { return $false }
    $versionPath = nvm_version_path $Version 2>$null
    if ([string]::IsNullOrEmpty($versionPath) -or -not (Test-Path $versionPath -PathType Container)) { return $false }
    $nodeBin = Join-Path $versionPath 'node.exe'
    if (-not (Test-Path $nodeBin -PathType Leaf)) {
        nvm_err "The installed node binary at $nodeBin is missing."
        return $false
    }
    $fileInfo = Get-Item $nodeBin
    if ($fileInfo.Length -eq 0) {
        nvm_err "The installed node binary at $nodeBin is empty."
        return $false
    }
    return $true
}

function nvm_ls_current {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $nodeCmd) { return 'none' }
    $nodePath = $nodeCmd.Source

    $iojsDir = nvm_version_dir 'iojs'
    if (nvm_tree_contains_path $iojsDir $nodePath) {
        $iojsVersion = & iojs --version 2>$null
        return (nvm_add_iojs_prefix $iojsVersion)
    }

    if (nvm_tree_contains_path $env:NVM_DIR $nodePath) {
        $version = & node --version 2>$null
        if ($version -eq 'v0.6.21-pre') { return 'v0.6.21' }
        if ([string]::IsNullOrEmpty($version)) { return 'none' }
        return $version
    }

    return 'system'
}

function nvm_has_system_node {
    # Check if there's a node outside of NVM_DIR
    $saved = $env:PATH
    $newPath = nvm_strip_path $env:PATH '/bin'
    $env:PATH = $newPath
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    $env:PATH = $saved
    return ($null -ne $cmd)
}

function nvm_has_system_iojs {
    $saved = $env:PATH
    $newPath = nvm_strip_path $env:PATH '/bin'
    $env:PATH = $newPath
    $cmd = Get-Command iojs -ErrorAction SilentlyContinue
    $env:PATH = $saved
    return ($null -ne $cmd)
}

function nvm_version {
    param([string]$Pattern = '')
    if ([string]::IsNullOrEmpty($Pattern)) { $Pattern = 'current' }
    if ($Pattern -eq 'current') {
        return (nvm_ls_current)
    }

    $nodePrefix = nvm_node_prefix
    if ($Pattern -eq $nodePrefix -or $Pattern -eq "$nodePrefix-") {
        $Pattern = 'stable'
    }

    $versions = nvm_ls $Pattern
    if ($null -eq $versions) {
        nvm_echo 'N/A'
        return 'N/A'
    }
    $versionList = @($versions)
    $last = $versionList | Select-Object -Last 1
    if ($last -match '^system\s') { $last = 'system' }

    if ([string]::IsNullOrEmpty($last) -or $last -eq 'N/A') {
        nvm_echo 'N/A'
        return 'N/A'
    }
    # Extract just the version (first word)
    $last = ($last -split '\s+')[0]
    return $last
}

function nvm_ls {
    param([string]$Pattern = '')

    # Handle nvmrc-style content
    if ($Pattern -match '#' -or $Pattern -match "`n") {
        $nvmrcPattern = nvm_process_nvmrc_content $Pattern 2>$null
        if ($null -eq $nvmrcPattern) { return 'N/A' }
        $Pattern = $nvmrcPattern
    }

    if ($Pattern -eq 'current') {
        return (nvm_ls_current)
    }

    $iojsPrefix = nvm_iojs_prefix
    $nodePrefix = nvm_node_prefix
    $versionDirIojs = nvm_version_dir 'iojs'
    $versionDirNew = nvm_version_dir 'new'
    $versionDirOld = nvm_version_dir 'old'

    # Handle aliases
    if ($Pattern -ne "$iojsPrefix-" -and $Pattern -ne "$nodePrefix-" -and $Pattern -ne "$iojsPrefix" -and $Pattern -ne "$nodePrefix") {
        # Check if it resolves to 'system'
        $aliasTarget = nvm_resolve_alias $Pattern 2>$null
        if ($aliasTarget -eq 'system' -and ((nvm_has_system_node) -or (nvm_has_system_iojs))) {
            $sysVersion = ''
            $saved = $env:PATH
            $env:PATH = nvm_strip_path $env:PATH '/bin'
            try { $sysVersion = & node -v 2>$null } catch {}
            $env:PATH = $saved
            if (-not [string]::IsNullOrEmpty($sysVersion)) { return "system $sysVersion" }
            return 'system'
        }

        $localResolved = nvm_resolve_local_alias $Pattern
        if (-not [string]::IsNullOrEmpty($localResolved) -and $localResolved -ne 'N/A') {
            return $localResolved
        }

        if ($Pattern -ne $iojsPrefix -and $Pattern -ne $nodePrefix) {
            $Pattern = nvm_ensure_version_prefix $Pattern
        }
    }

    if ($Pattern -eq $iojsPrefix -or $Pattern -eq $nodePrefix) {
        $Pattern = "$Pattern-"
    }

    if ($Pattern -eq 'N/A') { return $null }

    # Exact 3-group version check
    $startsWithV = $Pattern.StartsWith('v')
    if ($startsWithV -and (nvm_num_version_groups $Pattern) -eq 3) {
        if (nvm_is_version_installed $Pattern) { return $Pattern }
        $iojsVersion = nvm_add_iojs_prefix $Pattern
        if (nvm_is_version_installed $iojsVersion) { return $iojsVersion }
        return 'N/A'
    }

    # Collect versions from directories
    $versions = @()
    $addSystem = $false
    $searchDirs = @()

    if (nvm_is_iojs_version $Pattern) {
        $searchDirs += $versionDirIojs
        $Pattern = nvm_strip_iojs_prefix $Pattern
        if (nvm_has_system_iojs) { $addSystem = $true }
    } elseif ($Pattern -eq "$nodePrefix-") {
        $searchDirs += $versionDirOld
        $searchDirs += $versionDirNew
        $Pattern = ''
        if (nvm_has_system_node) { $addSystem = $true }
    } else {
        $searchDirs += $versionDirOld
        $searchDirs += $versionDirNew
        $searchDirs += $versionDirIojs
        if ((nvm_has_system_node) -or (nvm_has_system_iojs)) { $addSystem = $true }
    }

    # Add dot for partial versions
    if ($Pattern -ne "$iojsPrefix-" -and $Pattern -ne "$nodePrefix-" -and $Pattern -ne 'system' -and -not [string]::IsNullOrEmpty($Pattern)) {
        $groups = nvm_num_version_groups $Pattern
        if ($groups -eq 1 -or $groups -eq 2) {
            $Pattern = $Pattern.TrimEnd('.') + '.'
        }
    }

    if ([string]::IsNullOrEmpty($Pattern)) { $Pattern = 'v' }

    foreach ($dir in $searchDirs) {
        if (-not (Test-Path $dir -PathType Container)) { continue }
        $subdirs = Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue
        foreach ($d in $subdirs) {
            $vName = $d.Name
            # Check if it matches the pattern
            if ($vName.StartsWith($Pattern) -or ($Pattern -eq 'v' -and $vName.StartsWith('v'))) {
                $fullVersion = $vName
                # Add iojs prefix if from iojs dir
                if ($dir -eq $versionDirIojs) {
                    $fullVersion = nvm_add_iojs_prefix $vName
                }
                $versions += $fullVersion
            }
        }
    }

    # Sort versions
    $versions = @($versions | Sort-Object -Unique {
        $v = $_ -replace '^iojs-', ''
        $v = $v.TrimStart('v')
        $parts = $v.Split('.')
        $major = if ($parts.Count -ge 1 -and $parts[0] -match '^\d+$') { [int]$parts[0] } else { 0 }
        $minor = if ($parts.Count -ge 2 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 0 }
        $patch = if ($parts.Count -ge 3 -and $parts[2] -match '^\d+$') { [int]$parts[2] } else { 0 }
        $major * 1000000 + $minor * 1000 + $patch
    })

    # Add system version
    if ($addSystem) {
        $sysVersion = ''
        $saved = $env:PATH
        $env:PATH = nvm_strip_path $env:PATH '/bin'
        try { $sysVersion = & node -v 2>$null } catch {}
        $env:PATH = $saved
        if (-not [string]::IsNullOrEmpty($sysVersion)) {
            $versions += "system $sysVersion"
        } else {
            $versions += 'system'
        }
    }

    if ($versions.Count -eq 0) { return 'N/A' }
    return $versions
}

function nvm_remote_version {
    param([string]$Pattern = '')
    $version = 'N/A'

    $isValid = nvm_validate_implicit_alias $Pattern 2>$null
    if ($isValid) {
        if ($Pattern -eq (nvm_iojs_prefix)) {
            $version = @(nvm_ls_remote_iojs) | Select-Object -Last 1
        } else {
            $version = nvm_ls_remote $Pattern
        }
    } else {
        $version = @(nvm_remote_versions $Pattern) | Select-Object -Last 1
    }

    if (-not [string]::IsNullOrEmpty($Pattern) -and $version -ne 'N/A') {
        $isValid = nvm_validate_implicit_alias $Pattern 2>$null
        if (-not $isValid) {
            $versionNum = ($version -split '\s+')[0]
            if ($versionNum -notmatch [regex]::Escape($Pattern)) {
                $version = 'N/A'
            }
        }
    }

    if ($env:NVM_VERSION_ONLY -eq 'true') {
        $version = ($version -split '\s+')[0]
    }

    if ([string]::IsNullOrEmpty($version)) { $version = 'N/A' }
    return $version
}

function nvm_remote_versions {
    param([string]$Pattern = '')
    $iojsPrefix = nvm_iojs_prefix
    $nodePrefix = nvm_node_prefix

    $nvmFlavor = ''
    if (-not [string]::IsNullOrEmpty($env:NVM_LTS_TEMP)) { $nvmFlavor = $nodePrefix }

    switch ($Pattern) {
        { $_ -eq $iojsPrefix -or $_ -eq 'io.js' } { $nvmFlavor = $iojsPrefix; $Pattern = '' }
        $nodePrefix { $nvmFlavor = $nodePrefix; $Pattern = '' }
    }

    $preOutput = ''
    $postOutput = ''
    $iojsOutput = ''

    if ([string]::IsNullOrEmpty($nvmFlavor) -or $nvmFlavor -eq $nodePrefix) {
        $nodeOutput = nvm_ls_remote $Pattern
        if ($null -ne $nodeOutput) {
            $nodeLines = @($nodeOutput)
            # Split at v4.0.0 for merge point
            $preLines = @()
            $postLines = @()
            $foundV4 = $false
            foreach ($line in $nodeLines) {
                if (-not $foundV4 -and $line -match '^v4\.0\.0') { $foundV4 = $true }
                if ($foundV4) { $postLines += $line } else { $preLines += $line }
            }
            $preOutput = $preLines
            $postOutput = $postLines
        }
    }

    if ([string]::IsNullOrEmpty($env:NVM_LTS_TEMP) -and ([string]::IsNullOrEmpty($nvmFlavor) -or $nvmFlavor -eq $iojsPrefix)) {
        $iojsOutput = @(nvm_ls_remote_iojs $Pattern)
    }

    $allVersions = @()
    $allVersions += $preOutput | Where-Object { $_ -and $_ -ne 'N/A' }
    $allVersions += $iojsOutput | Where-Object { $_ -and $_ -ne 'N/A' }
    $allVersions += $postOutput | Where-Object { $_ -and $_ -ne 'N/A' }
    $allVersions = $allVersions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($allVersions.Count -eq 0) { return 'N/A' }
    return $allVersions
}

function nvm_match_version {
    param([string]$ProvidedVersion)
    $iojsPrefix = nvm_iojs_prefix
    if ($ProvidedVersion -eq $iojsPrefix -or $ProvidedVersion -eq 'io.js') {
        return (nvm_version $iojsPrefix)
    }
    if ($ProvidedVersion -eq 'system') { return 'system' }
    return (nvm_version $ProvidedVersion)
}

function nvm_print_npm_version {
    if (nvm_has 'npm') {
        $npmVersion = & npm --version 2>$null
        if (-not [string]::IsNullOrEmpty($npmVersion)) {
            return " (npm v$npmVersion)"
        }
    }
    return ''
}

function nvm_print_versions {
    param([string[]]$RemoteVersions)
    $nvmCurrent = nvm_ls_current
    $installedVersions = @(nvm_ls) | ForEach-Object { ($_ -split '\s+')[0] }

    $installedColor = nvm_get_colors 1
    $systemColor = nvm_get_colors 2
    $currentColor = nvm_get_colors 3
    $defaultColor = nvm_get_colors 5
    $hasColors = nvm_has_colors

    $esc = [char]27
    $latestLtsColor = $currentColor -replace '0;', '1;'

    foreach ($line in $RemoteVersions) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $fields = $line.Trim() -split '\s+'
        $version = $fields[0]
        $isInstalled = $version -in $installedVersions

        $formatted = ''
        if ($version -eq $nvmCurrent) {
            if ($hasColors -and $currentColor) {
                $formatted = "${esc}[${currentColor}" + ('->{0,13}' -f $version) + "${esc}[0m"
            } else {
                $formatted = '->{0,13} *' -f $version
            }
        } elseif ($version -eq 'system') {
            if ($hasColors -and $systemColor) {
                $formatted = "${esc}[${systemColor}" + ('{0,15}' -f $version) + "${esc}[0m"
            } else {
                $formatted = '{0,15} *' -f $version
            }
        } elseif ($isInstalled) {
            if ($hasColors -and $installedColor) {
                $formatted = "${esc}[${installedColor}" + ('{0,15}' -f $version) + "${esc}[0m"
            } else {
                $formatted = '{0,15} *' -f $version
            }
        } else {
            $formatted = '{0,15}' -f $version
        }

        $padding = if (-not $hasColors -and $isInstalled) { '' } else { '  ' }

        # Handle LTS info
        if ($version -eq 'system' -and $fields.Count -ge 2) {
            $sysTarget = $fields[1]
            if ($hasColors -and $systemColor) {
                $formatted += " (${esc}[${systemColor}-> $sysTarget${esc}[0m)"
            } else {
                $formatted += " (-> $sysTarget)"
            }
        } elseif ($fields.Count -eq 2) {
            $ltsName = $fields[1]
            if ($hasColors -and $defaultColor) {
                $formatted += "${padding}${esc}[${defaultColor} (LTS: $ltsName)${esc}[0m"
            } else {
                $formatted += "${padding} (LTS: $ltsName)"
            }
        } elseif ($fields.Count -ge 3 -and $fields[2] -eq '*') {
            $ltsName = $fields[1]
            if ($hasColors -and $latestLtsColor) {
                $formatted += "${padding}${esc}[${latestLtsColor} (Latest LTS: $ltsName)${esc}[0m"
            } else {
                $formatted += "${padding} (Latest LTS: $ltsName)"
            }
        }

        nvm_echo $formatted
    }
}

# ==============================
# Section 8: OS / Arch Detection
# ==============================

function nvm_get_os {
    return 'win'
}

function nvm_get_arch {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    switch ($arch) {
        'X64' { return 'x64' }
        'X86' { return 'x86' }
        'Arm64' { return 'arm64' }
        'Arm' { return 'armv7l' }
        default { return $arch.ToString().ToLower() }
    }
}

# ==============================
# Section 9: Download & Checksum
# ==============================

function nvm_download {
    param(
        [string]$Url,
        [string]$OutputFile = '',
        [switch]$Silent,
        [string]$AuthHeader = ''
    )
    $headers = @{}
    if (-not [string]::IsNullOrEmpty($env:NVM_AUTH_HEADER)) {
        $sanitized = nvm_sanitize_auth_header $env:NVM_AUTH_HEADER
        $headers['Authorization'] = $sanitized
    }
    if (-not [string]::IsNullOrEmpty($AuthHeader)) {
        $headers['Authorization'] = $AuthHeader
    }

    $params = @{
        Uri = $Url
        UseBasicParsing = $true
        ErrorAction = 'Stop'
    }
    if ($headers.Count -gt 0) {
        $params['Headers'] = $headers
    }

    try {
        if (-not [string]::IsNullOrEmpty($OutputFile)) {
            Invoke-WebRequest @params -OutFile $OutputFile
            return $OutputFile
        } else {
            $response = Invoke-WebRequest @params
            return $response.Content
        }
    } catch {
        if (-not $Silent) {
            nvm_err "Download failed: $_"
        }
        return $null
    }
}

function nvm_sanitize_auth_header {
    param([string]$Header)
    return ($Header -replace '[^a-zA-Z0-9 :_.+/=\-]', '')
}

function nvm_get_latest {
    try {
        $response = Invoke-WebRequest -Uri 'https://latest.nvm.sh' -MaximumRedirection 0 -ErrorAction SilentlyContinue -SkipHttpErrorCheck
        $location = $response.Headers['Location']
        if ($null -eq $location) {
            # Follow redirect manually
            $response = Invoke-WebRequest -Uri 'https://latest.nvm.sh' -UseBasicParsing
            $finalUrl = $response.BaseResponse.RequestMessage.RequestUri.ToString()
            return ($finalUrl.Split('/')[-1])
        }
        if ($location -is [array]) { $location = $location[0] }
        return ($location.Split('/')[-1])
    } catch {
        nvm_err 'https://latest.nvm.sh did not redirect to the latest release on GitHub'
        return $null
    }
}

function nvm_compute_checksum {
    param([string]$FilePath)
    if ([string]::IsNullOrEmpty($FilePath) -or -not (Test-Path $FilePath)) {
        nvm_err 'Provided file to checksum does not exist.'
        return $null
    }
    nvm_err 'Computing checksum with Get-FileHash'
    $hash = (Get-FileHash $FilePath -Algorithm SHA256).Hash
    return $hash.ToLower()
}

function nvm_compare_checksum {
    param([string]$FilePath, [string]$ExpectedChecksum)
    if ([string]::IsNullOrEmpty($FilePath) -or -not (Test-Path $FilePath)) {
        nvm_err 'Provided file to checksum does not exist.'
        return $false
    }
    if ([string]::IsNullOrEmpty($ExpectedChecksum)) {
        nvm_err 'Provided checksum to compare to is empty.'
        return $false
    }

    $computed = nvm_compute_checksum $FilePath
    if ([string]::IsNullOrEmpty($computed)) {
        nvm_err "Computed checksum of '$FilePath' is empty."
        nvm_err 'WARNING: Continuing *without checksum verification*'
        return $true
    }

    if ($computed -ne $ExpectedChecksum.ToLower()) {
        nvm_err "Checksums do not match: '$computed' found, '$ExpectedChecksum' expected."
        return $false
    }
    nvm_err 'Checksums matched!'
    return $true
}

function nvm_get_checksum {
    param([string]$Flavor, [string]$Type, [string]$Version, [string]$Slug, [string]$Compression)
    $mirror = nvm_get_mirror $Flavor $Type
    if ([string]::IsNullOrEmpty($mirror)) { return $null }

    $shasumsUrl = "$mirror/$Version/SHASUMS256.txt"
    try {
        $content = nvm_download -Url $shasumsUrl -Silent
        if ($null -eq $content) { return $null }
        $targetName = "$Slug.$Compression"
        foreach ($line in ($content -split "`n")) {
            $parts = $line.Trim() -split '\s+'
            if ($parts.Count -ge 2 -and $parts[1] -eq $targetName) {
                return $parts[0].ToLower()
            }
        }
    } catch {
        return $null
    }
    return $null
}

function nvm_get_mirror {
    param([string]$Flavor, [string]$Type)
    $mirror = ''
    switch ("$Flavor-$Type") {
        'node-std' { $mirror = if ($env:NVM_NODEJS_ORG_MIRROR) { $env:NVM_NODEJS_ORG_MIRROR } else { 'https://nodejs.org/dist' } }
        'iojs-std' { $mirror = if ($env:NVM_IOJS_ORG_MIRROR) { $env:NVM_IOJS_ORG_MIRROR } else { 'https://iojs.org/dist' } }
        default {
            nvm_err 'unknown type of node.js or io.js release'
            return $null
        }
    }
    # Validate URL
    if ($mirror -match '[`\\''() ]') {
        nvm_err '$NVM_NODEJS_ORG_MIRROR and $NVM_IOJS_ORG_MIRROR may only contain a URL'
        return $null
    }
    if ($mirror -notmatch '^https?://[a-zA-Z0-9./_-]+$') {
        nvm_err '$NVM_NODEJS_ORG_MIRROR and $NVM_IOJS_ORG_MIRROR may only contain a URL'
        return $null
    }
    return $mirror
}

function nvm_ls_remote {
    param([string]$Pattern = '')
    $isValid = nvm_validate_implicit_alias $Pattern 2>$null
    if ($isValid) {
        $implicit = nvm_print_implicit_alias 'remote' $Pattern
        if ([string]::IsNullOrEmpty($implicit) -or $implicit -eq 'N/A') { return 'N/A' }
        $result = @(nvm_ls_remote $implicit) | Select-Object -Last 1
        return ($result -split '\s+')[0]
    }
    if (-not [string]::IsNullOrEmpty($Pattern)) {
        $Pattern = nvm_ensure_version_prefix $Pattern
    } else {
        $Pattern = '.*'
    }
    return (nvm_ls_remote_index_tab 'node' 'std' $Pattern)
}

function nvm_ls_remote_iojs {
    param([string]$Pattern = '')
    return (nvm_ls_remote_index_tab 'iojs' 'std' $Pattern)
}

function nvm_ls_remote_index_tab {
    param([string]$Flavor, [string]$Type, [string]$Pattern = '')
    $lts = $env:NVM_LTS_TEMP

    $mirror = nvm_get_mirror $Flavor $Type
    if ([string]::IsNullOrEmpty($mirror)) { return 'N/A' }

    $prefix = ''
    switch ("$Flavor-$Type") {
        'iojs-std' { $prefix = "$(nvm_iojs_prefix)-" }
        'node-std' { $prefix = '' }
        default { nvm_err 'unknown release type'; return 'N/A' }
    }

    if (-not [string]::IsNullOrEmpty($Pattern) -and $Pattern.EndsWith('.')) {
        $Pattern = $Pattern.TrimEnd('.')
    }

    # Download index.tab
    $indexUrl = "$mirror/index.tab"
    $indexContent = nvm_download -Url $indexUrl -Silent
    if ($null -eq $indexContent) { return 'N/A' }

    $lines = @($indexContent -split "`n" | Select-Object -Skip 1)  # skip header

    # Process version list and create LTS aliases
    $aliasDir = nvm_alias_path
    $ltsDir = Join-Path $aliasDir 'lts'
    if (-not (Test-Path $ltsDir)) { New-Item -ItemType Directory -Path $ltsDir -Force | Out-Null }

    $seenLts = @{}
    $firstLts = $true
    foreach ($rawLine in $lines) {
        $fields = $rawLine.Trim() -split '\t+'
        if ($fields.Count -lt 10) { continue }
        $ver = "$prefix$($fields[0])"
        $ltsName = $fields[9]
        if ($ltsName -match '^\-?$' -or [string]::IsNullOrEmpty($ltsName)) { continue }
        $ltsLower = $ltsName.ToLower()
        if ($ltsLower -notmatch '^[a-z0-9][a-z0-9._-]*$') { continue }

        if (-not $seenLts.ContainsKey($ltsLower)) {
            if ($firstLts) {
                nvm_make_alias "lts/*" "lts/$ltsLower" | Out-Null
                $firstLts = $false
            }
            nvm_make_alias "lts/$ltsLower" $ver | Out-Null
            $seenLts[$ltsLower] = $true
        }
    }

    # Normalize LTS filter
    if (-not [string]::IsNullOrEmpty($lts)) {
        $normalized = nvm_normalize_lts "lts/$lts"
        if ($null -eq $normalized) { return 'N/A' }
        $lts = $normalized -replace '^lts/', ''
    }

    # Build filtered version list
    if (-not [string]::IsNullOrEmpty($Pattern) -and $Pattern -ne '.*' -and $Pattern -ne '*') {
        if ($Flavor -eq 'iojs') {
            $Pattern = nvm_ensure_version_prefix (nvm_strip_iojs_prefix $Pattern)
        } else {
            $Pattern = nvm_ensure_version_prefix $Pattern
        }
    } else {
        $Pattern = ''
    }

    $versions = @()
    $prevLts = ''
    foreach ($rawLine in $lines) {
        $fields = $rawLine.Trim() -split '\t+'
        if ($fields.Count -lt 1 -or [string]::IsNullOrEmpty($fields[0])) { continue }

        $ver = "$prefix$($fields[0])"
        $ltsName = if ($fields.Count -ge 10) { $fields[9] } else { '-' }
        $ltsLower = $ltsName.ToLower()

        # Apply LTS filter
        if (-not [string]::IsNullOrEmpty($lts)) {
            if ($ltsName -match '^\-?$') { continue }
            if ($lts -ne '*' -and $ltsLower -ne $lts.ToLower()) { continue }
        }

        # Apply pattern filter
        if (-not [string]::IsNullOrEmpty($Pattern)) {
            if ($ver -notmatch [regex]::Escape($Pattern)) { continue }
        }

        # Build output line
        $outputLine = $ver
        if ($ltsName -notmatch '^\-?$' -and -not [string]::IsNullOrEmpty($ltsName)) {
            if ($ltsLower -ne $prevLts) {
                $outputLine = "$ver $ltsName *"
                $prevLts = $ltsLower
            } else {
                $outputLine = "$ver $ltsName"
            }
        }
        $versions += $outputLine
    }

    # Sort node versions
    if ($Flavor -eq 'node') {
        $versions = @($versions | Sort-Object {
            $v = ($_ -split '\s+')[0].TrimStart('v')
            $parts = $v.Split('.')
            $major = if ($parts.Count -ge 1 -and $parts[0] -match '^\d+$') { [int]$parts[0] } else { 0 }
            $minor = if ($parts.Count -ge 2 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 0 }
            $patch = if ($parts.Count -ge 3 -and $parts[2] -match '^\d+$') { [int]$parts[2] } else { 0 }
            $major * 1000000 + $minor * 1000 + $patch
        })
    }

    if ($versions.Count -eq 0) { return 'N/A' }
    return $versions
}

# ============================
# Section 10: Installation
# ============================

function nvm_binary_available {
    param([string]$Version)
    $stripped = nvm_strip_iojs_prefix $Version
    return (nvm_version_greater_than_or_equal_to $stripped 'v0.8.6')
}

function nvm_is_merged_node_version {
    param([string]$Version)
    return (nvm_version_greater_than_or_equal_to $Version 'v4.0.0')
}

function nvm_get_download_slug {
    param([string]$Flavor, [string]$Kind, [string]$Version)
    $nvmOS = nvm_get_os
    $nvmArch = nvm_get_arch

    if ($Kind -eq 'binary') {
        return "$Flavor-$Version-$nvmOS-$nvmArch"
    } elseif ($Kind -eq 'source') {
        return "$Flavor-$Version"
    }
    return ''
}

function nvm_get_artifact_compression {
    param([string]$Version = '')
    return 'zip'  # Always zip on Windows
}

function nvm_download_artifact {
    param([string]$Flavor, [string]$Kind, [string]$Type, [string]$Version)
    $mirror = nvm_get_mirror $Flavor $Type
    if ([string]::IsNullOrEmpty($mirror)) { return $null }

    if ([string]::IsNullOrEmpty($Version)) {
        nvm_err 'A version number is required.'
        return $null
    }
    if ($Version -match '[^0-9A-Za-z._+\-]') {
        nvm_err 'Invalid version: contains disallowed characters'
        return $null
    }

    if ($Kind -eq 'binary' -and -not (nvm_binary_available $Version)) {
        nvm_err "No precompiled binary available for $Version."
        return $null
    }

    $slug = nvm_get_download_slug $Flavor $Kind $Version
    $compression = nvm_get_artifact_compression $Version

    $cacheBase = nvm_cache_dir
    $subdir = if ($Kind -eq 'binary') { 'bin' } else { 'src' }
    $tmpdir = Join-Path $cacheBase $subdir $slug
    $tarball = Join-Path $tmpdir "$slug.$compression"

    # Offline mode
    if ($env:NVM_OFFLINE -eq '1') {
        if (Test-Path $tarball) {
            nvm_err "Offline: using cached archive $(nvm_sanitize_path $tarball)"
            return $tarball
        }
        nvm_err "Offline: no cached archive found for $slug"
        return $null
    }

    $checksum = nvm_get_checksum $Flavor $Type $Version $slug $compression

    if (-not (Test-Path $tmpdir)) {
        New-Item -ItemType Directory -Path $tmpdir -Force | Out-Null
    }
    $filesDir = Join-Path $tmpdir 'files'
    if (-not (Test-Path $filesDir)) {
        New-Item -ItemType Directory -Path $filesDir -Force | Out-Null
    }

    $tarballUrl = "$mirror/$Version/$slug.$compression"

    # Check cached file
    if (Test-Path $tarball) {
        nvm_err "Local cache found: $(nvm_sanitize_path $tarball)"
        $isMatch = nvm_compare_checksum $tarball $checksum 2>$null
        if ($isMatch) {
            nvm_err "Checksums match! Using existing downloaded archive $(nvm_sanitize_path $tarball)"
            return $tarball
        }
        nvm_err 'Checksum check failed!'
        nvm_err 'Removing the broken local cache...'
        Remove-Item $tarball -Force -ErrorAction SilentlyContinue
    }

    nvm_err "Downloading $tarballUrl..."
    $result = nvm_download -Url $tarballUrl -OutputFile $tarball
    if ($null -eq $result -or -not (Test-Path $tarball)) {
        Remove-Item $tarball -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpdir -Recurse -Force -ErrorAction SilentlyContinue
        nvm_err "download from $tarballUrl failed"
        return $null
    }

    # Check for 404
    $content = Get-Content $tarball -Raw -ErrorAction SilentlyContinue
    if ($content -match '404 Not Found') {
        Remove-Item $tarball -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpdir -Recurse -Force -ErrorAction SilentlyContinue
        nvm_err "HTTP 404 at URL $tarballUrl"
        return $null
    }

    if (-not (nvm_compare_checksum $tarball $checksum)) {
        $filesPath = Join-Path $tmpdir 'files'
        Remove-Item $filesPath -Recurse -Force -ErrorAction SilentlyContinue
        return $null
    }

    return $tarball
}

function nvm_install_binary_extract {
    param([string]$NvmOS, [string]$PrefixedVersion, [string]$Version, [string]$Tarball, [string]$TmpDir)

    if (-not (Test-Path $Tarball)) { return $false }

    $versionPath = nvm_version_path $PrefixedVersion
    if ([string]::IsNullOrEmpty($versionPath)) { return $false }

    if (-not (Test-Path $TmpDir)) {
        New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
    }

    try {
        # Extract zip
        Expand-Archive -Path $Tarball -DestinationPath $TmpDir -Force

        # Remove existing version directory
        if (Test-Path $versionPath) {
            Remove-Item $versionPath -Recurse -Force
        }

        # Create version directory
        $parentDir = Split-Path $versionPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        # Find the extracted directory (node-vX.Y.Z-win-x64)
        $extractedDirs = @(Get-ChildItem $TmpDir -Directory)
        if ($extractedDirs.Count -eq 0) {
            nvm_err 'Extraction produced no directories'
            return $false
        }
        $extractedDir = $extractedDirs[0].FullName

        # Move extracted directory to version path
        Move-Item -Path $extractedDir -Destination $versionPath -Force

        # Clean up tmp
        Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue

        return $true
    } catch {
        nvm_err "Extraction failed: $_"
        return $false
    }
}

function nvm_install_binary {
    param([string]$Flavor, [string]$Type, [string]$PrefixedVersion, [string]$NoSource = '0')

    $version = nvm_strip_iojs_prefix $PrefixedVersion
    $nvmOS = nvm_get_os

    $nodeOrIojs = if ($Flavor -eq 'node') { 'node' } else { 'io.js' }
    nvm_echo "Downloading and installing $nodeOrIojs $version..."

    $tarball = nvm_download_artifact $Flavor 'binary' $Type $version
    if ([string]::IsNullOrEmpty($tarball) -or -not (Test-Path $tarball)) {
        if ($NoSource -eq '1') {
            nvm_err 'Binary download failed. Download from source aborted.'
            return $false
        }
        nvm_err 'Binary download failed.'
        return $false
    }

    $tmpdir = Join-Path (Split-Path $tarball -Parent) 'files'

    if (nvm_install_binary_extract $nvmOS $PrefixedVersion $version $tarball $tmpdir) {
        return $true
    }

    if ($NoSource -eq '1') {
        nvm_err 'Binary download failed. Download from source aborted.'
        return $false
    }
    nvm_err 'Binary extraction failed.'
    return $false
}

function nvm_install_source {
    param([string]$Flavor, [string]$Type, [string]$PrefixedVersion, [string]$MakeJobs = '', [string]$AdditionalParams = '')
    nvm_err 'Installing from source on Windows is not supported.'
    nvm_err 'Please use binary installation (the default).'
    return $false
}

function nvm_install_npm_if_needed {
    param([string]$Version)
    if (-not (nvm_has 'npm')) {
        nvm_echo 'npm should be bundled with node on Windows.'
        return $false
    }
    return $true
}

function nvm_use_if_needed {
    param([string]$Version)
    if ($Version -eq (nvm_ls_current)) { return $true }
    nvm 'use' $Version
    return $?
}

function nvm_install_lock_name {
    param([string]$Version)
    return ($Version -replace '[^0-9A-Za-z._+\-]', '_')
}

function nvm_acquire_install_lock {
    param([string]$Version)
    if ([string]::IsNullOrEmpty($Version)) { return $true }

    $lockRoot = Join-Path (nvm_cache_dir) 'locks'
    if (-not (Test-Path $lockRoot)) {
        New-Item -ItemType Directory -Path $lockRoot -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $lockName = nvm_install_lock_name $Version
    $lockPath = Join-Path $lockRoot $lockName

    $timeout = if ($env:NVM_INSTALL_LOCK_TIMEOUT) { [int]$env:NVM_INSTALL_LOCK_TIMEOUT } else { 600 }
    $waited = 0
    $announced = $false

    while (Test-Path $lockPath) {
        if ($waited -ge $timeout) {
            nvm_err "Timed out after ${timeout}s waiting for another install of $Version to finish."
            nvm_err "If no other install is running, remove $lockPath and try again."
            return $false
        }
        if (-not $announced) {
            nvm_err "Waiting for another install of $Version to finish..."
            $announced = $true
        }
        Start-Sleep -Seconds 1
        $waited++
    }

    New-Item -ItemType Directory -Path $lockPath -Force | Out-Null
    $script:NVM_INSTALL_LOCK = $lockPath
    return $true
}

function nvm_release_install_lock {
    if (-not [string]::IsNullOrEmpty($script:NVM_INSTALL_LOCK)) {
        Remove-Item $script:NVM_INSTALL_LOCK -Recurse -Force -ErrorAction SilentlyContinue
        $script:NVM_INSTALL_LOCK = $null
    }
}

function nvm_ensure_version_installed {
    param([string]$ProvidedVersion, [string]$IsFromNvmrc = '0')
    if ($ProvidedVersion -eq 'system') {
        if ((nvm_has_system_node) -or (nvm_has_system_iojs)) { return $true }
        nvm_err 'N/A: no system version of node/io.js is installed.'
        return $false
    }

    $localVersion = nvm_version $ProvidedVersion
    if ($localVersion -eq 'N/A' -or -not (nvm_is_version_installed $localVersion)) {
        $resolved = nvm_resolve_alias $ProvidedVersion 2>$null
        if (-not [string]::IsNullOrEmpty($resolved)) {
            nvm_err "N/A: version `"$ProvidedVersion -> $resolved`" is not yet installed."
        } else {
            $prefixed = nvm_ensure_version_prefix $ProvidedVersion
            if ([string]::IsNullOrEmpty($prefixed)) { $prefixed = $ProvidedVersion }
            nvm_err "N/A: version `"$prefixed`" is not yet installed."
        }
        nvm_err ''
        if ($ProvidedVersion -eq 'lts') {
            nvm_err '`lts` is not an alias - you may need to run `nvm install --lts` to install and `nvm use --lts` to use it.'
        } elseif ($IsFromNvmrc -ne '1') {
            nvm_err "You need to run ``nvm install $ProvidedVersion`` to install and use it."
        } else {
            nvm_err 'You need to run `nvm install` to install and use the node version specified in `.nvmrc`.'
        }
        return $false
    }
    return $true
}

# =======================================
# Section 11: npm config & default pkgs
# =======================================

function nvm_npmrc_bad_news_bears {
    param([string]$NpmrcPath)
    if (-not [string]::IsNullOrEmpty($NpmrcPath) -and (Test-Path $NpmrcPath -PathType Leaf)) {
        $content = Get-Content $NpmrcPath -Raw -ErrorAction SilentlyContinue
        if ($content -match '(?m)^(prefix|globalconfig)\s*=') {
            return $true
        }
    }
    return $false
}

function nvm_die_on_prefix {
    param([string]$DeletePrefix, [string]$NvmCommand, [string]$NvmVersionDir)
    if ([string]::IsNullOrEmpty($NvmCommand) -or [string]::IsNullOrEmpty($NvmVersionDir)) {
        nvm_err 'Second argument "nvm command", and third argument "nvm version dir", must both be nonempty'
        return $false
    }

    # Check PREFIX env var
    if (-not [string]::IsNullOrEmpty($env:PREFIX)) {
        $currentNodeVersion = & node -v 2>$null
        $currentPath = nvm_version_path $currentNodeVersion
        if ($currentPath -ne $env:PREFIX) {
            nvm 'deactivate' 2>$null
            nvm_err "nvm is not compatible with the `"PREFIX`" environment variable: currently set to `"$($env:PREFIX)`""
            nvm_err 'Run `$env:PREFIX = $null` to unset it.'
            return $false
        }
    }

    # Check NPM_CONFIG_PREFIX
    if (-not [string]::IsNullOrEmpty($env:NPM_CONFIG_PREFIX)) {
        if (-not (nvm_tree_contains_path $env:NVM_DIR $env:NPM_CONFIG_PREFIX)) {
            nvm 'deactivate' 2>$null
            nvm_err "nvm is not compatible with the `"NPM_CONFIG_PREFIX`" environment variable: currently set to `"$($env:NPM_CONFIG_PREFIX)`""
            nvm_err 'Run `$env:NPM_CONFIG_PREFIX = $null` to unset it.'
            return $false
        }
    }

    # Check npmrc files
    $npmrcLocations = @(
        (Join-Path $NvmVersionDir 'node_modules' 'npm' 'npmrc'),
        (Join-Path $NvmVersionDir 'etc' 'npmrc'),
        (Join-Path $env:USERPROFILE '.npmrc'),
        (Join-Path (nvm_find_project_dir) '.npmrc')
    )

    foreach ($npmrc in $npmrcLocations) {
        if (nvm_npmrc_bad_news_bears $npmrc) {
            if ($DeletePrefix -eq '1') {
                & npm config --loglevel=warn delete prefix 2>$null
                & npm config --loglevel=warn delete globalconfig 2>$null
            } else {
                nvm_err "Your npmrc file ($(nvm_sanitize_path $npmrc))"
                nvm_err 'has a `globalconfig` and/or a `prefix` setting, which are incompatible with nvm.'
                nvm_err "Run ``$NvmCommand`` to unset it."
                return $false
            }
        }
    }
    return $true
}

function nvm_npm_global_modules {
    param([string]$Version)
    $oldSilent = $env:NVM_SILENT
    $env:NVM_SILENT = '1'
    nvm 'use' $Version
    $env:NVM_SILENT = $oldSilent

    $npmList = & npm list -g --depth=0 2>$null
    if ($null -eq $npmList) { return ' //// ' }

    $lines = $npmList -split "`n" | Select-Object -Skip 1
    $installs = @()
    $links = @()
    foreach ($line in $lines) {
        if ($line -match 'UNMET PEER DEPENDENCY') { continue }
        if ($line -match ' -> ') {
            if ($line -match ' -> (.+)$') { $links += $Matches[1].Trim() }
        } elseif ($line -match '(empty)') {
            continue
        } elseif ($line -match '\s(.+@[^\s]+)') {
            $pkg = $Matches[1].Trim()
            if ($pkg -notmatch '^npm@' -and $pkg -notmatch '^corepack@') {
                $installs += $pkg
            }
        }
    }
    return "$($installs -join ' ') //// $($links -join ' ')"
}

function nvm_get_default_packages {
    $pkgFile = Join-Path $env:NVM_DIR 'default-packages'
    if (-not (Test-Path $pkgFile)) { return '' }

    $packages = @()
    foreach ($line in (Get-Content $pkgFile)) {
        $line = $line.Trim()
        if ($line.StartsWith('#') -or [string]::IsNullOrEmpty($line)) { continue }
        if ($line -match '\s') {
            nvm_err "Only one package per line is allowed in ``$pkgFile``. Please remove any lines with multiple space-separated values."
            return $null
        }
        $packages += $line
    }
    return ($packages -join ' ')
}

function nvm_install_default_packages {
    $packages = nvm_get_default_packages
    if ($null -eq $packages -or [string]::IsNullOrEmpty($packages)) { return }

    nvm_echo "Installing default global packages from $env:NVM_DIR\default-packages..."
    nvm_echo "npm install -g --quiet $packages"
    $pkgList = $packages -split ' '
    & npm install -g --quiet @pkgList 2>&1 | ForEach-Object { nvm_echo $_ }
}

function nvm_install_latest_npm {
    nvm_echo 'Attempting to upgrade to the latest working version of npm...'
    $nodeVersion = (nvm_strip_iojs_prefix (nvm_ls_current)).TrimStart('v')
    $npmVersion = & npm --version 2>$null

    if ($nodeVersion -eq 'system') {
        $nodeVersion = (& node --version 2>$null).TrimStart('v')
    } elseif ($nodeVersion -eq 'none') {
        nvm_echo "Detected node version $nodeVersion, npm version v$npmVersion"
        $nodeVersion = ''
    }
    if ([string]::IsNullOrEmpty($nodeVersion)) {
        nvm_err 'Unable to obtain node version.'
        return $false
    }
    if ([string]::IsNullOrEmpty($npmVersion)) {
        nvm_err 'Unable to obtain npm version.'
        return $false
    }

    # Version matrix (1:1 from nvm.sh)
    $nv = $nodeVersion  # shorthand
    if ((nvm_version_greater_than_or_equal_to $nv '0.6.0') -and (nvm_version_greater '0.7.0' $nv)) {
        nvm_echo '* `node` v0.6.x can only upgrade to `npm` v1.3.x'
        & npm install -g npm@1.3
    } elseif ((nvm_version_greater_than_or_equal_to $nv '0.9.0') -and (nvm_version_greater '0.10.0' $nv)) {
        nvm_echo '* node v0.6 and v0.9 are unable to upgrade further'
    } elseif (nvm_version_greater '1.1.0' $nv) {
        nvm_echo '* `npm` v4.5.x is the last version that works on `node` versions < v1.1.0'
        & npm install -g npm@4.5
    } elseif (nvm_version_greater '4.0.0' $nv) {
        nvm_echo '* `npm` v5 and higher do not work on `node` versions below v4.0.0'
        & npm install -g npm@4
    } elseif (nvm_version_greater '4.7.0' $nv) {
        & npm install -g npm@5.4.1
    } elseif (nvm_version_greater '6.0.0' $nv) {
        & npm install -g npm@5
    } elseif (nvm_version_greater '6.2.0' $nv) {
        & npm install -g npm@6.9
    } elseif (nvm_version_greater '10.0.0' $nv) {
        & npm install -g npm@6
    } elseif (nvm_version_greater '12.13.0' $nv) {
        & npm install -g npm@7
    } elseif (nvm_version_greater '16.0.0' $nv) {
        & npm install -g npm@8.6
    } elseif (nvm_version_greater '18.17.0' $nv) {
        & npm install -g npm@9
    } elseif (nvm_version_greater '20.17.0' $nv) {
        & npm install -g npm@10
    } else {
        nvm_echo '* Installing latest `npm`; if this does not work on your node version, please report a bug!'
        & npm install -g npm
    }
    $newNpm = & npm --version 2>$null
    nvm_echo "* npm upgraded to: v$newNpm"
}

# ==========================
# Section 12: io.js Support
# ==========================

function nvm_iojs_prefix { return 'iojs' }
function nvm_node_prefix { return 'node' }

function nvm_is_iojs_version {
    param([string]$Version)
    return ($Version -like 'iojs-*')
}

function nvm_add_iojs_prefix {
    param([string]$Version)
    $stripped = nvm_strip_iojs_prefix $Version
    $prefixed = nvm_ensure_version_prefix $stripped
    return "$(nvm_iojs_prefix)-$prefixed"
}

function nvm_strip_iojs_prefix {
    param([string]$Version)
    $iojsPrefix = nvm_iojs_prefix
    if ($Version -eq $iojsPrefix) { return '' }
    if ($Version.StartsWith("$iojsPrefix-")) {
        return $Version.Substring($iojsPrefix.Length + 1)
    }
    return $Version
}

# =========================
# Section 13: Cached / Offline
# =========================

function nvm_ls_cached {
    param([string]$Pattern = '')
    $cacheDir = nvm_cache_dir
    $nvmOS = nvm_get_os
    $nvmArch = nvm_get_arch
    $suffix = "$nvmOS-$nvmArch"

    $versions = @()
    $binDir = Join-Path $cacheDir 'bin'
    if (Test-Path $binDir) {
        Get-ChildItem $binDir -Directory | ForEach-Object {
            if ($_.Name -match "^(node|iojs)-v[\d.]+-$([regex]::Escape($suffix))$") {
                $ver = $_.Name -replace "-$([regex]::Escape($suffix))$", '' -replace '^node-', ''
                $versions += $ver
            }
        }
    }
    $srcDir = Join-Path $cacheDir 'src'
    if (Test-Path $srcDir) {
        Get-ChildItem $srcDir -Directory | ForEach-Object {
            if ($_.Name -match '^(node|iojs)-v[\d.]+$') {
                $ver = $_.Name -replace '^node-', ''
                $versions += $ver
            }
        }
    }

    if (-not [string]::IsNullOrEmpty($Pattern)) {
        $prefix = nvm_ensure_version_prefix $Pattern
        $versions = $versions | Where-Object { $_ -match [regex]::Escape($prefix) }
    }

    $versions = $versions | Sort-Object -Unique {
        $v = $_.TrimStart('v').TrimStart("$(nvm_iojs_prefix)-v")
        $parts = $v.Split('.')
        $major = if ($parts.Count -ge 1 -and $parts[0] -match '^\d+$') { [int]$parts[0] } else { 0 }
        $minor = if ($parts.Count -ge 2 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 0 }
        $patch = if ($parts.Count -ge 3 -and $parts[2] -match '^\d+$') { [int]$parts[2] } else { 0 }
        $major * 1000000 + $minor * 1000 + $patch
    }
    return $versions
}

function nvm_offline_version {
    param([string]$Pattern)
    # Try installed
    $version = nvm_version $Pattern
    if ($version -ne 'N/A') { return $version }
    # Try cached
    $version = @(nvm_ls_cached $Pattern) | Select-Object -Last 1
    if (-not [string]::IsNullOrEmpty($version)) { return $version }
    return 'N/A'
}

# ================================
# Section 14: Main nvm Dispatcher
# ================================

function nvm {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Command,
        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    if ([string]::IsNullOrEmpty($Command)) {
        nvm 'help'
        return
    }
    if ($null -eq $Arguments) { $Arguments = @() }

    # Check for help anywhere in args
    if ($Command -in @('-h', 'help', '--help') -or '--help' -in $Arguments -or '-h' -in $Arguments) {
        $iojsPrefix = nvm_iojs_prefix
        $nodePrefix = nvm_node_prefix
        $nvmVersion = '0.40.7'

        nvm_echo ''
        nvm_echo "Node Version Manager (v$nvmVersion) for PowerShell"
        nvm_echo ''
        nvm_echo 'Note: <version> refers to any version-like string nvm understands. This includes:'
        nvm_echo '  - full or partial version numbers, starting with an optional "v" (0.10, v0.1.2, v1)'
        nvm_echo "  - default (built-in) aliases: $nodePrefix, stable, unstable, $iojsPrefix, system"
        nvm_echo '  - custom aliases you define with `nvm alias foo`'
        nvm_echo ''
        nvm_echo ' Any options that produce colorized output should respect the `--no-colors` option.'
        nvm_echo ''
        nvm_echo 'Usage:'
        nvm_echo '  nvm --help                                  Show this message'
        nvm_echo '    --no-colors                               Suppress colored output'
        nvm_echo '  nvm --version                               Print out the installed version of nvm'
        nvm_echo '  nvm install [<version>]                     Download and install a <version>. Uses .nvmrc if version is omitted.'
        nvm_echo '   The following optional arguments, if provided, must appear directly after `nvm install`:'
        nvm_echo '    -b                                        Skip source download, install from binary only.'
        nvm_echo '    --reinstall-packages-from=<version>       When installing, reinstall packages installed in <version>'
        nvm_echo '    --lts                                     When installing, only select from LTS (long-term support) versions'
        nvm_echo '    --lts=<LTS name>                          When installing, only select from versions for a specific LTS line'
        nvm_echo '    --skip-default-packages                   When installing, skip the default-packages file if it exists'
        nvm_echo '    --latest-npm                              After installing, attempt to upgrade to the latest working npm'
        nvm_echo '    --no-progress                             Disable the progress bar on any downloads'
        nvm_echo '    --offline                                 Install from cache only, without downloading anything'
        nvm_echo '    --alias=<name>                            After installing, set the alias specified to the version specified'
        nvm_echo '    --default                                 After installing, set default alias to the version specified'
        nvm_echo '    --save                                    After installing, write the specified version to .nvmrc'
        nvm_echo '  nvm uninstall <version>                     Uninstall a version'
        nvm_echo '  nvm uninstall --lts                         Uninstall using automatic LTS alias `lts/*`, if available.'
        nvm_echo '  nvm uninstall --lts=<LTS name>              Uninstall using automatic alias for provided LTS line.'
        nvm_echo '  nvm use [current | <version>]               Modify PATH to use <version>. Uses .nvmrc if version is omitted.'
        nvm_echo '    --silent                                  Silences stdout/stderr output'
        nvm_echo '    --lts                                     Uses automatic LTS alias `lts/*`, if available.'
        nvm_echo '    --lts=<LTS name>                          Uses automatic alias for provided LTS line.'
        nvm_echo '    --save                                    Writes the specified version to .nvmrc.'
        nvm_echo '  nvm exec [current | <version>] [<command>]  Run <command> on <version>. Uses .nvmrc if version is omitted.'
        nvm_echo '    --silent                                  Silences stdout/stderr output'
        nvm_echo '    --lts                                     Uses automatic LTS alias `lts/*`, if available.'
        nvm_echo '  nvm run [current | <version>] [<args>]      Run `node` on <version> with <args> as arguments.'
        nvm_echo '    --silent                                  Silences stdout/stderr output'
        nvm_echo '    --lts                                     Uses automatic LTS alias `lts/*`, if available.'
        nvm_echo '  nvm current                                 Display the active node version.'
        nvm_echo '  nvm ls [<version>]                          List installed versions, matching a given <version> if provided'
        nvm_echo '    --no-colors                               Suppress colored output'
        nvm_echo '    --no-alias                                Suppress `nvm alias` output'
        nvm_echo '  nvm ls-remote [<version>]                   List remote versions available for install'
        nvm_echo '    --lts                                     When listing, only show LTS (long-term support) versions'
        nvm_echo '    --no-colors                               Suppress colored output'
        nvm_echo '  nvm version <version>                       Resolve the given description to a single local version'
        nvm_echo '  nvm version-remote <version>                Resolve the given description to a single remote version'
        nvm_echo '    --lts                                     When listing, only select from LTS versions'
        nvm_echo '  nvm deactivate                              Undo effects of `nvm` on current shell'
        nvm_echo '    --silent                                  Silences stdout/stderr output'
        nvm_echo '  nvm alias [<pattern>]                       Show all aliases beginning with <pattern>'
        nvm_echo '    --no-colors                               Suppress colored output'
        nvm_echo '  nvm alias <name> <version>                  Set an alias named <name> pointing to <version>'
        nvm_echo '  nvm unalias <name>                          Deletes the alias named <name>'
        nvm_echo '  nvm install-latest-npm                      Attempt to upgrade to the latest working `npm` on the current node version'
        nvm_echo '  nvm reinstall-packages <version>            Reinstall global `npm` packages contained in <version> to current version'
        nvm_echo '  nvm unload                                  Unload `nvm` from shell'
        nvm_echo '  nvm which [current | <version>]             Display path to installed node version.'
        nvm_echo '    --silent                                  Silences stdout/stderr output when a version is omitted'
        nvm_echo '  nvm cache dir                               Display path to the cache directory for nvm'
        nvm_echo '  nvm cache clear                             Empty cache directory for nvm'
        nvm_echo '  nvm set-colors [<color codes>]              Set five text colors using format "yMeBg".'
        nvm_echo ''
        nvm_echo 'Example:'
        nvm_echo '  nvm install 8.0.0                     Install a specific version number'
        nvm_echo '  nvm use 8.0                           Use the latest available 8.0.x release'
        nvm_echo '  nvm run 6.10.3 app.js                 Run app.js using node 6.10.3'
        nvm_echo '  nvm exec 4.8.3 node app.js            Run `node app.js` with the PATH pointing to node 4.8.3'
        nvm_echo '  nvm alias default 8.1.0               Set default node version on a shell'
        nvm_echo '  nvm alias default node                Always default to the latest available node version on a shell'
        nvm_echo ''
        nvm_echo '  nvm install node                      Install the latest available version'
        nvm_echo '  nvm use node                          Use the latest version'
        nvm_echo '  nvm install --lts                     Install the latest LTS version'
        nvm_echo '  nvm use --lts                         Use the latest LTS version'
        nvm_echo ''
        nvm_echo 'Note:'
        nvm_echo '  to remove, delete, or uninstall nvm - just remove the `$NVM_DIR` folder (usually `~\.nvm`)'
        nvm_echo ''
        return
    }

    switch -Regex ($Command) {
        '^version$|^-v$' {
            nvm_echo '0.40.7'
        }

        'cache' {
            if ($Arguments.Count -eq 0) {
                nvm_err 'Usage: nvm cache dir'
                nvm_err '       nvm cache clear'
                return
            }
            switch ($Arguments[0]) {
                'dir' { nvm_echo (nvm_cache_dir) }
                'clear' {
                    $dir = nvm_cache_dir
                    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                    nvm_echo 'nvm cache cleared.'
                }
                default {
                    nvm_err 'Usage: nvm cache dir'
                    nvm_err '       nvm cache clear'
                }
            }
        }

        'debug' {
            nvm_err "nvm --version: v$(nvm '--version')"
            nvm_err "`$SHELL: PowerShell $($PSVersionTable.PSVersion)"
            nvm_err "whoami: '$([Environment]::UserName)'"
            nvm_err "`${HOME}: $($env:USERPROFILE)"
            nvm_err "`${NVM_DIR}: '$(nvm_sanitize_path $env:NVM_DIR)'"
            nvm_err "`${PATH}: $(nvm_sanitize_path $env:PATH)"
            nvm_err "`$PREFIX: '$($env:PREFIX)'"
            nvm_err "`${NPM_CONFIG_PREFIX}: '$($env:NPM_CONFIG_PREFIX)'"
            nvm_err "`$NVM_NODEJS_ORG_MIRROR: '$($env:NVM_NODEJS_ORG_MIRROR)'"
            nvm_err "`$NVM_IOJS_ORG_MIRROR: '$($env:NVM_IOJS_ORG_MIRROR)'"
            nvm_err "OS: $([Environment]::OSVersion.VersionString)"
            nvm_err "Architecture: $(nvm_get_arch)"
            nvm_err "PowerShell: $($PSVersionTable.PSVersion)"

            foreach ($cmd in @('node', 'npm', 'git', 'curl')) {
                $c = Get-Command $cmd -ErrorAction SilentlyContinue
                if ($c) {
                    nvm_err "${cmd}: $($c.Source)"
                } else {
                    nvm_err "${cmd}: not found"
                }
            }

            $current = nvm_ls_current
            nvm_err "nvm current: $current"
            $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
            if ($nodeCmd) { nvm_err "which node: $($nodeCmd.Source)" } else { nvm_err 'which node: not found' }
            $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
            if ($npmCmd) { nvm_err "which npm: $($npmCmd.Source)" } else { nvm_err 'which npm: not found' }
            try {
                $npmPrefix = & npm config get prefix 2>$null
                nvm_err "npm config get prefix: $(nvm_sanitize_path $npmPrefix)"
            } catch {}
        }

        '^install$|^i$' {
            $versionNotProvided = ($Arguments.Count -eq 0)
            $nobinary = $false
            $nosource = $true  # Windows: always binary
            $noprogress = $false
            $nvmOffline = $false
            $lts = ''
            $installAlias = ''
            $upgradeNpm = $false
            $writeNvmrc = $false
            $skipDefaultPackages = $false
            $reinstallFrom = ''
            $providedReinstallFrom = ''

            # Parse arguments
            $remaining = @()
            $i = 0
            while ($i -lt $Arguments.Count) {
                $arg = $Arguments[$i]
                switch -Regex ($arg) {
                    '^---' { nvm_err 'arguments with `---` are not supported - this is likely a typo'; return }
                    '^-s$' { nvm_err 'Installing from source (-s) is not supported on Windows.'; return }
                    '^-b$' { $nosource = $true }
                    '^--no-progress$' { $noprogress = $true }
                    '^--offline$' { $nvmOffline = $true }
                    '^--lts$' { $lts = '*' }
                    '^--lts=(.+)$' { $lts = $Matches[1] }
                    '^--latest-npm$' { $upgradeNpm = $true }
                    '^--default$' {
                        if (-not [string]::IsNullOrEmpty($installAlias)) {
                            nvm_err '--default and --alias are mutually exclusive'
                            return
                        }
                        $installAlias = 'default'
                    }
                    '^--alias=(.+)$' {
                        if (-not [string]::IsNullOrEmpty($installAlias)) {
                            nvm_err '--default and --alias are mutually exclusive'
                            return
                        }
                        $installAlias = $Matches[1]
                    }
                    '^--reinstall-packages-from=(.+)$' {
                        $providedReinstallFrom = $Matches[1]
                        $reinstallFrom = nvm_version $providedReinstallFrom 2>$null
                    }
                    '^--copy-packages-from=(.+)$' {
                        $providedReinstallFrom = $Matches[1]
                        $reinstallFrom = nvm_version $providedReinstallFrom 2>$null
                    }
                    '^--skip-default-packages$' { $skipDefaultPackages = $true }
                    '^--(save|w)$' { $writeNvmrc = $true }
                    '^--save$' { $writeNvmrc = $true }
                    '^-w$' { $writeNvmrc = $true }
                    default { $remaining += $arg }
                }
                $i++
            }

            $providedVersion = if ($remaining.Count -gt 0) { $remaining[0] } else { '' }
            $additionalParams = if ($remaining.Count -gt 1) { $remaining[1..($remaining.Count - 1)] } else { @() }
            [void]$nobinary; [void]$nosource; [void]$additionalParams

            if ([string]::IsNullOrEmpty($providedVersion)) {
                if ($lts -eq '*') {
                    nvm_echo 'Installing latest LTS version.'
                } elseif (-not [string]::IsNullOrEmpty($lts)) {
                    nvm_echo "Installing with latest version of LTS line: $lts"
                } else {
                    $providedVersion = nvm_rc_version
                    if ($versionNotProvided -and [string]::IsNullOrEmpty($providedVersion)) {
                        nvm_err 'Usage: nvm install [<version>]'
                        nvm_err '  Provide a <version>, or run from a directory containing an .nvmrc file.'
                        return
                    }
                }
            }

            # Handle lts/ patterns
            if ($providedVersion -eq 'lts/*') { $lts = '*'; $providedVersion = '' }
            elseif ($providedVersion -match '^lts/(.+)$') { $lts = $Matches[1]; $providedVersion = '' }

            # Resolve version
            $version = 'N/A'
            if ($nvmOffline) {
                $offlinePattern = $providedVersion
                if (-not [string]::IsNullOrEmpty($lts)) {
                    if ($lts -eq '*') { $offlinePattern = nvm_resolve_alias 'lts/*' 2>$null }
                    else { $offlinePattern = nvm_resolve_alias "lts/$lts" 2>$null }
                    if ([string]::IsNullOrEmpty($offlinePattern)) {
                        nvm_err "LTS alias '$lts' not found locally. Run ``nvm ls-remote --lts`` first to populate LTS aliases."
                        return
                    }
                }
                $version = nvm_offline_version $offlinePattern
            } else {
                $env:NVM_VERSION_ONLY = 'true'
                $env:NVM_LTS_TEMP = $lts
                $version = nvm_remote_version $providedVersion
                $env:NVM_VERSION_ONLY = $null
                $env:NVM_LTS_TEMP = $null
            }

            if ($version -eq 'N/A') {
                $ltsMsg = ''
                if ($lts -eq '*') { $ltsMsg = '(with LTS filter) ' }
                elseif (-not [string]::IsNullOrEmpty($lts)) { $ltsMsg = "(with LTS filter '$lts') " }
                nvm_err "Version '$providedVersion' ${ltsMsg}not found - try ``nvm ls-remote`` to browse available versions."
                return
            }

            # Check if already installed
            if ((nvm_is_version_installed $version) -and (nvm_validate_install $version)) {
                nvm_err "$version is already installed."
                nvm 'use' $version
                if ($upgradeNpm) { nvm 'install-latest-npm' }
                if (-not $skipDefaultPackages) { nvm_install_default_packages }
                if (-not [string]::IsNullOrEmpty($reinstallFrom) -and $reinstallFrom -ne 'N/A') {
                    nvm 'reinstall-packages' $reinstallFrom
                }
                if (-not [string]::IsNullOrEmpty($lts)) {
                    $ltsLower = $lts.ToLower()
                    nvm_ensure_default_set "lts/$ltsLower"
                } else {
                    nvm_ensure_default_set $providedVersion
                }
                if ($writeNvmrc) { nvm_write_nvmrc $version }
                if (-not [string]::IsNullOrEmpty($installAlias)) { nvm 'alias' $installAlias $providedVersion }
                return
            }

            # Determine flavor
            $flavor = if (nvm_is_iojs_version $version) { nvm_iojs_prefix } else { nvm_node_prefix }

            # Acquire lock
            if (-not (nvm_acquire_install_lock $version)) { return }

            # Install binary
            $env:NVM_NO_PROGRESS = if ($noprogress) { '1' } else { $env:NVM_NO_PROGRESS }
            $env:NVM_OFFLINE = if ($nvmOffline) { '1' } else { '' }

            $success = nvm_install_binary $flavor 'std' $version '1'

            nvm_release_install_lock

            if (-not $success) {
                nvm_err "Installation of $version failed."
                return
            }

            if (-not (nvm_validate_install $version)) {
                nvm_err "The install of $version reported success but failed verification; not activating it."
                return
            }

            # Activate
            nvm_use_if_needed $version
            nvm_install_npm_if_needed $version | Out-Null

            if (-not [string]::IsNullOrEmpty($lts)) {
                nvm_ensure_default_set "lts/$($lts.ToLower())" | Out-Null
            } else {
                nvm_ensure_default_set $providedVersion | Out-Null
            }

            if ($upgradeNpm) { nvm 'install-latest-npm' }
            if (-not $skipDefaultPackages) { nvm_install_default_packages }
            if (-not [string]::IsNullOrEmpty($reinstallFrom) -and $reinstallFrom -ne 'N/A') {
                nvm 'reinstall-packages' $reinstallFrom
            }
            if ($writeNvmrc) { nvm_write_nvmrc $version }
            if (-not [string]::IsNullOrEmpty($installAlias)) { nvm 'alias' $installAlias $providedVersion }
            return
        }

        'uninstall' {
            if ($Arguments.Count -ne 1) {
                nvm_err 'Usage: nvm uninstall <version>'
                nvm_err '       nvm uninstall --lts'
                return
            }

            $pattern = $Arguments[0]
            $version = ''

            switch -Regex ($pattern) {
                '^--lts$' { $version = nvm_match_version 'lts/*' }
                '^lts/\*$' { $version = nvm_match_version 'lts/*' }
                '^lts/(.+)$' { $version = nvm_match_version "lts/$($Matches[1])" }
                '^--lts=(.+)$' { $version = nvm_match_version "lts/$($Matches[1])" }
                default { $version = nvm_version $pattern }
            }

            if ($version -eq (nvm_ls_current)) {
                $typeStr = if (nvm_is_iojs_version $version) { 'io.js' } else { 'node' }
                nvm_err "nvm: Cannot uninstall currently-active $typeStr version, $version (inferred from $pattern)."
                return
            }

            if (-not (nvm_is_version_installed $version)) {
                if ($version -ne 'N/A' -and $version -ne $pattern) {
                    nvm_err "Version '$version' (inferred from $pattern) is not installed."
                } else {
                    nvm_err "Version '$pattern' is not installed."
                }
                return
            }

            $versionPath = nvm_version_path $version
            if (-not (nvm_check_file_permissions $versionPath)) {
                nvm_err 'Cannot uninstall, incorrect permissions on installation folder.'
                return
            }

            # Delete version
            $cacheDir = nvm_cache_dir
            $flavor = if (nvm_is_iojs_version $version) { 'iojs' } else { 'node' }
            $slugBin = nvm_get_download_slug $flavor 'binary' (nvm_strip_iojs_prefix $version)
            $slugSrc = nvm_get_download_slug $flavor 'source' (nvm_strip_iojs_prefix $version)

            Remove-Item (Join-Path $cacheDir 'bin' $slugBin 'files') -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $cacheDir 'src' $slugSrc 'files') -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $versionPath -Recurse -Force -ErrorAction SilentlyContinue

            $successMsg = if (nvm_is_iojs_version $version) {
                "Uninstalled io.js $(nvm_strip_iojs_prefix $version)"
            } else {
                "Uninstalled node $version"
            }
            nvm_echo $successMsg

            # Remove aliases pointing to this version
            $aliasDir = nvm_alias_path
            if (Test-Path $aliasDir) {
                Get-ChildItem $aliasDir -File -Recurse | ForEach-Object {
                    $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content -match [regex]::Escape($version)) {
                        $relName = $_.FullName.Substring($aliasDir.Length + 1).Replace('\', '/')
                        nvm 'unalias' $relName
                    }
                }
            }
        }

        'deactivate' {
            $nvmSilent = '--silent' -in $Arguments

            $newPath = nvm_strip_path $env:PATH '/bin'
            if ($newPath -eq $env:PATH) {
                if (-not $nvmSilent) {
                    nvm_err "Could not find $($env:NVM_DIR)\* in `$env:PATH"
                }
            } else {
                $env:PATH = $newPath
                if (-not $nvmSilent) {
                    nvm_echo "$($env:NVM_DIR)\* removed from `$env:PATH"
                }
            }
            $env:NVM_BIN = $null
            $env:NVM_INC = $null
        }

        'use' {
            $providedVersion = ''
            $nvmSilent = $false
            $nvmDeletePrefix = '0'
            $nvmLts = ''
            $writeNvmrc = $false
            $isFromNvmrc = $false

            foreach ($arg in $Arguments) {
                switch -Regex ($arg) {
                    '^--silent$' { $nvmSilent = $true }
                    '^--delete-prefix$' { $nvmDeletePrefix = '1' }
                    '^--lts$' { $nvmLts = '*' }
                    '^--lts=(.+)$' { $nvmLts = $Matches[1] }
                    '^--save$' { $writeNvmrc = $true }
                    '^-w$' { $writeNvmrc = $true }
                    '^--' { }
                    default {
                        if (-not [string]::IsNullOrEmpty($arg)) { $providedVersion = $arg }
                    }
                }
            }

            $version = ''
            if (-not [string]::IsNullOrEmpty($nvmLts)) {
                $version = nvm_match_version "lts/$nvmLts"
            } elseif ([string]::IsNullOrEmpty($providedVersion)) {
                $oldSilent = $env:NVM_SILENT
                $env:NVM_SILENT = if ($nvmSilent) { '1' } else { '0' }
                $providedVersion = nvm_rc_version
                $env:NVM_SILENT = $oldSilent
                if (-not [string]::IsNullOrEmpty($providedVersion)) {
                    $isFromNvmrc = $true
                    $version = nvm_version $providedVersion
                }
                if ([string]::IsNullOrEmpty($version)) {
                    if (-not $nvmSilent) {
                        nvm_err 'Please see `nvm --help` or https://github.com/nvm-sh/nvm#nvmrc for more information.'
                    }
                    return
                }
            } else {
                $version = nvm_match_version $providedVersion
            }

            if ([string]::IsNullOrEmpty($version)) {
                if (-not $nvmSilent) {
                    nvm_err 'Usage: nvm use [<version>]'
                    nvm_err '  Provide a <version>, or run from a directory containing an .nvmrc file.'
                }
                return
            }

            if ($writeNvmrc) { nvm_write_nvmrc $version }

            $infinity = [char]0x221E
            if ($version -eq 'system') {
                if (nvm_has_system_node) {
                    nvm 'deactivate' '--silent' | Out-Null
                    if (-not $nvmSilent) {
                        $nodeV = & node -v 2>$null
                        nvm_echo "Now using system version of node: $nodeV$(nvm_print_npm_version)"
                    }
                    return
                } elseif (-not $nvmSilent) {
                    nvm_err 'System version of node not found.'
                }
                return
            } elseif ($version -eq $infinity) {
                if (-not $nvmSilent) {
                    nvm_err "The alias `"$providedVersion`" leads to an infinite loop. Aborting."
                }
                return
            }

            if ($version -eq 'N/A') {
                if (-not $nvmSilent) {
                    $fromNvmrcStr = if ($isFromNvmrc) { '1' } else { '0' }
                    nvm_ensure_version_installed $providedVersion $fromNvmrcStr
                }
                return
            }
            $fromNvmrcStr = if ($isFromNvmrc) { '1' } else { '0' }
            if (-not (nvm_ensure_version_installed $version $fromNvmrcStr)) { return }

            $versionDir = nvm_version_path $version

            # Update PATH
            $env:PATH = nvm_change_path $env:PATH '/bin' $versionDir
            $env:NVM_BIN = $versionDir
            $env:NVM_INC = Join-Path $versionDir 'include' 'node'

            if (-not $nvmSilent) {
                if (nvm_is_iojs_version $version) {
                    nvm_echo "Now using io.js $(nvm_strip_iojs_prefix $version)$(nvm_print_npm_version)"
                } else {
                    nvm_echo "Now using node $version$(nvm_print_npm_version)"
                }
            }

            # Check npm prefix compatibility
            if ($version -ne 'system') {
                $useCmd = "nvm use --delete-prefix $version"
                if ($nvmSilent) { $useCmd += ' --silent' }
                nvm_die_on_prefix $nvmDeletePrefix $useCmd $versionDir | Out-Null
            }
        }

        'run' {
            $nvmSilent = $false
            $nvmLts = ''
            $runArgs = @()
            $versionArg = ''
            $parsingOptions = $true

            foreach ($arg in $Arguments) {
                if ($parsingOptions) {
                    switch -Regex ($arg) {
                        '^--silent$' { $nvmSilent = $true; continue }
                        '^--lts$' { $nvmLts = '*'; continue }
                        '^--lts=(.+)$' { $nvmLts = $Matches[1]; continue }
                        default {
                            if ([string]::IsNullOrEmpty($versionArg) -and -not [string]::IsNullOrEmpty($arg)) {
                                $versionArg = $arg
                                $parsingOptions = $false
                            } else {
                                $runArgs += $arg
                            }
                        }
                    }
                } else {
                    $runArgs += $arg
                }
            }

            $version = ''
            if (-not [string]::IsNullOrEmpty($nvmLts)) {
                $version = ''
                $ltsArg = "--lts=$nvmLts"
                $silentArg = if ($nvmSilent) { '--silent' } else { '' }
                $execArgs = @($silentArg, $ltsArg) + @($versionArg) + @('node') + $runArgs
                $execArgs = $execArgs | Where-Object { -not [string]::IsNullOrEmpty($_) }
                nvm 'exec' @execArgs
                return
            }

            if (-not [string]::IsNullOrEmpty($versionArg)) {
                $version = nvm_version $versionArg 2>$null
                if ($version -eq 'N/A' -and -not (nvm_is_valid_version $versionArg)) {
                    # Not a version, treat as arg
                    $runArgs = @($versionArg) + $runArgs
                    $versionArg = ''
                    $providedVersion = nvm_rc_version
                    if (-not [string]::IsNullOrEmpty($providedVersion)) {
                        $version = nvm_version $providedVersion
                    }
                }
            } else {
                $providedVersion = nvm_rc_version
                if (-not [string]::IsNullOrEmpty($providedVersion)) {
                    $version = nvm_version $providedVersion
                }
            }

            if ([string]::IsNullOrEmpty($version) -or $version -eq 'N/A') {
                nvm_err 'Usage: nvm run [<version>] [<args>]'
                nvm_err '  Provide a <version>, or run from a directory containing an .nvmrc file.'
                return
            }

            $silentArg = if ($nvmSilent) { '--silent' } else { '' }
            $execArgs = @($silentArg, $version, 'node') + $runArgs
            $execArgs = $execArgs | Where-Object { -not [string]::IsNullOrEmpty($_) }
            nvm 'exec' @execArgs
        }

        'exec' {
            $nvmSilent = $false
            $nvmLts = ''
            $execVersion = ''
            $execArgs = @()
            $parsingOptions = $true

            foreach ($arg in $Arguments) {
                if ($parsingOptions) {
                    switch -Regex ($arg) {
                        '^--silent$' { $nvmSilent = $true; continue }
                        '^--lts$' { $nvmLts = '*'; continue }
                        '^--lts=(.+)$' { $nvmLts = $Matches[1]; continue }
                        '^--$' { $parsingOptions = $false; continue }
                        default {
                            if ([string]::IsNullOrEmpty($execVersion) -and -not [string]::IsNullOrEmpty($arg)) {
                                $execVersion = $arg
                                $parsingOptions = $false
                            }
                        }
                    }
                } else {
                    $execArgs += $arg
                }
            }

            $providedVersion = $execVersion
            $versionSource = ''

            if (-not [string]::IsNullOrEmpty($nvmLts)) {
                $providedVersion = "lts/$nvmLts"
                $version = $providedVersion
                $versionSource = 'lts'
            } elseif (-not [string]::IsNullOrEmpty($providedVersion)) {
                $version = nvm_version $providedVersion 2>$null
                if ($version -eq 'N/A' -and -not (nvm_is_valid_version $providedVersion)) {
                    # Not a version - unshift into args
                    $execArgs = @($providedVersion) + $execArgs
                    $providedVersion = nvm_rc_version
                    $version = nvm_version $providedVersion 2>$null
                    $versionSource = 'nvmrc'
                } else {
                    $versionSource = 'arg'
                }
            }

            if ([string]::IsNullOrEmpty($versionSource)) {
                if (-not $nvmSilent) {
                    nvm_err 'WARNING: `nvm exec` was invoked without a version argument and without an .nvmrc file.'
                    nvm_err '  Falling back to the active node version.'
                }
                $providedVersion = 'current'
                $version = nvm_version 'current'
            }

            if (-not (nvm_ensure_version_installed $providedVersion)) { return }

            if (-not $nvmSilent) {
                $v = nvm_version $version
                if (-not [string]::IsNullOrEmpty($nvmLts)) {
                    if ($nvmLts -eq '*') { nvm_echo "Running node latest LTS -> $v" }
                    else { nvm_echo "Running node LTS `"$nvmLts`" -> $v" }
                } elseif (nvm_is_iojs_version $version) {
                    nvm_echo "Running io.js $(nvm_strip_iojs_prefix $version)"
                } else {
                    nvm_echo "Running node $version"
                }
            }

            # Run with modified PATH
            $versionDir = nvm_version_path $version
            $savedPath = $env:PATH
            $env:PATH = nvm_change_path $env:PATH '/bin' $versionDir

            try {
                if ($execArgs.Count -gt 0) {
                    $cmd = $execArgs[0]
                    $cmdArgs = if ($execArgs.Count -gt 1) { $execArgs[1..($execArgs.Count - 1)] } else { @() }
                    & $cmd @cmdArgs
                }
            } finally {
                $env:PATH = $savedPath
            }
        }

        '^ls$|^list$' {
            $pattern = ''
            $noColors = $false
            $noAlias = $false

            foreach ($arg in $Arguments) {
                switch -Regex ($arg) {
                    '^--no-colors$' { $noColors = $true; $env:NVM_NO_COLORS = '--no-colors' }
                    '^--no-alias$' { $noAlias = $true }
                    '^--' { }
                    default { if ([string]::IsNullOrEmpty($pattern)) { $pattern = $arg } }
                }
            }

            if (-not [string]::IsNullOrEmpty($pattern) -and $noAlias) {
                nvm_err '`--no-alias` is not supported when a pattern is provided.'
                return
            }

            $lsOutput = nvm_ls $pattern
            nvm_print_versions @($lsOutput)

            if (-not $noAlias -and [string]::IsNullOrEmpty($pattern)) {
                if ($noColors) {
                    nvm 'alias' '--no-colors'
                } else {
                    nvm 'alias'
                }
            }

            if ($noColors) { $env:NVM_NO_COLORS = $null }
            return
        }

        '^ls-remote$|^list-remote$' {
            $nvmLts = ''
            $pattern = ''
            $noColors = $false

            foreach ($arg in $Arguments) {
                switch -Regex ($arg) {
                    '^--lts$' { $nvmLts = '*' }
                    '^--lts=(.+)$' { $nvmLts = $Matches[1] }
                    '^--no-colors$' { $noColors = $true; $env:NVM_NO_COLORS = '--no-colors' }
                    '^--' { }
                    default {
                        if ([string]::IsNullOrEmpty($pattern)) {
                            $pattern = $arg
                            if ([string]::IsNullOrEmpty($nvmLts)) {
                                if ($pattern -eq 'lts/*') { $nvmLts = '*'; $pattern = '' }
                                elseif ($pattern -match '^lts/(.+)$') { $nvmLts = $Matches[1]; $pattern = '' }
                            }
                        }
                    }
                }
            }

            $env:NVM_LTS_TEMP = $nvmLts
            $output = nvm_remote_versions $pattern
            $env:NVM_LTS_TEMP = $null

            if ($null -ne $output -and $output -ne 'N/A') {
                nvm_print_versions @($output)
            } else {
                nvm_print_versions @('N/A')
            }
            if ($noColors) { $env:NVM_NO_COLORS = $null }
            return
        }

        'current' {
            nvm_version 'current'
            return
        }

        'which' {
            $nvmSilent = $false
            $providedVersion = ''

            foreach ($arg in $Arguments) {
                switch ($arg) {
                    '--silent' { $nvmSilent = $true }
                    '--' { }
                    default { $providedVersion = $arg }
                }
            }

            $version = ''
            if ([string]::IsNullOrEmpty($providedVersion)) {
                $env:NVM_SILENT = if ($nvmSilent) { '1' } else { '0' }
                $providedVersion = nvm_rc_version
                $env:NVM_SILENT = $null
                if (-not [string]::IsNullOrEmpty($providedVersion)) {
                    $version = nvm_version $providedVersion
                }
            } elseif ($providedVersion -ne 'system') {
                $version = nvm_version $providedVersion
            } else {
                $version = 'system'
            }

            if ([string]::IsNullOrEmpty($version)) {
                nvm_err 'Usage: nvm which [current | <version>]'
                return
            }

            if ($version -eq 'system') {
                if ((nvm_has_system_node) -or (nvm_has_system_iojs)) {
                    nvm 'use' 'system' '--silent' | Out-Null
                    $cmd = Get-Command node -ErrorAction SilentlyContinue
                    if ($cmd) { nvm_echo $cmd.Source; return }
                }
                nvm_err 'System version of node not found.'
                return
            }

            $infinity = [char]0x221E
            if ($version -eq $infinity) {
                nvm_err "The alias `"$providedVersion`" leads to an infinite loop. Aborting."
                return
            }

            if (-not (nvm_ensure_version_installed $providedVersion)) { return }
            $versionDir = nvm_version_path $version
            nvm_echo (Join-Path $versionDir 'node.exe')
            return
        }

        'alias' {
            $aliasDir = nvm_alias_path
            $ltsDir = Join-Path $aliasDir 'lts'
            if (-not (Test-Path $aliasDir)) { New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null }
            if (-not (Test-Path $ltsDir)) { New-Item -ItemType Directory -Path $ltsDir -Force | Out-Null }

            $aliasName = '--'
            $target = '--'
            $noColors = $false

            foreach ($arg in $Arguments) {
                switch -Regex ($arg) {
                    '^--no-colors$' { $noColors = $true; $env:NVM_NO_COLORS = '--no-colors' }
                    '^--' { }
                    default {
                        if ($aliasName -eq '--') { $aliasName = $arg }
                        elseif ($target -eq '--') { $target = $arg }
                    }
                }
            }

            if ($target -eq '' ) {
                # Empty string passed as target: unalias
                nvm 'unalias' $aliasName
                return
            } elseif ($aliasName -match '#') {
                nvm_err 'Aliases with a comment delimiter (#) are not supported.'
                return
            } elseif ($target -ne '--') {
                # Create alias
                if ($aliasName -match '/') {
                    nvm_err 'Aliases in subdirectories are not supported.'
                    return
                }
                $version = nvm_version $target 2>$null
                if ($version -eq 'N/A') {
                    nvm_err "! WARNING: Version '$target' does not exist."
                }
                nvm_make_alias $aliasName $target | Out-Null
                $nvmCurrent = nvm_ls_current
                nvm_print_formatted_alias $aliasName $target $version $false $nvmCurrent
            } else {
                # List aliases
                if ($aliasName -eq '--') { $aliasName = '' }
                nvm_list_aliases $aliasName
            }
            if ($noColors) { $env:NVM_NO_COLORS = $null }
            return
        }

        'unalias' {
            $aliasDir = nvm_alias_path
            if ($Arguments.Count -ne 1) {
                nvm_err 'Usage: nvm unalias <name>'
                return
            }
            $aliasName = $Arguments[0]
            if ($aliasName -match '/') {
                nvm_err 'Aliases in subdirectories are not supported.'
                return
            }

            $iojsPrefix = nvm_iojs_prefix
            $nodePrefix = nvm_node_prefix

            $safeAliasName = if ($aliasName -eq 'lts/*') { 'lts/latest' } else { $aliasName }
            $aliasFile = Join-Path $aliasDir $safeAliasName
            if (-not (Test-Path $aliasFile)) {
                if ($aliasName -in @('stable', 'unstable', $iojsPrefix, $nodePrefix, 'system')) {
                    nvm_err "$aliasName is a default (built-in) alias and cannot be deleted."
                    return
                }
                nvm_err "Alias $aliasName doesn't exist!"
                return
            }

            $original = nvm_alias $aliasName
            Remove-Item $aliasFile -Force
            nvm_echo "Deleted alias $aliasName - restore it with ``nvm alias `"$aliasName`" `"$original`"``"
            return
        }

        'install-latest-npm' {
            if ($Arguments.Count -ne 0) {
                nvm_err 'Usage: nvm install-latest-npm'
                return
            }
            nvm_install_latest_npm
            return
        }

        '^reinstall-packages$|^copy-packages$' {
            if ($Arguments.Count -ne 1) {
                nvm_err "Usage: nvm $Command <version>"
                return
            }

            $providedVersion = $Arguments[0]
            $current = nvm_ls_current
            if ($providedVersion -eq $current -or (nvm_version $providedVersion) -eq $current) {
                nvm_err 'Can not reinstall packages from the current version of node.'
                return
            }

            $version = ''
            if ($providedVersion -eq 'system') {
                if (-not (nvm_has_system_node) -and -not (nvm_has_system_iojs)) {
                    nvm_err 'No system version of node or io.js detected.'
                    return
                }
                $version = 'system'
            } else {
                $version = nvm_version $providedVersion
            }

            $npmList = nvm_npm_global_modules $version
            $parts = $npmList -split ' //// '
            $installs = $parts[0].Trim()
            $links = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

            nvm_echo "Reinstalling global packages from $version..."
            if (-not [string]::IsNullOrEmpty($installs)) {
                $pkgs = $installs -split '\s+'
                & npm install -g --quiet @pkgs
            } else {
                nvm_echo 'No installed global packages found...'
            }

            nvm_echo "Linking global packages from $version..."
            if (-not [string]::IsNullOrEmpty($links)) {
                foreach ($link in ($links -split "`n")) {
                    $link = $link.Trim()
                    if (-not [string]::IsNullOrEmpty($link)) {
                        Push-Location $link
                        & npm link
                        Pop-Location
                    }
                }
            } else {
                nvm_echo 'No linked global packages found...'
            }
            return
        }

        'clear-cache' {
            $cacheDir = nvm_cache_dir
            if (Test-Path $cacheDir) { Remove-Item $cacheDir -Recurse -Force -ErrorAction SilentlyContinue }
            nvm_echo 'nvm cache cleared.'
            return
        }

        'version' {
            if ($Arguments.Count -ge 1) {
                nvm_version $Arguments[0]
            } else {
                nvm_version
            }
            return
        }

        'version-remote' {
            $nvmLts = ''
            $pattern = ''
            foreach ($arg in $Arguments) {
                switch -Regex ($arg) {
                    '^--lts$' { $nvmLts = '*' }
                    '^--lts=(.+)$' { $nvmLts = $Matches[1] }
                    '^--' { }
                    default { if ([string]::IsNullOrEmpty($pattern)) { $pattern = $arg } }
                }
            }
            if ($pattern -eq 'lts/*') { $nvmLts = '*'; $pattern = '' }
            elseif ($pattern -match '^lts/(.+)$') { $nvmLts = $Matches[1]; $pattern = '' }

            if ([string]::IsNullOrEmpty($pattern)) { $pattern = 'node' }
            $env:NVM_VERSION_ONLY = 'true'
            $env:NVM_LTS_TEMP = $nvmLts
            nvm_remote_version $pattern
            $env:NVM_VERSION_ONLY = $null
            $env:NVM_LTS_TEMP = $null
            return
        }

        'set-colors' {
            $colors = if ($Arguments.Count -ge 1) { $Arguments[0] } else { '' }
            $result = nvm_set_colors $colors
            if (-not $result) {
                nvm '--help'
                nvm_echo ''
                nvm_err 'Please pass in five valid color codes. Choose from: rRgGbBcCyYmMkKeW'
            }
            return
        }

        'unload' {
            nvm 'deactivate' '--silent'
            $env:NVM_NODEJS_ORG_MIRROR = $null
            $env:NVM_IOJS_ORG_MIRROR = $null
            $env:NVM_DIR = $null
            $env:NVM_BIN = $null
            $env:NVM_INC = $null
            $env:NVM_COLORS = $null
            Remove-Module nvm -Force -ErrorAction SilentlyContinue
            return
        }

        default {
            nvm '--help'
        }
    }
}

# =====================================
# Section 15: Auto-use & Initialization
# =====================================

function nvm_auto {
    param([string]$Mode = 'use')
    switch ($Mode) {
        'none' { return }
        'use' {
            $nvmCurrent = nvm_ls_current
            if ($nvmCurrent -eq 'none' -or $nvmCurrent -eq 'system') {
                $version = nvm_resolve_local_alias 'default' 2>$null
                if (-not [string]::IsNullOrEmpty($version) -and $version -ne 'N/A' -and (nvm_is_valid_version $version)) {
                    nvm 'use' '--silent' $version | Out-Null
                } else {
                    $rcVersion = nvm_rc_version 2>$null
                    if (-not [string]::IsNullOrEmpty($rcVersion)) {
                        $env:NVM_SILENT = '1'
                        nvm 'use' '--silent' | Out-Null
                        $env:NVM_SILENT = $null
                    }
                }
            } else {
                nvm 'use' '--silent' $nvmCurrent | Out-Null
            }
        }
        'install' {
            $version = nvm_alias 'default' 2>$null
            if (-not [string]::IsNullOrEmpty($version) -and $version -ne 'N/A' -and (nvm_is_valid_version $version)) {
                nvm 'install' $version | Out-Null
            } else {
                $rcVersion = nvm_rc_version 2>$null
                if (-not [string]::IsNullOrEmpty($rcVersion)) {
                    nvm 'install' | Out-Null
                }
            }
        }
    }
}

# ===========================
# Module initialization
# ===========================

# Ensure NVM_DIR exists
if (-not (Test-Path $env:NVM_DIR)) {
    New-Item -ItemType Directory -Path $env:NVM_DIR -Force | Out-Null
}

# Ensure alias directory structure exists
$aliasDir = nvm_alias_path
if (-not (Test-Path $aliasDir)) {
    New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null
}
$ltsDir = Join-Path $aliasDir 'lts'
if (-not (Test-Path $ltsDir)) {
    New-Item -ItemType Directory -Path $ltsDir -Force | Out-Null
}

# Auto-activate default version
nvm_auto 'use'

# Export only the nvm function
Export-ModuleMember -Function 'nvm'
