#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoPath = $PSScriptRoot
$modulesDir = Join-Path $repoPath 'setup\modules'
if (-not (Test-Path (Join-Path $modulesDir 'profile.ps1') -PathType Leaf)) {
    throw 'Modular uninstaller files are missing. Download the latest stable release and retry.'
}

$script:SyncHash = $null
. (Join-Path $repoPath 'lib/executable.ps1')
. (Join-Path $modulesDir 'core.ps1')
. (Join-Path $modulesDir 'deps.ps1')
. (Join-Path $modulesDir 'profile.ps1')

$profileResult = Uninstall-Profile -RepoPath $repoPath
$alacrittyResult = Uninstall-AlacrittyConfig
if (-not ($profileResult -and $alacrittyResult)) {
    throw 'Uninstallation did not complete successfully. Review messages above.'
}

if (-not $NonInteractive) {
    Write-Host 'Managed profile and Alacritty configuration removed.' -ForegroundColor Green
}
