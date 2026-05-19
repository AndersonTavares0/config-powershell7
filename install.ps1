#Requires -Version 5.1
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
<#
.SYNOPSIS
    Industrial-grade installer for the PowerShell Profile ecosystem.
.DESCRIPTION
    Cross-platform (Windows 10+ / Linux Fedora) installer with:
    - Idempotent execution (safe to run multiple times)
    - Dot-source profile linking (no symlinks, no UAC required)
    - Timestamped backups (never overwrites existing backups)
    - Dependency detection with graceful degradation
    - Post-installation validation
.EXAMPLE
    .\install.ps1

    pwsh ./install.ps1
.NOTES
    Revision: 05/2026 | License: MIT
#>

param(
    [switch]$NonInteractive
)

# ── STRICT MODE ──────────────────────────────────────────────
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── SHARED LIBS ──────────────────────────────────────────────
. (Join-Path $PSScriptRoot 'lib/platform.ps1')
. (Join-Path $PSScriptRoot 'lib/ux-helpers.ps1')
. (Join-Path $PSScriptRoot 'lib/profile-paths.ps1')

# ─ RESOLVE PATHS ────────────────────────────────────────────
$script:SourceProfile = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
$script:SourceModules = Join-Path $PSScriptRoot 'modules'

# Validate source files exist
if (-not (Test-Path $script:SourceProfile)) {
    Write-Fail "Microsoft.PowerShell_profile.ps1 not found in $PSScriptRoot"
    exit 1
}
if (-not (Test-Path $script:SourceModules)) {
    Write-Fail "modules/ directory not found in $PSScriptRoot"
    exit 1
}

# ── PERMANENT INSTALL LOCATION ───────────────────────────────
# If running from a temporary location (Desktop, Downloads, TEMP),
# copy files to a permanent location in Documents to avoid profile breakage.
$script:PermanentInstallDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'config-powershell7'

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

if (Test-IsTempLocation $PSScriptRoot) {
    Write-Step "Detected temporary location. Copying to permanent install directory..."
    try {
        if (Test-Path $script:PermanentInstallDir) {
            Remove-Item $script:PermanentInstallDir -Recurse -Force -ErrorAction Stop
        }
        Copy-Item -Path "$PSScriptRoot\*" -Destination $script:PermanentInstallDir -Recurse -Force -ErrorAction Stop
        Write-Ok "Files copied to: $script:PermanentInstallDir"
        
        # Update source paths to permanent location
        $script:SourceProfile = Join-Path $script:PermanentInstallDir 'Microsoft.PowerShell_profile.ps1'
        $script:SourceModules = Join-Path $script:PermanentInstallDir 'modules'
        $script:InstallRoot = $script:PermanentInstallDir
    } catch {
        Write-Warn "Failed to copy to permanent location: $($_.Exception.Message)"
        Write-Warn "Profile may break if source folder is deleted."
        $script:InstallRoot = $PSScriptRoot
    }
} else {
    $script:InstallRoot = $PSScriptRoot
}

# Resolve target profile path (cross-platform) — loaded from lib/profile-paths.ps1

$script:TargetProfile = script:Get-TargetProfilePath
$script:TargetDir     = Split-Path $script:TargetProfile -Parent

# ══════════════════════════════════════════════════════════════
# BANNER
# ══════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   PowerShell Profile Installer v2.0         ║" -ForegroundColor Cyan
Write-Host "  ║   Windows 10+ / Linux (Fedora)              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$platform = if ($script:IsWin) { "Windows" } else { "Linux" }
$adminTag = if ($script:IsAdmin) { " [ADMIN]" } else { "" }
Write-Info "Platform: $platform | PS $($PSVersionTable.PSVersion)$adminTag"
Write-Info "Source:   $script:InstallRoot"
Write-Info "Target:   $script:TargetProfile"
Write-Host ""

