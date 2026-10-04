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
. (Join-Path $repoRoot 'setup/modules/agent-clis.ps1')
. (Join-Path $repoRoot 'setup/modules/cli.ps1')

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
        [IO.Directory]::CreateDirectory((Join-Path $source 'modules/config')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $source 'modules/config/config.ps1'), '# fixture')
        [IO.File]::WriteAllText((Join-Path $source 'Microsoft.PowerShell_profile.ps1'), '# source')
        Copy-Item -LiteralPath (Join-Path $repoRoot 'lib/executable.ps1') -Destination (Join-Path $source 'lib/executable.ps1')
        [IO.File]::WriteAllText((Join-Path $source 'setup/setup.ps1'), 'param($RepoPath, [switch]$NonInteractive, $ThemeName, [switch]$Gui, [switch]$InstallFastfetch, [switch]$InstallTopgrade) "installer status"; [IO.File]::WriteAllText((Join-Path $RepoPath "launched.txt"), "ok")')
        # Load the real functions via AST, without running the real installer.
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'setup.ps1'), [ref]$null, [ref]$null)
        foreach ($name in @('Test-IsValidRepo', 'Invoke-Launcher')) {
            $definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $false)
            . ([scriptblock]::Create($definition.Extent.Text))
        }
        Assert-True (Test-IsValidRepo -Path $source) 'Bootstrapper treated the repository path as a wildcard'
        $launched = @(Invoke-Launcher -RepoPath $source -NonInteractive)
        Assert-True ($launched.Count -eq 1 -and $launched[0] -is [bool] -and $launched[0]) 'Bootstrapper output polluted its boolean result'
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

    Test-Result 'Real profile loads from a bracketed repository path' {
        $source = Join-Path $testRoot 'profile [real]'
        [IO.Directory]::CreateDirectory($source) | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot 'modules') -Destination $source -Recurse
        Copy-Item -LiteralPath (Join-Path $repoRoot 'Microsoft.PowerShell_profile.ps1') -Destination $source
        $scriptPath = Join-Path $source 'Microsoft.PowerShell_profile.ps1'
        $executable = if ($PSVersionTable.PSVersion.Major -ge 7) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'powershell.exe' }
        $command = "`$env:CI='true'; `$env:PATH=''; Set-Variable HOME $(ConvertTo-PowerShellLiteral $source) -Force; . $(ConvertTo-PowerShellLiteral $scriptPath); if (-not (Get-Command docs -ErrorAction SilentlyContinue)) { exit 1 }; if (-not (Test-Path -LiteralPath `$script:Config.CachePath)) { exit 2 }; `$stamp=(Get-Item -LiteralPath `$script:Config.CachePath).LastWriteTimeUtc.Ticks; Remove-Variable __CONFIG_POWERSHELL7_PROFILE_LOADED -Scope Global; . $(ConvertTo-PowerShellLiteral $scriptPath); if ((Get-Item -LiteralPath `$script:Config.CachePath).LastWriteTimeUtc.Ticks -ne `$stamp) { exit 3 }; exit 0"
        & $executable -NoProfile -ExecutionPolicy Bypass -Command $command | Out-Host
        Assert-True ($LASTEXITCODE -eq 0) 'Real profile did not load navigation functions'
    }

    Test-Result 'Scoop stdout and nonzero exit never report successful installation' {
        function Get-Command { param($Name, $ErrorAction) return [PSCustomObject]@{ Source = 'mock-scoop' } }
        function Install-Scoop { return $true }
        function mock-scoop { 'download failed'; $global:LASTEXITCODE = 1 }
        function Update-ProcessPathFromUser { }
        $result = @(Install-ScoopFallbackPackage -Id 'Fastfetch-cli.Fastfetch' -DisplayName 'Fastfetch')
        Assert-True ($result.Count -eq 1 -and $result[0] -is [bool] -and -not $result[0]) 'Scoop failure output polluted the boolean result'
    }

    Test-Result 'npm stdout never turns a failed agent install into success' {
        function Get-AgentCliCommand { param($Name) if ($Name -eq 'npm') { return [PSCustomObject]@{ Source = 'mock-npm' } } }
        function mock-npm { 'npm download failed'; $global:LASTEXITCODE = 1 }
        $result = @(Install-AgentCli -Name 'OpenCode')
        Assert-True ($result.Count -eq 1 -and $result[0] -is [bool] -and -not $result[0]) 'npm failure output polluted the boolean result'
    }

    Test-Result 'Vendor script stdout never turns a failed agent install into success' {
        function Get-FileFromUrl {
            param($Url, $OutFile, $MinBytes, $Description)
            Set-Content -LiteralPath $OutFile -Value "'installer failed'; exit 1"
            return $true
        }
        function Update-ProcessPathFromUser { }
        function Get-AgentCliCommand { return [PSCustomObject]@{ Source = 'existing-claude.exe' } }
        $result = @(Invoke-OfficialPowerShellInstaller -Spec (Get-AgentCliInstallSpec -Name 'ClaudeCode'))
        Assert-True ($result.Count -eq 1 -and $result[0] -is [bool] -and -not $result[0]) 'Vendor failure output polluted the boolean result'
    }

    Test-Result 'Interactive CLI reports failure to its caller' {
        $script:menuAnswers = [Collections.Generic.Queue[string]]::new()
        foreach ($answer in @('1', 'n', 'n', 'n')) { $script:menuAnswers.Enqueue($answer) }
        function Read-Host { return $script:menuAnswers.Dequeue() }
        function Install-OhMyPosh { return $false }
        function Start-ProfileInstall { return $false }
        $result = @(Start-CliMenu -RepoPath $testRoot)
        Assert-True ($result.Count -eq 1 -and $result[0] -is [bool] -and -not $result[0]) 'CLI failure was not returned'
    }

    Test-Result 'Legacy migration preserves unrelated dot-sourced profiles' {
        $source = Join-Path $testRoot 'legacy-source'
        [IO.Directory]::CreateDirectory((Join-Path $source 'modules')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $source 'Microsoft.PowerShell_profile.ps1'), '# source')
        $global:PROFILE = Join-Path $testRoot 'legacy-mixed.ps1'
        $unrelated = ". 'C:\Other\Microsoft.PowerShell_profile.ps1'"
        $content = "# Generated by config-powershell7 installer`r`n`$env:__PROFILE_REPO_ROOT = $(ConvertTo-PowerShellLiteral $source)`r`n. $(ConvertTo-PowerShellLiteral (Join-Path $source 'Microsoft.PowerShell_profile.ps1'))`r`n$unrelated`r`n"
        Set-Content -LiteralPath $PROFILE -Value $content -NoNewline
        Assert-True (Install-Profile -RepoPath $source) 'Legacy migration failed'
        Assert-True ((Get-Content -LiteralPath $PROFILE -Raw).Contains($unrelated)) 'Migration deleted unrelated user dot-source'
        Assert-True (Uninstall-Profile -RepoPath $source) 'Mixed legacy uninstall failed'
        Assert-True ((Get-Content -LiteralPath $PROFILE -Raw).Contains($unrelated)) 'Uninstall deleted unrelated user dot-source'
    }

    Test-Result 'Legacy current-host profile is migrated and removed on uninstall' {
        $source = Join-Path $testRoot 'legacy-host-source'
        [IO.Directory]::CreateDirectory((Join-Path $source 'modules')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $source 'Microsoft.PowerShell_profile.ps1'), '# source')
        $hostPath = Join-Path $testRoot 'legacy-current-host.ps1'
        $allPath = Join-Path $testRoot 'legacy-all-hosts.ps1'
        $global:PROFILE = [PSCustomObject]@{ CurrentUserAllHosts = $allPath; CurrentUserCurrentHost = $hostPath }
        $legacy = "# Generated by config-powershell7 installer`r`n`$env:__PROFILE_REPO_ROOT = $(ConvertTo-PowerShellLiteral $source)`r`n`$env:POSH_THEME = 'atomic'`r`n. $(ConvertTo-PowerShellLiteral (Join-Path $source 'Microsoft.PowerShell_profile.ps1'))`r`n# user-owned"
        Set-Content -LiteralPath $hostPath -Value $legacy -NoNewline
        Assert-True (Install-Profile -RepoPath $source) 'Legacy host migration failed'
        $remaining = Get-Content -LiteralPath $hostPath -Raw
        Assert-True ($remaining.Contains('# user-owned') -and -not $remaining.Contains('__PROFILE_REPO_ROOT') -and -not $remaining.Contains('POSH_THEME')) 'Legacy host stub remained or user code was lost'
        Assert-True (Uninstall-Profile -RepoPath $source) 'All-hosts uninstall failed'
        Assert-True (-not (Test-Path -LiteralPath $allPath)) 'All-hosts link survived uninstall'
    }

    Test-Result 'GUI workers fail closed when their module loader is missing' {
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'setup/modules/gui.ps1'), [ref]$null, [ref]$null)
        $workers = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $node.Member.Value -eq 'AddScript' }, $true))
        Assert-True ($workers.Count -eq 2) 'Expected install and uninstall workers'
        foreach ($worker in $workers) {
            $sync = [hashtable]::Synchronized(@{ LogMessages = [Collections.Generic.List[object]]::new(); InstallFailed = $false; InstallComplete = $false })
            $ps = [PowerShell]::Create()
            try {
                $null = $ps.AddScript($worker.Arguments[0].ScriptBlock.Extent.Text.Trim('{', '}'))
                $null = $ps.AddParameter('SetupDir', (Join-Path $testRoot 'missing-setup'))
                $null = $ps.AddParameter('RepoPath', $testRoot)
                $null = $ps.AddParameter('SyncHash', $sync)
                $null = $ps.AddParameter('ProfilePath', (Join-Path $testRoot 'gui-profile.ps1'))
                if ($worker.Arguments[0].Extent.Text -match 'NeedDownload') {
                    $null = $ps.AddParameter('NeedDownload', $false)
                    $null = $ps.AddParameter('RepoZipUrl', 'https://example.test/release')
                    $null = $ps.AddParameter('RepoName', 'config-powershell7')
                    $null = $ps.AddParameter('Params', @{})
                }
                $null = $ps.Invoke()
                Assert-True ($sync.InstallComplete -and $sync.InstallFailed) 'GUI worker left the UI waiting or silently succeeded'
                Assert-True ($ps.Streams.Error.Count -eq 0) 'GUI worker leaked uncaught nonterminating errors'
            } finally { $ps.Dispose() }
        }
    }

    foreach ($downloadImplementation in @('bootstrapper', 'core')) {
        Test-Result "$downloadImplementation download refuses unrelated directories and retains the old repo" {
            if ($downloadImplementation -eq 'bootstrapper') {
                $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'setup.ps1'), [ref]$null, [ref]$null)
                foreach ($name in @('Test-IsValidRepo', 'Download-Repo')) {
                    $definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $false)
                    . ([scriptblock]::Create($definition.Extent.Text))
                }
            }
            $releaseRoot = Join-Path $testRoot "release-$downloadImplementation"
            $inner = Join-Path $releaseRoot 'repo'
            foreach ($relative in @('Microsoft.PowerShell_profile.ps1', 'modules/config/config.ps1', 'setup/setup.ps1', 'lib/executable.ps1')) {
                $path = Join-Path $inner $relative
                [IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
                [IO.File]::WriteAllText($path, '# fixture')
            }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $fixtureZip = Join-Path $testRoot "release-$downloadImplementation.zip"
            [IO.Compression.ZipFile]::CreateFromDirectory($releaseRoot, $fixtureZip)
            function Get-LatestRepoRelease { return [PSCustomObject]@{ tag_name = 'v-test'; zipball_url = 'https://example.test/release.zip' } }
            function Invoke-RestMethod { return Get-LatestRepoRelease }
            function Invoke-WebRequest { param($Uri, $OutFile, [switch]$UseBasicParsing, $ErrorAction) Copy-Item -LiteralPath $fixtureZip -Destination $OutFile }
            $target = Join-Path $testRoot "target-$downloadImplementation"
            [IO.Directory]::CreateDirectory($target) | Out-Null
            [IO.File]::WriteAllText((Join-Path $target 'user.txt'), 'keep me')
            Assert-True (-not (Download-Repo -TargetDir $target)) 'Download replaced an unrelated existing directory'
            Assert-True ([IO.File]::ReadAllText((Join-Path $target 'user.txt')) -eq 'keep me') 'Unrelated user file was lost'
            foreach ($relative in @('Microsoft.PowerShell_profile.ps1', 'modules/config/config.ps1', 'setup/setup.ps1', 'lib/executable.ps1')) {
                $path = Join-Path $target $relative
                [IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
                [IO.File]::WriteAllText($path, '# previous')
            }
            Assert-True (Download-Repo -TargetDir $target) 'Valid repository update failed'
            $backups = @(Get-ChildItem -LiteralPath $testRoot -Directory -Force | Where-Object { $_.Name -like '.config-powershell7-previous-*' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'user.txt')) })
            Assert-True ($backups.Count -gt 0) 'Old repository and user additions were deleted instead of retained'
        }
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
