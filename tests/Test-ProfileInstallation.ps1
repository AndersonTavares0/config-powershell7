#Requires -Version 5.1
<#
.SYNOPSIS
    Post-installation validation for the PowerShell Profile ecosystem.
.DESCRIPTION
    Cross-platform post-installation validation with:
    - Profile link integrity checks
    - Module structure validation
    - Syntax verification of core files
    - Cache system validation
    - Dependency availability checks
    Can be run at any time to diagnose issues.
.EXAMPLE
    .\tests\Test-ProfileInstallation.ps1
    # Or after sourcing in profile:
    Test-ProfileInstallation
.OUTPUTS
    PSCustomObject with validation results.
.NOTES
    Revision: 05/2026 | Exit code 0 = all passed, 1 = failures detected.
#>

param(
    [switch]$Quiet,
    [switch]$Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── SHARED LIBS ──────────────────────────────────────────────
$script:LibPath = Join-Path $PSScriptRoot '../lib/platform.ps1'
if (Test-Path $script:LibPath) {
    . $script:LibPath
} else {
    # Fallback inline para quando executado isoladamente
    $script:IsWin = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }
    $script:IsLnx = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsLinux }   else { $false }
}

# ── TEST FRAMEWORK ───────────────────────────────────────────
$script:Results = [System.Collections.Generic.List[PSCustomObject]]::new()

function script:Add-Check {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Status,   # PASS, FAIL, WARN, SKIP
        [string]$Detail
    )
    $script:Results.Add([PSCustomObject]@{
        Category = $Category
        Name     = $Name
        Status   = $Status
        Detail   = $Detail
    })

    if (-not $Quiet) {
        $icon = switch ($Status) {
            'PASS' { '✔' }
            'FAIL' { '✗' }
            'WARN' { '⚠' }
            'SKIP' { '⊘' }
        }
        $color = switch ($Status) {
            'PASS' { 'Green' }
            'FAIL' { 'Red' }
            'WARN' { 'Yellow' }
            'SKIP' { 'Gray' }
        }
        Write-Host "  $icon " -ForegroundColor $color -NoNewline
        Write-Host "$Category/$Name" -ForegroundColor White -NoNewline
        if ($Detail) {
            Write-Host " — $Detail" -ForegroundColor DarkGray
        } else {
            Write-Host ""
        }
    }
}

# ══════════════════════════════════════════════════════════════
if (-not $Quiet) {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   Profile Installation Health Check          ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# ══════════════════════════════════════════════════════════════
# CATEGORY 1: PROFILE INTEGRITY
# ══════════════════════════════════════════════════════════════
if (-not $Quiet) { Write-Host "  Profile Integrity" -ForegroundColor Cyan }

$profilePath = $PROFILE
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

    if ($content -match "\. `"[^`"]*Microsoft\.PowerShell_profile\.ps1`"") {
        script:Add-Check 'Profile' 'Type' 'PASS' 'Profile dot-sources the config'
    } else {
        script:Add-Check 'Profile' 'Type' 'WARN' 'Profile does not seem to dot-source the repository config'
    }
} else {
    script:Add-Check 'Profile' 'Exists' 'FAIL' "No profile at $profilePath"
}

# ══════════════════════════════════════════════════════════════
# CATEGORY 2: MODULE SYNTAX VALIDATION
# ══════════════════════════════════════════════════════════════
if (-not $Quiet) { Write-Host "  Module Syntax" -ForegroundColor Cyan }

# Resolve module directory from profile content (dot-source path)
$moduleDir = $null
if (Test-Path $profilePath) {
    $profContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    # Try to extract __ProfileRepoRoot from the generated profile
    if ($profContent -match '\$global:__ProfileRepoRoot\s*=\s*"([^"]+)"') {
        $moduleDir = Join-Path $Matches[1] 'modules'
    } else {
        # Fallback: resolve from profile path itself
        $moduleDir = Join-Path (Split-Path $profilePath) 'modules'
    }
}

if ($moduleDir -and (Test-Path $moduleDir)) {
    $ps1Files = Get-ChildItem -Path $moduleDir -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $ps1Files) {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count -eq 0) {
            script:Add-Check 'Syntax' $file.Name 'PASS' ''
        } else {
            $errMsg = ($errors | Select-Object -First 2 | ForEach-Object { "L$($_.Extent.StartLineNumber): $($_.Message)" }) -join '; '
            script:Add-Check 'Syntax' $file.Name 'FAIL' $errMsg
        }
    }
} else {
    script:Add-Check 'Syntax' 'ModuleDir' 'FAIL' "modules/ directory not found"
}

