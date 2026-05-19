#Requires -Version 5.1
<#
.SYNOPSIS
    GUI installer for the PowerShell 7 Profile ecosystem.
.DESCRIPTION
    One-click setup that installs ALL requirements (PowerShell 7, Git,
    Oh My Posh, Zoxide, Nerd Font, PS modules) and configures the profile.

    Invoke remotely (no clone needed):
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
param()

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
$repoOwner  = 'AndersonTavares0'
$repoName   = 'config-powershell7'
$repoBranch = 'main'
$repoZipUrl = "https://github.com/$repoOwner/$repoName/archive/refs/heads/$repoBranch.zip"
$repoDefaultDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $repoName

# Resolve repo path
function Resolve-RepoPath {
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'))) {
        return $PSScriptRoot
    }
    $defaultPath = $repoDefaultDir
    if (Test-Path (Join-Path $defaultPath 'Microsoft.PowerShell_profile.ps1')) {
        return $defaultPath
    }
    return $null
}

$repoPath = Resolve-RepoPath

# Detect temporary locations where users commonly extract ZIPs
$tempLocations = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('MyDocuments'),
    [Environment]::GetFolderPath('Downloads'),
    $env:TEMP,
    $env:TMP
) | Where-Object { $_ }

function Test-IsTempLocation {
    param([string]$Path)
    foreach ($temp in $tempLocations) {
        if ($Path -like "$temp*") { return $true }
    }
    return $false
}

# If running from a temporary location, copy to permanent install dir
if ($repoPath -and (Test-IsTempLocation $repoPath)) {
    Write-Host "Detected temporary install location. Copying to permanent directory..." -ForegroundColor Yellow
    $permanentPath = $repoDefaultDir
    
    try {
        if (Test-Path $permanentPath) {
            Remove-Item $permanentPath -Recurse -Force -ErrorAction Stop
        }
        Copy-Item -Path "$repoPath\*" -Destination $permanentPath -Recurse -Force -ErrorAction Stop
        Write-Host "Files copied to: $permanentPath" -ForegroundColor Green
        $repoPath = $permanentPath
    } catch {
        Write-Host "Failed to copy to permanent location: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Continuing with temporary location (profile may break if folder is deleted)." -ForegroundColor Yellow
    }
}

# Unblock files in existing repo (covers git clone or manual copy)
if ($repoPath) {
    Write-Host "Unblocking script files..." -ForegroundColor Cyan
    Get-ChildItem -Path $repoPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
    Write-Host "Files unblocked." -ForegroundColor Green
}

# Download repo if not found
if (-not $repoPath) {
    $repoPath = $repoDefaultDir
    Write-Host "Downloading repository..." -ForegroundColor Cyan

    $zipPath = Join-Path $env:TEMP "$repoName.zip"
    $extractDir = Join-Path $env:TEMP "$repoName-extract"

    try {
        Invoke-WebRequest -Uri $repoZipUrl -OutFile $zipPath -ErrorAction Stop

        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $repoPath) { Remove-Item $repoPath -Recurse -Force -ErrorAction SilentlyContinue }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

        $innerDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
        if ($innerDir) {
            Move-Item $innerDir.FullName $repoPath -Force
        } else {
            Move-Item $extractDir $repoPath -Force
        }

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

        # Unblock downloaded files to avoid ExecutionPolicy errors
        Write-Host "Unblocking script files..." -ForegroundColor Cyan
        Get-ChildItem -Path $repoPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
        Write-Host "Files unblocked." -ForegroundColor Green

        Write-Host "Repository downloaded to: $repoPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download repository: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
}

# Delegate to setup modules
$setupEntryPoint = Join-Path $repoPath 'setup\setup.ps1'
if (-not (Test-Path $setupEntryPoint)) {
    Write-Host "Setup directory not found. The repository may be outdated." -ForegroundColor Red
    return
}

. $setupEntryPoint -RepoPath $repoPath
