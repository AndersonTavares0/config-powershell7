#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrapper for the PowerShell 7 Profile ecosystem.
.DESCRIPTION
    Acquires the repository (local or remote) and launches the installer.

    Remote flow (irm | iex):
        - Shows summary of what the installer does
        - Asks for install directory (default: ~/Documents/config-powershell7)
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
    No admin elevation required.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [switch]$NonInteractive
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
    Write-Host "This installer is for Windows only. For Linux, use install.ps1." -ForegroundColor Red
    return
}

# Constants
$repoOwner   = 'AndersonTavares0'
$repoName    = 'config-powershell7'
$repoBranch  = 'main'
$repoZipUrl  = "https://github.com/$repoOwner/$repoName/archive/refs/heads/$repoBranch.zip"
$repoDefaultDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $repoName

# Helpers

function Test-IsValidRepo {
    param([string]$Path)
    return (Test-Path (Join-Path $Path 'Microsoft.PowerShell_profile.ps1'))
}

function Invoke-Launcher {
    param([string]$RepoPath)
    $setupEntryPoint = Join-Path $RepoPath 'setup\setup.ps1'
    if (-not (Test-Path $setupEntryPoint)) {
        Write-Host "Setup directory not found. The repository may be outdated." -ForegroundColor Red
        return
    }
    . $setupEntryPoint -RepoPath $RepoPath
}

function Download-Repo {
    param([string]$TargetDir)

    $zipPath    = Join-Path $env:TEMP "$repoName.zip"
    $extractDir = Join-Path $env:TEMP "$repoName-extract"

    try {
        Write-Host "Downloading repository..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $repoZipUrl -OutFile $zipPath -ErrorAction Stop

        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue }

        # Ensure parent directory exists before extraction
        $parentDir = Split-Path $TargetDir -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
        }

        if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

        $innerDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
        if ($innerDir) {
            Move-Item $innerDir.FullName $TargetDir -Force
        } else {
            Move-Item $extractDir $TargetDir -Force
        }

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Unblocking script files..." -ForegroundColor Cyan
        Get-ChildItem -Path $TargetDir -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
        Write-Host "Files unblocked." -ForegroundColor Green

        Write-Host "Repository downloaded to: $TargetDir" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Failed to download repository: $($_.Exception.Message)" -ForegroundColor Red
        # Clean up partial download
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
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
    Invoke-Launcher -RepoPath $localRepoPath
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
    Write-Host "  - Optional: Alacritty, terminal themes, Topgrade, Scoop" -ForegroundColor Gray
    Write-Host ""

    # Ask install directory
    Write-Host "Install directory [$repoDefaultDir]:" -ForegroundColor Cyan
    $userDir = Read-Host ""
    $userDir = $userDir.Trim()
    if ([string]::IsNullOrWhiteSpace($userDir)) {
        $repoPath = $repoDefaultDir
    } else {
        $repoPath = $userDir
    }

    # Check if directory exists
    if (Test-Path $repoPath) {
        if (Test-IsValidRepo $repoPath) {
            # Valid repo already exists - skip download, go straight to launcher
            Write-Host "Repository found at: $repoPath" -ForegroundColor Green
            Write-Host "Launching installer..." -ForegroundColor Cyan
            Invoke-Launcher -RepoPath $repoPath
            return
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
        Invoke-Launcher -RepoPath $repoPath
        return
    }
}

# Download repository
$downloadOk = Download-Repo -TargetDir $repoPath
if (-not $downloadOk) {
    Write-Host "Installation aborted due to download failure." -ForegroundColor Red
    return
}

# Launch installer
Invoke-Launcher -RepoPath $repoPath
