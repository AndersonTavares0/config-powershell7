<#
.SYNOPSIS
    Installs the PowerShell Profile by creating a symbolic link.
#>

$ProfileFile = Join-Path $PSScriptRoot "Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $ProfileFile)) {
    Write-Error "Could not find Microsoft.PowerShell_profile.ps1 in $PSScriptRoot"
    exit 1
}

Write-Host "--- PowerShell Profile Installer ---" -ForegroundColor Cyan

# 1. Check for Admin (required for Symbolic Links)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Admin privileges are required to create a Symbolic Link."
    Write-Host "Please restart this terminal as Administrator and run the script again."
    exit 1
}

# 2. Unblock files
Write-Host "Unblocking script files..." -NoNewline
Get-ChildItem -Path $PSScriptRoot -Filter *.ps1 -Recurse | Unblock-File
Write-Host " Done." -ForegroundColor Green

# 3. Create/Backup Profile
if (Test-Path $PROFILE) {
    $choice = Read-Host "A profile already exists at $PROFILE. Overwrite? [y/N]"
    if ($choice -ne 'y') {
        Write-Host "Installation aborted."
        exit 0
    }
    
    # Create backup
    $backupPath = "$PROFILE.bak"
    Write-Host "Backing up existing profile to $backupPath..."
    Copy-Item $PROFILE $backupPath -Force
}

# 4. Create Symbolic Link
Write-Host "Creating symbolic link..."
New-Item -ItemType SymbolicLink -Path $PROFILE -Target $ProfileFile -Force | Out-Null

Write-Host "`nInstallation Successful!" -ForegroundColor Green
Write-Host "Please restart your terminal to apply the changes."