# ══════════════════════════════════════════════════════════════
# CATEGORY 3: PROFILE LOAD TEST
# ══════════════════════════════════════════════════════════════
if (-not $Quiet) { Write-Host "  Profile Loading" -ForegroundColor Cyan }

$loadTimer = [System.Diagnostics.Stopwatch]::StartNew()
$loadError = $null
try {
    $global:ProfileLoaded = $false
    . $profilePath 2>$null
    $loadTimer.Stop()
    $loadMs = [math]::Round($loadTimer.Elapsed.TotalMilliseconds, 0)
    script:Add-Check 'Load' 'ProfileSource' 'PASS' "Loaded in ${loadMs}ms"

    if ($loadMs -lt 200) {
        script:Add-Check 'Load' 'Performance' 'PASS' "${loadMs}ms < 200ms target"
    } elseif ($loadMs -lt 400) {
        script:Add-Check 'Load' 'Performance' 'WARN' "${loadMs}ms (target: < 200ms)"
    } else {
        script:Add-Check 'Load' 'Performance' 'FAIL' "${loadMs}ms exceeds 400ms threshold"
    }
} catch {
    $loadTimer.Stop()
    $loadError = $_.Exception.Message
    script:Add-Check 'Load' 'ProfileSource' 'FAIL' $loadError
}

# ══════════════════════════════════════════════════════════════
# CATEGORY 4: FUNCTION & ALIAS AVAILABILITY
# ══════════════════════════════════════════════════════════════
if (-not $Quiet) { Write-Host "  Functions & Aliases" -ForegroundColor Cyan }

# Core functions that must always exist
$coreFunctions = @(
    'Clear-PluginCache', 'Import-TerminalIcons',
    'docs', 'dtop', 'home', 'up', 'up2', 'la', 'll', 'mkcd', 'nf',
    'touch', 'which', 'unzip', 'head', 'tail', 'grep', 'Copy-ToClipboard', 'pst', 'sed',
    'pkill', 'pgrep', 'flushdns', 'df', 'pubip', 'sysinfo', 'sudo'
)

foreach ($fn in $coreFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        script:Add-Check 'Function' $fn 'PASS' ''
    } else {
        script:Add-Check 'Function' $fn 'FAIL' 'Not defined'
    }
}

# Core aliases
$coreAliases = @(
    @{ Alias = 'Clear-Cache'; Target = 'Clear-PluginCache' }
    @{ Alias = 'icons';       Target = 'Import-TerminalIcons' }
    @{ Alias = 'cpy';         Target = 'Copy-ToClipboard' }
    @{ Alias = 'k9';          Target = 'pkill' }
)

foreach ($a in $coreAliases) {
    $cmd = Get-Command $a.Alias -ErrorAction SilentlyContinue
    if ($cmd) {
        script:Add-Check 'Alias' $a.Alias 'PASS' "→ $($a.Target)"
    } else {
        script:Add-Check 'Alias' $a.Alias 'FAIL' 'Not defined'
    }
}

