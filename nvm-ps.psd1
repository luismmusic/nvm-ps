# nvm-ps — Node Version Manager for PowerShell 7+ (Windows 11) — Bilingual en-US / es-ES (BCP 47)
# Fork/Port of nvm-sh/nvm (https://github.com/nvm-sh/nvm) — nvm.sh v0.40.7
# Product: nvm-ps (Windows) — upstream: nvm-sh (Linux/macOS/WSL) — CLI remains `nvm` for 1:1 parity.
# --- English (US) — en-US (BCP 47 en-US, Microsoft Language Portal: behavior, color, folder/file, customize) ---
# Original credits: Tim Caswell <tim@creationix.com>, Matthew Ranney, Jordan Harband (@ljharb) and nvm-sh contributors.
# Fork author: Luis Mendez — all tool credits belong to original nvm-sh creators.
# --- Español (España) — es-ES (BCP 47 es-ES, Portal de idioma de Microsoft: comportamiento, color, carpeta/fichero, ordenador, personalizar) ---
# Créditos originales: Tim Caswell, Matthew Ranney, Jordan Harband y contribuidores de OpenJS Foundation.
# Autor del fork: Luis Mendez — todos los créditos para los creadores de nvm-sh.
# Authorship (logical / lógico): Port in Antigravity; audit/validation/docs in opencode with oh-my-openagent. — Port en Antigravity; auditoría/validación/docs en opencode con oh-my-openagent.

@{
    RootModule        = 'nvm-ps.psm1'
    ModuleVersion     = '0.40.7'
    GUID              = 'a5a8081f-fc3b-4ee7-a4b6-0b3a8d955f2a'
    Author            = 'Luis Mendez (fork of nvm-sh by Tim Caswell, Matthew Ranney, Jordan Harband and contributors)'
    CompanyName       = 'nvm-sh'
    Copyright         = '(c) OpenJS Foundation and nvm-sh contributors. Fork nvm-ps by Luis Mendez — all credits to original nvm-sh creators; this fork is a curiosity port.'
    Description       = 'nvm-ps: Node Version Manager for Windows 11 + PowerShell 7+ — PowerShell port of nvm-sh v0.40.7. CLI is `nvm` (1:1 parity). Fork by Luis Mendez, all credits to nvm-sh (Tim Caswell et al.). Install: irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex — Bilingual en-US/es-ES per BCP 47 (en-US: behavior, color, folder/file / es-ES: comportamiento, color, carpeta/fichero, ordenador)'

    CompatiblePSEditions = @('Desktop', 'Core')
    PowerShellVersion = '7.0'

    FunctionsToExport = @('nvm')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    NestedModules     = @('completions/nvm-ps.ArgumentCompleter.ps1')

    PrivateData       = @{
        PSData = @{
            Tags         = @('node', 'nodejs', 'nvm', 'nvm-ps', 'version-manager', 'windows', 'powershell')
            LicenseUri   = 'https://github.com/nvm-sh/nvm/blob/master/LICENSE.md'
            ProjectUri   = 'https://github.com/luismmusic/nvm-ps'
            ReleaseNotes = 'nvm-ps v0.40.7 — PowerShell 7+ port of nvm-sh v0.40.7. Port by Luis Mendez in Antigravity; audit/validation/docs in opencode with oh-my-openagent. All credits to nvm-sh. Install: irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex'
        }
    }
}