# ══════════════════════════════════════════════════════════════
# STEP 1: EXECUTION POLICY (Windows only)
# ══════════════════════════════════════════════════════════════
Write-Host "  [1/5] Checking ExecutionPolicy..." -ForegroundColor Cyan

if ($script:IsWin) {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
        Write-Step "Setting ExecutionPolicy to RemoteSigned for CurrentUser..."
        try {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
            Write-Ok "ExecutionPolicy set to RemoteSigned."
        } catch {
            Write-Fail "Could not set ExecutionPolicy: $($_.Exception.Message)"
            Write-Info "Run manually: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
            exit 1
        }
    } else {
        Write-Ok "ExecutionPolicy: $currentPolicy (OK)."
    }

    # Unblock downloaded files
    Write-Step "Unblocking script files..."
    Get-ChildItem -Path $script:InstallRoot -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
    Write-Ok "Files unblocked."
} else {
    Write-Ok "Skipped (not applicable on Linux)."
}

# ══════════════════════════════════════════════════════════════
# STEP 2: DEPENDENCY CHECK
# ══════════════════════════════════════════════════════════════
Write-Host "  [2/5] Checking dependencies..." -ForegroundColor Cyan

# Required
$psVer = $PSVersionTable.PSVersion
if ($psVer.Major -ge 7) {
    $msgOk = "PowerShell $psVer"
    Write-Ok $msgOk
} elseif ($psVer.Major -ge 5) {
    $msgWarn = "PowerShell $psVer (5.1 supported, but 7+ recommended)"
    Write-Warn $msgWarn
} else {
    $msgFail = "PowerShell $psVer is not supported. Requires 5.1+"
    Write-Fail $msgFail
    exit 1
}

# Optional dependencies
$optionalDeps = @(
    @{ Name = 'git';        Cmd = 'git';        Hint = 'Git aliases will be disabled' }
    @{ Name = 'oh-my-posh'; Cmd = 'oh-my-posh'; Hint = 'Prompt theming will be disabled' }
    @{ Name = 'zoxide';     Cmd = 'zoxide';      Hint = 'Smart navigation (z) will be disabled' }
)

foreach ($dep in $optionalDeps) {
    $found = Get-Command $dep.Cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Ok "$($dep.Name) found: $($found.Source)"
    } else {
        Write-Warn "$($dep.Name) not found — $($dep.Hint)"
    }
}

# Optional modules
$optionalModules = @('Terminal-Icons', 'PSReadLine')
foreach ($mod in $optionalModules) {
    if (Get-Module -ListAvailable -Name $mod -ErrorAction SilentlyContinue) {
        Write-Ok "Module $mod available."
    } else {
        Write-Warn "Module $mod not installed. Install with: Install-Module -Name $mod -Scope CurrentUser"
    }
}

# ══════════════════════════════════════════════════════════════
# STEP 3: BACKUP EXISTING PROFILE
# ══════════════════════════════════════════════════════════════
Write-Host "  [3/5] Managing existing profile..." -ForegroundColor Cyan

$script:NeedLink = -not (Test-Path $script:TargetProfile)