# Git functions (conditional — only if git is installed)
$gitAvailable = Get-Command git -ErrorAction SilentlyContinue
if ($gitAvailable) {
    $gitFunctions = @('gst', 'ga', 'gcmt', 'gco', 'gpush', 'gpull', 'glog', 'gundo', 'gdiff', 'gcl', 'gcom', 'lazyg')
    foreach ($fn in $gitFunctions) {
        if (Get-Command $fn -ErrorAction SilentlyContinue) {
            script:Add-Check 'Git' $fn 'PASS' ''
        } else {
            script:Add-Check 'Git' $fn 'FAIL' 'Not defined'
        }
    }
} else {
    script:Add-Check 'Git' 'Available' 'SKIP' 'Git not installed — Git functions not expected'
}

# ══════════════════════════════════════════════════════════════
# CATEGORY 5: CONFIG SYSTEM
# ══════════════════════════════════════════════════════════════
if (-not $Quiet) { Write-Host "  Config System" -ForegroundColor Cyan }

if (Get-Variable -Name 'Config' -Scope Script -ErrorAction SilentlyContinue) {
    script:Add-Check 'Config' 'Object' 'PASS' 'Exists'

    $configProps = @('IsWindows', 'IsLinux', 'IsMacOS', 'IsAdmin', 'PSMajor', 'CachePath', 'ThemePath', 'CacheTTLMinutes')
    foreach ($prop in $configProps) {
        if ($null -ne $script:Config.$prop) {
            script:Add-Check 'Config' $prop 'PASS' "$($script:Config.$prop)"
        } else {
            script:Add-Check 'Config' $prop 'FAIL' 'Property is null'
        }
    }
} else {
    script:Add-Check 'Config' 'Object' 'FAIL' '$script:Config not found — config module may have failed to load'
}

# ══════════════════════════════════════════════════════════════
# CATEGORY 6: CACHE SYSTEM
# ══════════════════════════════════════════════════════════════
if (-not $Quiet) { Write-Host "  Cache System" -ForegroundColor Cyan }

$cachePath = if (Get-Variable -Name 'Config' -Scope Script -ErrorAction SilentlyContinue) { $script:Config.CachePath } else { Join-Path $HOME '.cache_pwsh_plugins.ps1' }

if (Test-Path $cachePath) {
    script:Add-Check 'Cache' 'FileExists' 'PASS' $cachePath
    $header = Get-Content $cachePath -TotalCount 1 -ErrorAction SilentlyContinue
    if ($header -match '^# fp:(\S+)\s+ts:(\d+)$') {
        $fp = $Matches[1]
        $ts = [DateTimeOffset]::FromUnixTimeSeconds([long]$Matches[2]).LocalDateTime
        script:Add-Check 'Cache' 'TTLHeader' 'PASS' "fp=$($fp.Substring(0,8))... ts=$($ts.ToString('yyyy-MM-dd HH:mm'))"
    } elseif ($header -match '^# fp:') {
        script:Add-Check 'Cache' 'TTLHeader' 'WARN' 'Old format without timestamp — will rebuild on next boot'
    } else {
        script:Add-Check 'Cache' 'TTLHeader' 'FAIL' 'Invalid cache header'
    }
} else {
    script:Add-Check 'Cache' 'FileExists' 'WARN' 'Cache not found — will be created on next boot'
}

# ══════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════
$passed = @($script:Results | Where-Object { $_.Status -eq 'PASS' }).Count
$failed = @($script:Results | Where-Object { $_.Status -eq 'FAIL' }).Count
$warned = @($script:Results | Where-Object { $_.Status -eq 'WARN' }).Count
$skipped = @($script:Results | Where-Object { $_.Status -eq 'SKIP' }).Count
$total  = $script:Results.Count

if (-not $Quiet) {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Results: $passed PASS, $failed FAIL, $warned WARN, $skipped SKIP ($total total)" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "  ════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

if ($Detailed) {
    $script:Results | Format-Table Category, Name, Status, Detail -AutoSize
}

# Return structured result
[PSCustomObject]@{
    Passed  = $passed
    Failed  = $failed
    Warned  = $warned
    Skipped = $skipped
    Total   = $total
    Results = $script:Results
}

if ($failed -gt 0) { exit 1 } else { exit 0 }

