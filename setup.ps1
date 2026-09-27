#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrapper for the PowerShell 7 Profile ecosystem.
.DESCRIPTION
    Acquires the repository (local or remote) and launches the installer.

    Remote flow (irm | iex):
        - Shows summary of what the installer does
        - Asks for install directory (default: LocalApplicationData/config-powershell7)
        - Requests explicit consent before downloading
        - Downloads repo and invokes the local installer

    Local flow (.\setup.ps1 in valid repo):
        - Detects existing repo and invokes the installer directly
        - No prompts, no download

    Invoke remotely:
        irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex

    Or run locally:
        .\setup.ps1
        pwsh -File setup.ps1

    Double-click:
        install.cmd
.NOTES
    Requires Windows 10+ with PowerShell 5.1+.
    Uses winget for package installation.
    The orchestrator does not elevate itself. Individual packages can request UAC.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [switch]$NonInteractive,
    [string]$ThemeName = '',
    [switch]$Gui,
    [switch]$InstallFastfetch,
    [switch]$InstallTopgrade
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# TLS 1.2 enforcement for PS 5.1 (GitHub requires it)
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

# Platform check
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $isWin = $IsWindows
} else {
    $isWin = $true
}

if (-not $isWin) {
    throw 'This installer supports Windows 10/11 x64 only.'
}

$osVersion = [Environment]::OSVersion.Version
$architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($osVersion.Major -lt 10 -or -not [Environment]::Is64BitOperatingSystem -or $architecture -notin @('AMD64', 'x64')) {
    throw "This installer supports Windows 10/11 x64 only. Detected Windows $($osVersion) on $architecture."
}

# Constants
$repoOwner   = 'AndersonTavares0'
$repoName    = 'config-powershell7'
$repoReleaseUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
if ([string]::IsNullOrWhiteSpace($localAppData)) {
    $localAppData = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'AppData\Local'
}
$repoDefaultDir = Join-Path $localAppData $repoName

# Helpers

function Test-IsValidRepo {
    param([string]$Path)
    return (Test-Path (Join-Path $Path 'Microsoft.PowerShell_profile.ps1'))
}

