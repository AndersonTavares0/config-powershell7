#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:TestsPassed = 0
$script:TestsFailed = 0
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'lib/executable.ps1')
. (Join-Path $repoRoot 'setup/modules/core.ps1')
. (Join-Path $repoRoot 'setup/modules/deps.ps1')
. (Join-Path $repoRoot 'setup/modules/profile.ps1')

function Test-Result {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:TestsPassed++
        Write-Host "PASS: $Name" -ForegroundColor Green
    } catch {
        $script:TestsFailed++
        Write-Host "FAIL: $Name - $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) "pwsh-windows-audit-$([guid]::NewGuid().ToString('N'))"
$originalProfile = $PROFILE
$originalHome = $HOME
$originalXdgCache = $env:XDG_CACHE_HOME
$originalLocation = Get-Location
try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    # Uninstall must never touch the developer's real plugin cache.
    Set-Variable -Name HOME -Value $testRoot -Force
    $env:XDG_CACHE_HOME = Join-Path $testRoot 'cache'

    Test-Result 'Profile update treats dollar replacement tokens literally' {
        $source = Join-Path $testRoot 'repo-$$'
        New-Item -ItemType Directory -Path (Join-Path $source 'modules') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'Microsoft.PowerShell_profile.ps1') -Value '# source'
        $global:PROFILE = Join-Path $testRoot 'literal-profile.ps1'
        Set-Content -LiteralPath $PROFILE -Value "# user-owned`r`n"
        Assert-True (Install-Profile -RepoPath $source -ThemeName 'atomic') 'Initial install failed'
        Assert-True (Install-Profile -RepoPath $source -ThemeName 'Dracula') 'Update failed'
        $content = Get-Content -LiteralPath $PROFILE -Raw
        $expected = '. ' + (ConvertTo-PowerShellLiteral (Join-Path $source 'Microsoft.PowerShell_profile.ps1'))
        Assert-True ($content.Contains($expected)) 'Updated profile corrupted the literal source path'
        Assert-True ($content.Contains('# user-owned')) 'User content was lost'
        Assert-True (Uninstall-Profile -RepoPath $source) 'Uninstall failed'
        Assert-True ((Get-Content -LiteralPath $PROFILE -Raw).Contains('# user-owned')) 'Uninstall lost user content'
    }

    Test-Result 'Profile supports bracketed Windows paths' {
        $source = Join-Path $testRoot 'repo [local]'
        [IO.Directory]::CreateDirectory((Join-Path $source 'modules')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $source 'Microsoft.PowerShell_profile.ps1'), '# source')
        $global:PROFILE = Join-Path $testRoot 'profile [local].ps1'
        Assert-True (Install-Profile -RepoPath $source) 'Literal repository path was treated as a wildcard'
        Assert-True (Test-Path -LiteralPath $PROFILE -PathType Leaf) 'Literal profile filename was not created'
        Assert-True (Uninstall-Profile -RepoPath $source) 'Literal profile uninstall failed'
        Assert-True (-not (Test-Path -LiteralPath $PROFILE)) 'Literal profile survived uninstall'
    }

    Test-Result 'Relative repo is linked with an absolute path' {
        Set-Location -LiteralPath $testRoot
        New-Item -ItemType Directory -Path 'relative/modules' -Force | Out-Null
        Set-Content -LiteralPath 'relative/Microsoft.PowerShell_profile.ps1' -Value '# source'
        $global:PROFILE = Join-Path $testRoot 'relative-profile.ps1'
        Assert-True (Install-Profile -RepoPath './relative') 'Relative install failed'
        $content = Get-Content -LiteralPath $PROFILE -Raw
        Assert-True ($content.Contains((Join-Path $testRoot 'relative/Microsoft.PowerShell_profile.ps1'))) 'Profile depends on the next shell working directory'
    }

    Test-Result 'Bootstrapper detects and launches a repo in a bracketed path' {
        $source = Join-Path $testRoot 'bootstrap [local]'
        [IO.Directory]::CreateDirectory((Join-Path $source 'setup')) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $source 'lib')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $source 'Microsoft.PowerShell_profile.ps1'), '# source')
        Copy-Item -LiteralPath (Join-Path $repoRoot 'lib/executable.ps1') -Destination (Join-Path $source 'lib/executable.ps1')
        [IO.File]::WriteAllText((Join-Path $source 'setup/setup.ps1'), 'param($RepoPath, [switch]$NonInteractive, $ThemeName, [switch]$Gui, [switch]$InstallFastfetch, [switch]$InstallTopgrade) [IO.File]::WriteAllText((Join-Path $RepoPath "launched.txt"), "ok")')
        # Load the real functions via AST, without running the real installer.
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'setup.ps1'), [ref]$null, [ref]$null)
        foreach ($name in @('Test-IsValidRepo', 'Invoke-Launcher')) {
            $definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $false)
            . ([scriptblock]::Create($definition.Extent.Text))
        }
        Assert-True (Test-IsValidRepo -Path $source) 'Bootstrapper treated the repository path as a wildcard'
        Assert-True (Invoke-Launcher -RepoPath $source -NonInteractive) 'Bootstrapper launcher failed'
        Assert-True (Test-Path -LiteralPath (Join-Path $source 'launched.txt')) 'Setup entry point did not run'
    }

    foreach ($fixture in @('{"profiles":{"list":[]}}', '{"profiles":{"defaults":{}},"schemes":[{"name":"Existing"}]}')) {
        Test-Result "Terminal color scheme accepts minimal settings: $fixture" {
            $path = Join-Path $testRoot 'terminal-colors.json'
            Set-Content -LiteralPath $path -Value $fixture
            Assert-True (Set-WindowsTerminalColorScheme -ThemeName 'Dracula' -SettingsPath $path) 'Scheme configuration failed'
            $result = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            Assert-True ($result.profiles.defaults.colorScheme -eq 'Dracula') 'Default scheme was not set'
            Assert-True (@($result.schemes | Where-Object { $_.name -eq 'Dracula' }).Count -eq 1) 'New scheme was not added'
        }
    }

    Test-Result 'Terminal font accepts profiles without defaults' {
        $path = Join-Path $testRoot 'terminal-font.json'
        Set-Content -LiteralPath $path -Value '{"profiles":{"list":[{"name":"PowerShell"}]}}'
        Assert-True (Set-WindowsTerminalFont -SettingsPath $path) 'Font configuration failed'
        $result = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        Assert-True ($result.profiles.defaults.font.face -eq 'FiraCode Nerd Font') 'Default font was not set'
        Assert-True ($result.profiles.list[0].font.face -eq 'FiraCode Nerd Font') 'Profile font was not set'
    }

    Test-Result 'Module download failure is reported and repository trust restored' {
        $script:repositoryPolicies = @()
        function Get-PackageProvider { param($Name, [switch]$ListAvailable, $ErrorAction) return [PSCustomObject]@{ Name = 'NuGet' } }
        function Get-PSRepository { param($Name, $ErrorAction) return [PSCustomObject]@{ InstallationPolicy = 'Untrusted' } }
        function Set-PSRepository { param($Name, $InstallationPolicy) $script:repositoryPolicies += $InstallationPolicy }
        function Get-Module { param($Name, [switch]$ListAvailable, $ErrorAction) return }
        function Install-Module { throw 'simulated gallery outage' }
        Assert-True (-not (Install-PSModules)) 'Failed module installs reported success'
        Assert-True (($script:repositoryPolicies -join ',') -eq 'Trusted,Untrusted') 'Repository trust was not restored'
    }

    Test-Result 'Existing required modules skip downloads without changing trusted gallery' {
        $script:downloadCount = 0
        function Get-PackageProvider { return [PSCustomObject]@{ Name = 'NuGet' } }
        function Get-PSRepository { return [PSCustomObject]@{ InstallationPolicy = 'Trusted' } }
        function Set-PSRepository { throw 'Trust must not change' }
        function Get-Module { return [PSCustomObject]@{ Version = [version]'9.0.0' } }
        function Install-Module { $script:downloadCount++ }
        Assert-True (Install-PSModules) 'Existing modules were not accepted'
        Assert-True ($script:downloadCount -eq 0) 'Existing modules were downloaded again'
    }

    Test-Result 'Module discovery exception still restores gallery trust' {
        $script:repositoryPolicies = @()
        function Get-PackageProvider { return [PSCustomObject]@{ Name = 'NuGet' } }
        function Get-PSRepository { return [PSCustomObject]@{ InstallationPolicy = 'Untrusted' } }
        function Set-PSRepository { param($Name, $InstallationPolicy) $script:repositoryPolicies += $InstallationPolicy }
        function Get-Module { throw 'simulated discovery failure' }
        $threw = $false
        try { Install-PSModules | Out-Null } catch { $threw = $true }
        Assert-True $threw 'Discovery failure was hidden'
        Assert-True (($script:repositoryPolicies -join ',') -eq 'Trusted,Untrusted') 'Discovery failure left gallery trusted'
    }

    Test-Result 'Noninteractive dependency failure never prompts or elevates' {
        $script:InstallerNonInteractive = $true
        $script:promptCount = 0
        $script:elevationCount = 0
        function Get-WingetPath { return 'mock-winget.exe' }
        function Start-Process {
            param($FilePath, $ArgumentList, [switch]$NoNewWindow, [switch]$Wait, [switch]$PassThru, $ErrorAction, $Verb)
            if ($Verb) { $script:elevationCount++ }
            return [PSCustomObject]@{ ExitCode = 1 }
        }
        function Read-Host { $script:promptCount++; return 'n' }
        Assert-True (-not (Install-WingetPackage -Id 'Git.Git' -DisplayName 'Git')) 'Failed package reported success'
        Assert-True ($script:promptCount -eq 0 -and $script:elevationCount -eq 0) 'Headless install prompted or elevated'
    }

    Test-Result 'Noninteractive missing WinGet never prompts to install Scoop' {
        $script:InstallerNonInteractive = $true
        $script:promptCount = 0
        function Get-Command { return $null }
        function Read-Host { $script:promptCount++; return 'n' }
        Assert-True (-not (Install-ScoopFallbackPackage -Id 'Git.Git' -DisplayName 'Git')) 'Missing package tools reported success'
        Assert-True ($script:promptCount -eq 0) 'Headless fallback prompted for Scoop'
    }
} finally {
    Set-Location -LiteralPath $originalLocation.Path
    $global:PROFILE = $originalProfile
    Set-Variable -Name HOME -Value $originalHome -Force
    $env:XDG_CACHE_HOME = $originalXdgCache
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Windows compatibility: $script:TestsPassed passed, $script:TestsFailed failed."
if ($script:TestsFailed -gt 0) { exit 1 }
exit 0
