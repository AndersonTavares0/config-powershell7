<#
.SYNOPSIS
    Installs the PowerShell Profile by creating a symbolic link.
.DESCRIPTION
    Cross-platform installer that handles ExecutionPolicy and permissions safely.
#>

$ProfileFile = Join-Path $PSScriptRoot "Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $ProfileFile)) {
    Write-Error "Could not find Microsoft.PowerShell_profile.ps1 in $PSScriptRoot"
    exit 1
}

Write-Host "--- PowerShell Profile Installer ---" -ForegroundColor Cyan

# 1. Check ExecutionPolicy and set safely if needed
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if ($currentPolicy -eq 'Restricted') {
    Write-Host "Adjusting ExecutionPolicy for CurrentUser..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        Write-Host "ExecutionPolicy set to RemoteSigned (CurrentUser)." -ForegroundColor Green
    } catch {
        Write-Warning "Could not change ExecutionPolicy. You may need to run: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    }
}

# 2. Unblock files (Windows only)
$isWindowsInstall = $false
if ($PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell 6+: usa variável automática read-only $IsWindows
    $isWindowsInstall = $IsWindows
} else {
    # PS 5.1: fallback baseado em PSEdition (Desktop = Windows PowerShell)
    $isWindowsInstall = $PSVersionTable.PSEdition -eq 'Desktop'
}

if ($isWindowsInstall) {
    Write-Host "Unblocking script files... " -NoNewline
    Get-ChildItem -Path $PSScriptRoot -Filter *.ps1 -Recurse | Unblock-File
    Write-Host "Done." -ForegroundColor Green
}

# 3. Determine profile path cross-platform
if ($PROFILE.CurrentUserAllHosts) {
    $profilePath = $PROFILE.CurrentUserAllHosts
} else {
    # Fallback para Linux/macOS
    $profilePath = "~/.config/powershell/Microsoft.PowerShell_profile.ps1"
    $profilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($profilePath)
}

# 4. Create/Backup Profile
if (Test-Path $profilePath) {
    $choice = Read-Host "A profile already exists at $profilePath. Overwrite? [y/N]"
    if ($choice -ne 'y') {
        Write-Host "Installation aborted."
        exit 0
    }

    # Create backup
    $backupPath = "$profilePath.bak"
    Write-Host "Backing up existing profile to $backupPath..."
    Copy-Item $profilePath $backupPath -Force
}

# 5. Ensure target directory exists
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}

# 6. Create Symbolic Link (requires admin on Windows, not on Linux/macOS)
$isWindowsLink = $false
if ($PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell 6+: usa variável automática read-only $IsWindows
    $isWindowsLink = $IsWindows
} else {
    # PS 5.1: fallback baseado em PSEdition (Desktop = Windows PowerShell)
    $isWindowsLink = $PSVersionTable.PSEdition -eq 'Desktop'
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isWindowsLink -and -not $isAdmin) {
    Write-Warning "Admin privileges are required to create a Symbolic Link on Windows."
    Write-Host "Please restart this terminal as Administrator and run the script again."
    exit 1
}

Write-Host "Creating symbolic link at $profilePath..."
try {
    # Remove existing file/link first
    if (Test-Path $profilePath) {
        Remove-Item $profilePath -Force -ErrorAction SilentlyContinue
    }

    if ($isWindowsLink) {
        New-Item -ItemType SymbolicLink -Path $profilePath -Target $ProfileFile -Force | Out-Null
    } else {
        # Linux/macOS: use ln -s via bash
        & ln -sf $ProfileFile $profilePath 2>&1 | Out-Null
    }
    Write-Host "Symbolic link created successfully." -ForegroundColor Green
} catch {
    # Fallback: copy file instead of symlink
    Write-Warning "Could not create symbolic link. Copying file instead..."
    Copy-Item $ProfileFile $profilePath -Force
}

Write-Host "`nInstallation Successful!" -ForegroundColor Green
Write-Host "Please restart your terminal to apply the changes."
Write-Host "Profile location: $profilePath"