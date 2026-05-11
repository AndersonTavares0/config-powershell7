#Requires -Version 5.1
# ============================================================
# SETUP MODULE TESTS — TDD
# Tests: core.ps1, deps.ps1, profile.ps1, orchestrator.ps1
# ============================================================

param([switch]$Verbose)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0
$script:TestResults = [System.Collections.Generic.List[object]]::new()

function Test-Result {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Message
    )
    $script:TestResults.Add([PSCustomObject]@{
            Name    = $Name
            Passed  = $Passed
            Message = $Message
        })
    if ($Passed) {
        $script:TestsPassed++
        Write-Host "  PASS: $Name" -ForegroundColor Green
    }
    else {
        $script:TestsFailed++
        Write-Host "  FAIL: $Name - $Message" -ForegroundColor Red
    }
}

function Test-Skip {
    param([Parameter(Mandatory)][string]$Name, [string]$Reason = 'Skipped')
    $script:TestsSkipped++
    Write-Host "  SKIP: $Name - $Reason" -ForegroundColor Gray
}

function Assert-Equal {
    param($Expected, $Actual, [string]$TestName)
    $passed = $Expected -eq $Actual
    $msg = if (-not $passed) { "Expected: '$Expected', Got: '$Actual'" } else { "" }
    Test-Result -Name $TestName -Passed $passed -Message $msg
}

function Assert-True {
    param([bool]$Condition, [string]$TestName)
    $passed = $Condition -eq $true
    $msg = if (-not $passed) { "Condition was false" } else { "" }
    Test-Result -Name $TestName -Passed $passed -Message $msg
}

function Assert-NotNull {
    param($Value, [string]$TestName)
    $passed = $null -ne $Value
    $msg = if (-not $passed) { "Value was null" } else { "" }
    Test-Result -Name $TestName -Passed $passed -Message $msg
}

function Assert-False {
    param([bool]$Condition, [string]$TestName)
    $passed = $Condition -eq $false
    $msg = if (-not $passed) { "Condition was true" } else { "" }
    Test-Result -Name $TestName -Passed $passed -Message $msg
}

