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
    [switch]$InstallAlacritty
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
    Write-Host "This installer supports Windows 10/11 x64 only." -ForegroundColor Red
    return
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
        [switch]$InstallAlacritty
    )
    $setupEntryPoint = Join-Path $RepoPath 'setup\setup.ps1'
    if (-not (Test-Path $setupEntryPoint)) {
        Write-Host "Setup directory not found. The repository may be outdated." -ForegroundColor Red
        return $false
    }

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
        $pwshPath = if ($pwshCommand) { $pwshCommand.Source } else { Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe' }
        if (-not (Test-Path $pwshPath -PathType Leaf)) {
            $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
            $wingetPath = if ($wingetCommand) { $wingetCommand.Source } else {
                Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\WindowsApps\winget.exe'
            }
            if (-not (Test-Path $wingetPath -PathType Leaf)) {
                Write-Host 'PowerShell 7 and WinGet are unavailable. Install PowerShell 7, then retry.' -ForegroundColor Red
                return $false
            }
            Write-Host 'Installing PowerShell 7 before configuring its profile...' -ForegroundColor Cyan
            & $wingetPath install --id Microsoft.PowerShell --exact --source winget --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $pwshPath -PathType Leaf)) {
                Write-Host 'PowerShell 7 installation failed.' -ForegroundColor Red
                return $false
            }
        }

        $launcherArgs = @('-NoProfile', '-File', $setupEntryPoint, '-RepoPath', $RepoPath)
        if ($NonInteractive) { $launcherArgs += '-NonInteractive' }
        if ($ThemeName) { $launcherArgs += @('-ThemeName', $ThemeName) }
        if ($InstallAlacritty) { $launcherArgs += '-InstallAlacritty' }
        & $pwshPath @launcherArgs
        return $LASTEXITCODE -eq 0
    }
    . $setupEntryPoint -RepoPath $RepoPath -NonInteractive:$NonInteractive `
        -ThemeName $ThemeName -InstallAlacritty:$InstallAlacritty
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

    try {
        $TargetDir = [System.IO.Path]::GetFullPath($TargetDir)
        $parentDir = Split-Path $TargetDir -Parent
        $id = [guid]::NewGuid().ToString('N')
        $extractDir = Join-Path $parentDir ".$repoName-stage-$id"
        $previousDir = Join-Path $parentDir ".$repoName-previous-$id"
        Write-Host "Resolving latest stable release..." -ForegroundColor Cyan
        $release = Get-LatestRepoRelease

        Write-Host "Downloading release $($release.tag_name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $release.zipball_url -OutFile $zipPath -ErrorAction Stop

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
        -ThemeName $ThemeName -InstallAlacritty:$InstallAlacritty
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
    Write-Host "  - Alacritty; optional terminal themes, Topgrade, Scoop" -ForegroundColor Gray
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
                    -ThemeName $ThemeName -InstallAlacritty:$InstallAlacritty
                if (-not $launcherOk) { throw 'Installation failed. Review messages above.' }
                return
            }
            Write-Host "Installed repository needs stable release update: $repoPath" -ForegroundColor Yellow
        }
        # Directory exists but is not a valid repo - ask before replacing
        Write-Host "Directory exists but is not a valid repo: $repoPath" -ForegroundColor Yellow
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
    if (Test-Path $repoPath -and (Test-IsValidRepo $repoPath)) {
        if (Test-RepoReleaseCurrent $repoPath) {
            $launcherOk = Invoke-Launcher -RepoPath $repoPath -NonInteractive:$NonInteractive `
                -ThemeName $ThemeName -InstallAlacritty:$InstallAlacritty
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
    -ThemeName $ThemeName -InstallAlacritty:$InstallAlacritty
if (-not $launcherOk) { throw 'Installation failed. Review messages above.' }
