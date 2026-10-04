#Requires -Version 5.1
# Module loader and launcher - called by root setup.ps1 after repo is resolved

param(
    [string]$RepoPath,
    [switch]$NonInteractive,
    [string]$ThemeName = '',
    [switch]$Gui,
    [switch]$InstallFastfetch,
    [switch]$InstallTopgrade
)

# Set explicitly: the PS 5.1 relaunch enters through `pwsh -File`, which does not
# inherit the preferences the root setup.ps1 established for the dot-sourced path.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:InstallerNonInteractive = $NonInteractive -or ($env:CI -eq 'true') -or ($env:CI -eq '1')

$setupDir = Join-Path $RepoPath 'setup'
$modulesDir = Join-Path $setupDir 'modules'

. (Join-Path $RepoPath 'lib/executable.ps1')
. (Join-Path $modulesDir 'core.ps1')
. (Join-Path $modulesDir 'deps.ps1')
. (Join-Path $modulesDir 'agent-clis.ps1')
. (Join-Path $modulesDir 'profile.ps1')
. (Join-Path $modulesDir 'orchestrator.ps1')
. (Join-Path $modulesDir 'gui.ps1')
. (Join-Path $modulesDir 'cli.ps1')

$canShowGui = $false
if ($Gui) {
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        $canShowGui = $true
    } catch {
        $canShowGui = $false
    }
}

if ($script:InstallerNonInteractive) {
    $installResult = Start-ProfileInstall -RepoPath $RepoPath -ThemeName $ThemeName `
        -InstallFastfetch ([bool]$InstallFastfetch) -InstallTopgrade ([bool]$InstallTopgrade)
    if (-not $installResult) { throw 'One or more required installation steps failed.' }
} elseif (-not $Gui -or -not $canShowGui -or ($Host.Name -notmatch 'ConsoleHost' -and $env:CI)) {
    Start-CliMenu -RepoPath $RepoPath
} else {
    Show-Gui -SetupDir $setupDir -RepoPath $RepoPath
}
