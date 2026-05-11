#Requires -Version 5.1
# Module loader and launcher - called by root setup.ps1 after repo is resolved

param([string]$RepoPath)

$setupDir = Join-Path $RepoPath 'setup'
$modulesDir = Join-Path $setupDir 'modules'

. (Join-Path $modulesDir 'core.ps1')
. (Join-Path $modulesDir 'deps.ps1')
. (Join-Path $modulesDir 'profile.ps1')
. (Join-Path $modulesDir 'orchestrator.ps1')
. (Join-Path $modulesDir 'gui.ps1')
. (Join-Path $modulesDir 'cli.ps1')

$canShowGui = $true
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
} catch {
    $canShowGui = $false
}

if (-not $canShowGui -or ($Host.Name -notmatch 'ConsoleHost' -and $env:CI)) {
    Start-CliMenu -RepoPath $RepoPath
} else {
    Show-Gui -SetupDir $setupDir -RepoPath $RepoPath
}