function New-MockDir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Remove-MockDir {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function New-MockFile {
    param([string]$Path, [string]$Content = "")
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Remove-MockFile {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item $Path -Force -ErrorAction SilentlyContinue
    }
}

# ── LOAD SETUP MODULES ──────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Module Tests" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$setupDir = Join-Path $PSScriptRoot '../setup'
$modulesDir = Join-Path $setupDir 'modules'

if (-not (Test-Path $modulesDir)) {
    Write-Host "Setup modules not found at $modulesDir" -ForegroundColor Red
    exit 1
}

. (Join-Path $modulesDir 'core.ps1')
. (Join-Path $modulesDir 'deps.ps1')
. (Join-Path $modulesDir 'profile.ps1')
. (Join-Path $modulesDir 'orchestrator.ps1')

Write-Host "Setup modules loaded.`n" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════
# TEST SUITE: CORE — Write-GuiLog
# ══════════════════════════════════════════════════════════════
Write-Host "Testing Write-GuiLog..." -ForegroundColor Yellow

$script:SyncHash = [hashtable]::Synchronized(@{
    LogMessages     = [System.Collections.Generic.List[object]]::new()
    InstallComplete = $false
    InstallFailed   = $false
    IsRunning       = $false
    Progress        = ''
})

Write-GuiLog "test message" -Type Info
Assert-True -Condition ($script:SyncHash.LogMessages.Count -eq 1) -TestName "Write-GuiLog adds to SyncHash"
Assert-Equal -Expected "test message" -Actual $script:SyncHash.LogMessages[0].Message -TestName "Write-GuiLog stores correct message"
Assert-Equal -Expected "Info" -Actual $script:SyncHash.LogMessages[0].Type -TestName "Write-GuiLog stores correct type"

Write-GuiLog "step msg" -Type Step
Assert-Equal -Expected "Step" -Actual $script:SyncHash.LogMessages[1].Type -TestName "Write-GuiLog handles Step type"

Write-GuiLog "ok msg" -Type Ok
Assert-Equal -Expected "Ok" -Actual $script:SyncHash.LogMessages[2].Type -TestName "Write-GuiLog handles Ok type"

Write-GuiLog "warn msg" -Type Warn
Assert-Equal -Expected "Warn" -Actual $script:SyncHash.LogMessages[3].Type -TestName "Write-GuiLog handles Warn type"

Write-GuiLog "fail msg" -Type Fail
Assert-Equal -Expected "Fail" -Actual $script:SyncHash.LogMessages[4].Type -TestName "Write-GuiLog handles Fail type"

# ══════════════════════════════════════════════════════════════
# TEST SUITE: CORE — Constants
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Core Constants..." -ForegroundColor Yellow

Assert-NotNull -Value $script:RepoOwner -TestName "RepoOwner is set"
Assert-NotNull -Value $script:RepoName -TestName "RepoName is set"
Assert-NotNull -Value $script:RepoZipUrl -TestName "RepoZipUrl is set"
Assert-True -Condition ($script:RepoZipUrl -match 'github\.com') -TestName "RepoZipUrl points to GitHub"

# ══════════════════════════════════════════════════════════════
# TEST SUITE: CORE — Get-WingetPath
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Get-WingetPath..." -ForegroundColor Yellow

$wingetPath = Get-WingetPath
if ($wingetPath) {
    Assert-True -Condition (Test-Path $wingetPath) -TestName "Get-WingetPath returns existing file"
} else {
    Test-Skip -Name "Get-WingetPath returns path" -Reason "winget not installed on this machine"
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: PROFILE — Get-ProfilePath
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Get-ProfilePath..." -ForegroundColor Yellow

$profilePath = Get-ProfilePath
Assert-NotNull -Value $profilePath -TestName "Get-ProfilePath returns non-null"

# ══════════════════════════════════════════════════════════════
# TEST SUITE: PROFILE — Install-Profile (mock)
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Install-Profile..." -ForegroundColor Yellow

$testRepoDir = Join-Path $env:TEMP "test-setup-repo-$(Get-Random)"
$testProfileDir = Join-Path $env:TEMP "test-setup-profile-$(Get-Random)"
$testProfilePath = Join-Path $testProfileDir "Microsoft.PowerShell_profile.ps1"

try {
    New-MockDir $testRepoDir
    New-MockDir (Join-Path $testRepoDir 'modules')
    New-MockFile (Join-Path $testRepoDir 'Microsoft.PowerShell_profile.ps1') '# profile'

    $originalProfile = $PROFILE
    $global:PROFILE = $testProfilePath

    $result = Install-Profile -RepoPath $testRepoDir
    Assert-True -Condition $result -TestName "Install-Profile returns true on success"
    Assert-True -Condition (Test-Path $testProfilePath) -TestName "Install-Profile creates profile file"

    $content = Get-Content $testProfilePath -Raw
    Assert-True -Condition ($content -match 'Microsoft\.PowerShell_profile\.ps1') -TestName "Profile contains dot-source reference"
    Assert-True -Condition ($content -match '__PROFILE_REPO_ROOT') -TestName "Profile sets __PROFILE_REPO_ROOT"

    $result2 = Install-Profile -RepoPath $testRepoDir
    Assert-True -Condition $result2 -TestName "Install-Profile idempotent (already linked)"

    $result3 = Install-Profile -RepoPath "C:\nonexistent-path-$(Get-Random)"
    Assert-False -Condition $result3 -TestName "Install-Profile returns false for missing repo"

} finally {
    Remove-MockDir $testRepoDir
    Remove-MockDir $testProfileDir
    $global:PROFILE = $originalProfile
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: PROFILE — Uninstall-Profile (mock)
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Uninstall-Profile..." -ForegroundColor Yellow

$testRepoDir2 = Join-Path $env:TEMP "test-setup-repo2-$(Get-Random)"
$testProfileDir2 = Join-Path $env:TEMP "test-setup-profile2-$(Get-Random)"
$testProfilePath2 = Join-Path $testProfileDir2 "Microsoft.PowerShell_profile.ps1"

try {
    New-MockDir $testRepoDir2
    New-MockDir (Join-Path $testRepoDir2 'modules')
    New-MockFile (Join-Path $testRepoDir2 'Microsoft.PowerShell_profile.ps1') '# profile'
    New-MockDir $testProfileDir2

    $originalProfile = $PROFILE
    $global:PROFILE = $testProfilePath2

    $linkContent = "# Generated by config-powershell7 installer`n`$env:__PROFILE_REPO_ROOT = `"$testRepoDir2`"`n. `"$testRepoDir2\Microsoft.PowerShell_profile.ps1`""
    Set-Content -Path $testProfilePath2 -Value $linkContent -Encoding UTF8 -Force

    $result = Uninstall-Profile -RepoPath $testRepoDir2
    Assert-True -Condition $result -TestName "Uninstall-Profile returns true"
    Assert-False -Condition (Test-Path $testProfilePath2) -TestName "Uninstall-Profile removes profile file"

} finally {
    Remove-MockDir $testRepoDir2
    Remove-MockDir $testProfileDir2
    $global:PROFILE = $originalProfile
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: DEPS — Install-WingetPackage (detection only)
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Winget Detection..." -ForegroundColor Yellow

$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
if ($wingetCmd -or $wingetPath) {
    Test-Result -Name "winget is available" -Passed $true -Message ""
} else {
    Test-Skip -Name "winget is available" -Reason "winget not installed"
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: DEPS — Install-PSModules (NuGet check)
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting PS Module Infrastructure..." -ForegroundColor Yellow

$nuGet = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
if ($nuGet) {
    Test-Result -Name "NuGet package provider is available" -Passed $true -Message ""
} else {
    Test-Skip -Name "NuGet package provider" -Reason "Not installed yet"
}

$gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
if ($gallery) {
    Test-Result -Name "PSGallery repository is accessible" -Passed $true -Message ""
} else {
    Test-Skip -Name "PSGallery repository" -Reason "Not accessible"
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: ORCHESTRATOR — Start-ProfileInstall (dry-run)
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Orchestrator..." -ForegroundColor Yellow

$testRepoDir3 = Join-Path $env:TEMP "test-setup-repo3-$(Get-Random)"
$testProfileDir3 = Join-Path $env:TEMP "test-setup-profile3-$(Get-Random)"
$testProfilePath3 = Join-Path $testProfileDir3 "Microsoft.PowerShell_profile.ps1"

try {
    New-MockDir $testRepoDir3
    New-MockDir (Join-Path $testRepoDir3 'modules')
    New-MockFile (Join-Path $testRepoDir3 'Microsoft.PowerShell_profile.ps1') '# profile'
    New-MockDir $testProfileDir3

    $originalProfile = $PROFILE
    $global:PROFILE = $testProfilePath3

    Start-ProfileInstall -RepoPath $testRepoDir3 `
        -InstallPS7 $false -InstallGit $false -InstallOMP $false `
        -InstallZoxide $false -InstallFont $false -InstallModules $false `
        -InstallAlacritty $false -InstallChocolatey $false -InstallScoop $false

    Assert-True -Condition (Test-Path $testProfilePath3) -TestName "Orchestrator creates profile link (dry-run)"

    $content = Get-Content $testProfilePath3 -Raw
    Assert-True -Condition ($content -match 'Microsoft\.PowerShell_profile\.ps1') -TestName "Orchestrator profile has dot-source"

} finally {
    Remove-MockDir $testRepoDir3
    Remove-MockDir $testProfileDir3
    $global:PROFILE = $originalProfile
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: DEPS — Set-WindowsTerminalFont
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Set-WindowsTerminalFont..." -ForegroundColor Yellow

$fontTestDir = Join-Path $env:TEMP "test-wt-font-$(Get-Random)"

try {
    New-MockDir $fontTestDir

    # Test 1: Updates font in valid settings.json
    $settings1 = @'
{
    "profiles": {
        "defaults": {
            "font": { "face": "Cascadia Code", "size": 11 }
        },
        "list": [
            { "guid": "...", "name": "PowerShell", "font": { "face": "Cascadia Code", "size": 11 } }
        ]
    }
}
'@
    $path1 = Join-Path $fontTestDir "settings1.json"
    New-MockFile $path1 $settings1
    Set-WindowsTerminalFont -SettingsPath $path1
    $result1 = Get-Content $path1 -Raw | ConvertFrom-Json
    Assert-Equal -Expected "FiraCode Nerd Font" -Actual $result1.profiles.defaults.font.face -TestName "Set-WindowsTerminalFont updates defaults font"

    # Test 2: Handles empty font object ({} with no 'face' property) — StrictMode crash guard
    $settings2 = @'
{
    "profiles": {
        "defaults": {
            "font": {}
        },
        "list": [
            { "guid": "...", "name": "PowerShell" }
        ]
    }
}
'@
    $path2 = Join-Path $fontTestDir "settings2.json"
    New-MockFile $path2 $settings2
    try {
        Set-WindowsTerminalFont -SettingsPath $path2
        $result2 = Get-Content $path2 -Raw | ConvertFrom-Json
        Assert-Equal -Expected "FiraCode Nerd Font" -Actual $result2.profiles.defaults.font.face -TestName "Set-WindowsTerminalFont handles empty font object"
    } catch {
        Test-Result -Name "Set-WindowsTerminalFont handles empty font object" -Passed $false -Message "Crash on empty font: $($_.Exception.Message)"
    }

    # Test 3: Handles missing profiles section gracefully
    $settings3 = '{}'
    $path3 = Join-Path $fontTestDir "settings3.json"
    New-MockFile $path3 $settings3
    Set-WindowsTerminalFont -SettingsPath $path3
    Assert-True -Condition (Test-Path $path3) -TestName "Set-WindowsTerminalFont does not corrupt file on missing profiles"

    # Test 4: Skips when already configured
    $settings4 = @'
{
    "profiles": {
        "defaults": {
            "font": { "face": "FiraCode Nerd Font", "size": 11 }
        }
    }
}
'@
    $path4 = Join-Path $fontTestDir "settings4.json"
    New-MockFile $path4 $settings4
    Set-WindowsTerminalFont -SettingsPath $path4
    $result4 = Get-Content $path4 -Raw | ConvertFrom-Json
    Assert-Equal -Expected "FiraCode Nerd Font" -Actual $result4.profiles.defaults.font.face -TestName "Set-WindowsTerminalFont skips when already configured"

    # Test 5: Updates per-profile font as well
    $settings5 = @'
{
    "profiles": {
        "defaults": {},
        "list": [
            { "guid": "a", "name": "PowerShell" },
            { "guid": "b", "name": "cmd" }
        ]
    }
}
'@
    $path5 = Join-Path $fontTestDir "settings5.json"
    New-MockFile $path5 $settings5
    Set-WindowsTerminalFont -SettingsPath $path5
    $result5 = Get-Content $path5 -Raw | ConvertFrom-Json
    Assert-Equal -Expected "FiraCode Nerd Font" -Actual $result5.profiles.list[0].font.face -TestName "Set-WindowsTerminalFont updates profile without font"
    Assert-Equal -Expected "FiraCode Nerd Font" -Actual $result5.profiles.list[1].font.face -TestName "Set-WindowsTerminalFont updates second profile"

} finally {
    Remove-MockDir $fontTestDir
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: DEPS — Install-Chocolatey admin check
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Install-Chocolatey admin detection..." -ForegroundColor Yellow

# Test: Non-admin returns false without crashing
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $result = Install-Chocolatey
    Assert-False -Condition $result -TestName "Install-Chocolatey returns false when not admin"
} else {
    Test-Skip -Name "Install-Chocolatey admin check" -Reason "Running as admin — cannot test non-admin path"
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: SYNTAX — All setup modules parse cleanly
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Setup Module Syntax..." -ForegroundColor Yellow

$ps1Files = Get-ChildItem -Path $modulesDir -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($file in $ps1Files) {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -eq 0) {
        Test-Result -Name "Syntax: $($file.Name)" -Passed $true -Message ""
    }
    else {
        $errMsg = ($errors | Select-Object -First 2 | ForEach-Object { "L$($_.Extent.StartLineNumber): $($_.Message)" }) -join '; '
        Test-Result -Name "Syntax: $($file.Name)" -Passed $false -Message $errMsg
    }
}

# ── TEST SUMMARY ──────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$totalTests = $script:TestsPassed + $script:TestsFailed
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed:      $script:TestsPassed" -ForegroundColor Green
Write-Host "Failed:      $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped:     $script:TestsSkipped" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

if ($script:TestResults.Count -gt 0 -and $Verbose) {
    Write-Host "Detailed Results:" -ForegroundColor Cyan
    $script:TestResults | Format-Table -AutoSize
}

if ($script:TestsFailed -gt 0) {
    exit 1
} else {
    exit 0
}