if (Test-Path $script:TargetProfile) {
    $content = Get-Content $script:TargetProfile -Raw -ErrorAction SilentlyContinue
    if ($content -match "\. `"[^`"]*Microsoft\.PowerShell_profile\.ps1`"") {
        Write-Ok "Profile is already correctly linked (dot-sourced)."
        $script:NeedLink = $false
    } else {
        # It's a different profile — back it up with unique timestamp
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = "$($script:TargetProfile).bak-$timestamp"

        # Safety: never overwrite existing backup
        if (Test-Path $backupPath) {
            $backupPath = "$($script:TargetProfile).bak-$timestamp-$(Get-Random -Maximum 9999)"
        }

        Write-Step "Backing up existing profile..."
        Copy-Item $script:TargetProfile $backupPath -Force
        Write-Ok "Backup created: $backupPath"

        # Remove the original to make way for new file
        Remove-Item $script:TargetProfile -Force
        $script:NeedLink = $true
    }
} else {
    Write-Info "No existing profile found. Clean install."
}

# ══════════════════════════════════════════════════════════════
# STEP 4: LINK PROFILE (DOT-SOURCE)
# ══════════════════════════════════════════════════════════════
Write-Host "  [4/5] Linking profile..." -ForegroundColor Cyan

if (-not $script:NeedLink) {
    Write-Ok "Profile already correctly linked — skipping."
} else {
    # Ensure target directory exists
    if (-not (Test-Path $script:TargetDir)) {
        Write-Step "Creating profile directory: $script:TargetDir"
        New-Item -ItemType Directory -Force -Path $script:TargetDir | Out-Null
    }

    try {
        # Create a profile that simply dot-sources our repository profile
        # This avoids all UAC requirements on Windows
        $linkContent = "# Generated by config-powershell7 installer`n`$env:__PROFILE_REPO_ROOT = `"$script:InstallRoot`"`n. `"$script:SourceProfile`""
        Set-Content -Path $script:TargetProfile -Value $linkContent -Encoding UTF8 -Force
        
        Write-Ok "Profile linked successfully: $script:TargetProfile"
        Write-Info "→ $script:SourceProfile"
    } catch {
        Write-Fail "Failed to link profile: $($_.Exception.Message)"
        exit 1
    }
}

# ══════════════════════════════════════════════════════════════
# STEP 5: POST-INSTALL VALIDATION
# ══════════════════════════════════════════════════════════════
Write-Host "  [5/5] Validating installation..." -ForegroundColor Cyan

$validationErrors = 0

# V1: Profile exists and points to our source
if (Test-Path $script:TargetProfile) {
    $content = Get-Content $script:TargetProfile -Raw -ErrorAction SilentlyContinue
    if ($content -match "\. `"[^`"]*Microsoft\.PowerShell_profile\.ps1`"") {
        Write-Ok "Profile link valid."
    } else {
        Write-Fail "Profile does not point to our script."
        $validationErrors++
    }
} else {
    Write-Fail "Profile validation failed."
    $validationErrors++
}

# V2: Source modules directory has expected structure
$expectedModules = @('cache', 'config', 'git', 'navigation', 'system', 'text_utils')
foreach ($mod in $expectedModules) {
    $modPath = Join-Path $script:SourceModules $mod
    if (Test-Path $modPath) {
        Write-Ok "Module directory: $mod/"
    } else {
        Write-Warn "Module directory missing: $mod/"
    }
}

# V3: Syntax validation of core files
$coreFiles = @(
    $script:SourceProfile
    (Join-Path $script:SourceModules 'config/config.ps1')
    (Join-Path $script:SourceModules 'cache/cache.ps1')
)
foreach ($file in $coreFiles) {
    if (Test-Path $file) {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors) | Out-Null
        $fileName = Split-Path $file -Leaf
        if ($errors.Count -eq 0) {
            Write-Ok "Syntax OK: $fileName"
        } else {
            Write-Fail "Syntax errors in $fileName"
            $validationErrors++
        }
    }
}

# ══════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════
Write-Host ""
if ($validationErrors -eq 0) {
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║   ✔ Installation Successful!                ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    $warnMsg = "⚠ Installed with $validationErrors warning(s)"
    $padded  = $warnMsg.PadRight(44)
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║   $padded║" -ForegroundColor Yellow
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Yellow
}
Write-Host ""
Write-Info "Profile:  $script:TargetProfile"
Write-Info "Source:   $script:SourceProfile"
Write-Host ""
Write-Host "  Restart your terminal to apply changes." -ForegroundColor White
Write-Host "  Run " -NoNewline -ForegroundColor White
Write-Host ".\tests\Test-ProfileInstallation.ps1" -NoNewline -ForegroundColor Yellow
Write-Host " after restart to verify." -ForegroundColor White
Write-Host ""

if ($Host.Name -match 'ConsoleHost' -and -not $NonInteractive) {
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}