function Invoke-Launcher {
    param(
        [string]$RepoPath,
        [switch]$NonInteractive,
        [string]$ThemeName = '',
        [switch]$Gui,
        [switch]$InstallFastfetch,
        [switch]$InstallTopgrade
    )
    $setupEntryPoint = Join-Path $RepoPath 'setup\setup.ps1'
    if (-not (Test-Path $setupEntryPoint)) {
        Write-Host "Setup directory not found. The repository may be outdated." -ForegroundColor Red
        return $false
    }
    . (Join-Path $RepoPath 'lib/executable.ps1')

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $pwshPath = Get-PwshExecutablePath
        if (-not $pwshPath) {
            $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
            $wingetPath = if ($wingetCommand) { $wingetCommand.Source } else {
                Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\WindowsApps\winget.exe'
            }
            if (Test-Path -LiteralPath $wingetPath -PathType Leaf) {
                Write-Host 'Installing PowerShell 7 with WinGet in user scope...' -ForegroundColor Cyan
                $installArgs = @('install', '--id', 'Microsoft.PowerShell', '--exact', '--source', 'winget',
                    '--scope', 'user', '--accept-source-agreements', '--accept-package-agreements')
                $installProcess = Start-Process -FilePath $wingetPath -ArgumentList $installArgs `
                    -NoNewWindow -Wait -PassThru -ErrorAction Stop
                if ($installProcess.ExitCode -ne 0 -and $Host.Name -eq 'ConsoleHost' -and -not $NonInteractive -and -not $env:CI) {
                    $retryElevated = Read-Host "PowerShell 7 user-scope install failed (exit $($installProcess.ExitCode)). Retry with administrator rights? (y/n) [n]"
                    if ($retryElevated -match '^(?i)y(es)?$') {
                        $installArgs = @('install', '--id', 'Microsoft.PowerShell', '--exact', '--source', 'winget',
                            '--scope', 'machine', '--accept-source-agreements', '--accept-package-agreements')
                        $installProcess = Start-Process -FilePath $wingetPath -ArgumentList $installArgs `
                            -Verb RunAs -Wait -PassThru -ErrorAction Stop
                    }
                }
                if ($installProcess.ExitCode -ne 0) {
                    Write-Host 'PowerShell 7 installation failed through WinGet.' -ForegroundColor Red
                    return $false
                }
            } else {
                . (Join-Path $RepoPath 'lib/executable.ps1')
                . (Join-Path $RepoPath 'setup/modules/core.ps1')
                . (Join-Path $RepoPath 'setup/modules/deps.ps1')
                $scoop = Get-Command scoop -ErrorAction SilentlyContinue
                if (-not $scoop) {
                    if ($Host.Name -ne 'ConsoleHost' -or $NonInteractive -or $env:CI) {
                        Write-Host 'WinGet is unavailable. Run interactively and approve the per-user Scoop fallback, or install PowerShell 7 manually.' -ForegroundColor Red
                        return $false
                    }
                    $installScoop = Read-Host 'WinGet is unavailable. Install Scoop for this user to install PowerShell 7? (y/n) [n]'
                    if ($installScoop -notmatch '^(?i)y(es)?$' -or -not (Install-Scoop)) {
                        Write-Host 'PowerShell 7 installation cancelled. No administrator rights were requested.' -ForegroundColor Yellow
                        return $false
                    }
                }
                $scoop = Get-Command scoop -ErrorAction SilentlyContinue
                if (-not $scoop) { Write-Host 'Scoop command is unavailable after installation.' -ForegroundColor Red; return $false }
                Write-Host 'Installing PowerShell 7 with Scoop...' -ForegroundColor Cyan
                & $scoop.Source install pwsh
                if ($LASTEXITCODE -ne 0) {
                    Write-Host 'Scoop could not install PowerShell 7.' -ForegroundColor Red
                    return $false
                }
                Update-ProcessPathFromUser
            }
            $pwshPath = Get-PwshExecutablePath
            if (-not $pwshPath) {
                Write-Host 'PowerShell 7 install completed, but pwsh.exe is still unavailable. Open a new terminal and retry.' -ForegroundColor Red
                return $false
            }
        }

        $launcherArgs = @('-NoProfile', '-File', $setupEntryPoint, '-RepoPath', $RepoPath)
        if ($NonInteractive) { $launcherArgs += '-NonInteractive' }
        if ($Gui) { $launcherArgs += '-Gui' }
        if ($ThemeName) { $launcherArgs += @('-ThemeName', $ThemeName) }
        if ($InstallFastfetch) { $launcherArgs += '-InstallFastfetch' }
        if ($InstallTopgrade) { $launcherArgs += '-InstallTopgrade' }
        & $pwshPath @launcherArgs
        return $LASTEXITCODE -eq 0
    }
    . $setupEntryPoint -RepoPath $RepoPath -NonInteractive:$NonInteractive `
        -ThemeName $ThemeName -Gui:$Gui -InstallFastfetch:$InstallFastfetch -InstallTopgrade:$InstallTopgrade
    return $true
}

$script:LatestRepoRelease = $null
function Get-LatestRepoRelease {
    if ($script:LatestRepoRelease) { return $script:LatestRepoRelease }
    $script:LatestRepoRelease = Invoke-RestMethod -Uri $repoReleaseUrl -ErrorAction Stop
    if (-not $script:LatestRepoRelease.tag_name -or -not $script:LatestRepoRelease.zipball_url) {
        throw 'Latest GitHub release metadata is incomplete.'
    }
    return $script:LatestRepoRelease
}

function Test-RepoReleaseCurrent {
    param([string]$Path)
    $versionPath = Join-Path $Path '.config-powershell7-version'
    if (-not (Test-Path $versionPath -PathType Leaf)) { return $false }
    $installedVersion = (Get-Content $versionPath -Raw -ErrorAction SilentlyContinue).Trim()
    $latestRelease = Get-LatestRepoRelease
    return $installedVersion -eq $latestRelease.tag_name
}

function Download-Repo {
    param([string]$TargetDir)

    $zipPath    = Join-Path $env:TEMP "$repoName.zip"
    $extractDir = $null
    $previousDir = $null
    $movedPrevious = $false
    # Progress rendering makes Invoke-WebRequest an order of magnitude slower on PS 5.1.
    $previousProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    try {
        $TargetDir = [System.IO.Path]::GetFullPath($TargetDir)
        $parentDir = Split-Path $TargetDir -Parent
        $id = [guid]::NewGuid().ToString('N')
        $extractDir = Join-Path $parentDir ".$repoName-stage-$id"
        $previousDir = Join-Path $parentDir ".$repoName-previous-$id"
        Write-Host "Resolving latest stable release..." -ForegroundColor Cyan
        $release = Get-LatestRepoRelease

        Write-Host "Downloading release $($release.tag_name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $release.zipball_url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop

        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
        }
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

        $innerDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
        if (-not $innerDir -or -not (Test-IsValidRepo $innerDir.FullName)) {
            throw 'Downloaded release does not contain a valid profile repository.'
        }
        Set-Content -Path (Join-Path $innerDir.FullName '.config-powershell7-version') -Value $release.tag_name -Encoding ASCII

        if (Test-Path $TargetDir) {
            Move-Item $TargetDir $previousDir -Force
            $movedPrevious = $true
        }
        Move-Item $innerDir.FullName $TargetDir -Force

        Write-Host "Unblocking script files..." -ForegroundColor Cyan
        Get-ChildItem -Path $TargetDir -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
        Write-Host "Files unblocked." -ForegroundColor Green

        if (-not (Test-IsValidRepo $TargetDir)) { throw 'Activated repository failed validation.' }
        if ($movedPrevious -and (Test-Path $previousDir)) {
            Remove-Item $previousDir -Recurse -Force
            $movedPrevious = $false
        }

        Write-Host "Repository downloaded to: $TargetDir" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Failed to download repository: $($_.Exception.Message)" -ForegroundColor Red
        if ($movedPrevious -and (Test-Path $previousDir)) {
            if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue }
            Move-Item $previousDir $TargetDir -Force -ErrorAction SilentlyContinue
            $movedPrevious = $false
        }
        return $false
    } finally {
        $ProgressPreference = $previousProgress
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        if ($extractDir) { Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Local repo detection

$localRepoPath = $null
if ($PSScriptRoot -and (Test-IsValidRepo $PSScriptRoot)) {
    $localRepoPath = $PSScriptRoot
}

# Local flow: repo already on disk

if ($localRepoPath) {
    # Unblock files in existing repo (covers git clone or manual copy)
    Get-ChildItem -Path $localRepoPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
    $launcherOk = Invoke-Launcher -RepoPath $localRepoPath -NonInteractive:$NonInteractive `
        -ThemeName $ThemeName -Gui:$Gui -InstallFastfetch:$InstallFastfetch -InstallTopgrade:$InstallTopgrade
    if (-not $launcherOk) { throw 'Installation failed. Review messages above.' }
    return
}

