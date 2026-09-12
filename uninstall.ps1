#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoPath = $PSScriptRoot

# The installer writes the PowerShell 7 CurrentUserAllHosts profile. Under Windows
# PowerShell 5.1 that same variable points at WindowsPowerShell, so uninstalling from
# 5.1 would inspect the wrong file and report nothing to remove.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    $pwshPath = if ($pwshCommand) { $pwshCommand.Source } else { Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe' }
    if (-not (Test-Path $pwshPath -PathType Leaf)) {
        throw 'PowerShell 7 is required to uninstall the managed profile. Install PowerShell 7, then retry.'
    }
    $relaunchArgs = @('-NoProfile', '-File', (Join-Path $repoPath 'uninstall.ps1'))
    if ($NonInteractive) { $relaunchArgs += '-NonInteractive' }
    & $pwshPath @relaunchArgs
    if ($LASTEXITCODE -ne 0) { throw 'Uninstallation failed. Review messages above.' }
    return
}

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
