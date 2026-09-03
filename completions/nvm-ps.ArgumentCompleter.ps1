# Tab completion for nvm (PowerShell 7+)
# Ported from bash_completion

Register-ArgumentCompleter -CommandName 'nvm' -ScriptBlock {
    param($commandName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $words = $commandAst.ToString() -split '\s+'
    $wordCount = $words.Count

    # All nvm subcommands
    $commands = @(
        'help', 'install', 'uninstall', 'use', 'run', 'exec',
        'alias', 'unalias', 'reinstall-packages', 'copy-packages',
        'current', 'list', 'ls', 'list-remote', 'ls-remote',
        'install-latest-npm',
        'cache', 'deactivate', 'unload',
        'version', 'version-remote', 'which',
        'debug', 'set-colors'
    )

    # Get installed versions (cached to avoid slowness)
    function Get-NvmInstalledVersions {
        if (Get-Command nvm_ls -ErrorAction SilentlyContinue) {
            @(nvm_ls) | ForEach-Object { ($_ -split '\s+')[0] }
        } else {
            @()
        }
    }

    # Get aliases
    function Get-NvmAliases {
        $aliases = @('node', 'stable', 'unstable', 'iojs', 'system')
        $aliasPath = ''
        if (-not [string]::IsNullOrEmpty($env:NVM_DIR)) {
            $aliasPath = Join-Path $env:NVM_DIR 'alias'
        }
        if (-not [string]::IsNullOrEmpty($aliasPath) -and (Test-Path $aliasPath)) {
            Get-ChildItem $aliasPath -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                $relPath = $_.FullName.Substring($aliasPath.Length + 1).Replace('\', '/')
                $aliases += $relPath
            }
        }
        return $aliases
    }

    if ($wordCount -le 2) {
        # Completing first argument (subcommand)
        if ($wordToComplete.StartsWith('-')) {
            @('--help', '--version') |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        } else {
            $commands |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    } else {
        $subcommand = $words[1]
        switch ($subcommand) {
            { $_ -in @('use', 'run', 'exec', 'uninstall', 'ls', 'list', 'which') } {
                if ($wordToComplete.StartsWith('-')) {
                    $opts = @('--silent', '--lts', '--no-colors', '--no-alias', '--save')
                    $opts |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object {
                            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                        }
                } else {
                    $versions = @(Get-NvmInstalledVersions) + @(Get-NvmAliases)
                    $versions |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        Sort-Object -Unique |
                        ForEach-Object {
                            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                        }
                }
            }
            'install' {
                if ($wordToComplete.StartsWith('-')) {
                    @('--lts', '--latest-npm', '--no-progress', '--default',
                      '--save', '--skip-default-packages', '--offline',
                      '-b') |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object {
                            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                        }
                } else {
                    $aliases = Get-NvmAliases
                    $aliases |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object {
                            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                        }
                }
            }
            { $_ -in @('alias', 'unalias') } {
                $aliases = Get-NvmAliases
                if ($wordCount -eq 4 -and $subcommand -eq 'alias') {
                    # Third arg for alias: completing the target version
                    $versions = Get-NvmInstalledVersions
                    $versions |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object {
                            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                        }
                } else {
                    $aliases |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object {
                            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                        }
                }
            }
            { $_ -in @('ls-remote', 'list-remote', 'version-remote') } {
                @('--lts', '--no-colors') |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
            }
            'cache' {
                @('dir', 'clear') |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
            }
            'reinstall-packages' {
                $versions = Get-NvmInstalledVersions
                $versions |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
            }
            'deactivate' {
                @('--silent') |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
            }
        }
    }
}