# Remote flow: bootstrapper with user agency

$isHeadless = $NonInteractive -or ($env:CI -eq 'true') -or ($env:CI -eq '1')

if (-not $isHeadless) {
    # Welcome banner
    Write-Host ""
    Write-Host "  +------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   PowerShell 7 Profile Kit                           |" -ForegroundColor Cyan
    Write-Host "  |   One-click setup - all dependencies included        |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # High-level summary
    Write-Host "This will download and launch the local installer." -ForegroundColor White
    Write-Host "The installer can configure:" -ForegroundColor White
    Write-Host "  - PowerShell 7, Git, Oh My Posh, Zoxide" -ForegroundColor Gray
    Write-Host "  - FiraCode Nerd Font, PowerShell modules" -ForegroundColor Gray
    Write-Host "  - Windows Terminal theme; optional Fastfetch, Topgrade, Scoop, and AI CLIs" -ForegroundColor Gray
    Write-Host ""

    # Ask install directory
    Write-Host "Install directory [$repoDefaultDir]:" -ForegroundColor Cyan
    $userDir = Read-Host
    $userDir = $userDir.Trim()
    if ([string]::IsNullOrWhiteSpace($userDir)) {
        $repoPath = $repoDefaultDir
    } else {
        $repoPath = $userDir
    }

    # Check if directory exists
    if (Test-Path $repoPath) {
        if (Test-IsValidRepo $repoPath) {
            if (Test-RepoReleaseCurrent $repoPath) {
                Write-Host "Current stable release found at: $repoPath" -ForegroundColor Green
                $launcherOk = Invoke-Launcher -RepoPath $repoPath -NonInteractive:$NonInteractive `
                    -ThemeName $ThemeName -Gui:$Gui -InstallFastfetch:$InstallFastfetch -InstallTopgrade:$InstallTopgrade
                if (-not $launcherOk) { throw 'Installation failed. Review messages above.' }
                return
            }
            Write-Host "Installed repository needs stable release update: $repoPath" -ForegroundColor Yellow
        } else {
            Write-Host "Directory exists but is not a valid repo: $repoPath" -ForegroundColor Yellow
        }
        $replaceChoice = Read-Host "Replace it? [Y/n]"
        if ($replaceChoice -eq 'n' -or $replaceChoice -eq 'N') {
            Write-Host "Installation cancelled. No changes were made." -ForegroundColor Yellow
            return
        }
    }

    # Explicit consent before download
    Write-Host ""
    $confirmChoice = Read-Host "Proceed with download and installation? [Y/n]"
    if ($confirmChoice -eq 'n' -or $confirmChoice -eq 'N') {
        Write-Host "Installation cancelled. No changes were made." -ForegroundColor Yellow
        return
    }
} else {
    # Headless mode - use defaults
    $repoPath = $repoDefaultDir
    if ((Test-Path $repoPath) -and (Test-IsValidRepo $repoPath)) {
        if (Test-RepoReleaseCurrent $repoPath) {
            $launcherOk = Invoke-Launcher -RepoPath $repoPath -NonInteractive:$NonInteractive `
                -ThemeName $ThemeName -Gui:$Gui -InstallFastfetch:$InstallFastfetch -InstallTopgrade:$InstallTopgrade
            if (-not $launcherOk) { throw 'Installation failed. Review messages above.' }
            return
        }
    }
}

# Download repository
$downloadOk = Download-Repo -TargetDir $repoPath
if (-not $downloadOk) {
    throw 'Installation aborted due to download failure.'
}

# Launch installer
$launcherOk = Invoke-Launcher -RepoPath $repoPath -NonInteractive:$NonInteractive `
    -ThemeName $ThemeName -Gui:$Gui -InstallFastfetch:$InstallFastfetch -InstallTopgrade:$InstallTopgrade
if (-not $launcherOk) { throw 'Installation failed. Review messages above.' }
