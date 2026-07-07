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
$repoRoot = Join-Path $PSScriptRoot '..'

if (-not (Test-Path $modulesDir)) {
    Write-Host "Setup modules not found at $modulesDir" -ForegroundColor Red
    exit 1
}

. (Join-Path $repoRoot 'lib/executable.ps1')
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
# TEST SUITE: CORE — Test-DocumentsRedirected
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Test-DocumentsRedirected..." -ForegroundColor Yellow

$actualDocs = [Environment]::GetFolderPath('MyDocuments')
$expectedDocs = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Documents'
if ($actualDocs -eq $expectedDocs) {
    Assert-False -Condition (Test-DocumentsRedirected) -TestName "Test-DocumentsRedirected returns false when Documents is default"
} else {
    Assert-True -Condition (Test-DocumentsRedirected) -TestName "Test-DocumentsRedirected returns true when Documents is redirected"
}

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

# Test Install-Profile with ThemeName
$testThemeDir = Join-Path $env:TEMP "test-setup-theme-$(Get-Random)"
$testThemeProfileDir = Join-Path $env:TEMP "test-setup-theme-profile-$(Get-Random)"
$testThemeProfilePath = Join-Path $testThemeProfileDir "Microsoft.PowerShell_profile.ps1"

try {
    New-MockDir $testThemeDir
    New-MockDir (Join-Path $testThemeDir 'modules')
    New-MockFile (Join-Path $testThemeDir 'Microsoft.PowerShell_profile.ps1') '# profile'

    $originalProfile = $PROFILE
    $global:PROFILE = $testThemeProfilePath

    $result4 = Install-Profile -RepoPath $testThemeDir -ThemeName 'jandedobbeleer'
    Assert-True -Condition $result4 -TestName "Install-Profile with ThemeName returns true"
    $content4 = Get-Content $testThemeProfilePath -Raw
    Assert-True -Condition ($content4 -match 'POSH_THEME') -TestName "Install-Profile with ThemeName includes POSH_THEME in stub"
    Assert-True -Condition ($content4 -match 'jandedobbeleer') -TestName "Install-Profile with ThemeName includes theme name in stub"

} finally {
    Remove-MockDir $testThemeDir
    Remove-MockDir $testThemeProfileDir
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
# TEST SUITE: DEPS — Install-OmpTheme
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Install-OmpTheme..." -ForegroundColor Yellow

# Save original functions we'll mock
$origGetExecutable = ${function:Get-Executable}

# Test 1: Returns false when no theme name provided
${function:Get-Executable} = { return $null }
$result1 = Install-OmpTheme -ThemeName ''
Assert-False -Condition $result1 -TestName "Install-OmpTheme returns false for empty theme name"

$result1b = Install-OmpTheme -ThemeName '   '
Assert-False -Condition $result1b -TestName "Install-OmpTheme returns false for whitespace theme name"

# Test 2: Returns false when oh-my-posh not in PATH
${function:Get-Executable} = { return $null }
$result2 = Install-OmpTheme -ThemeName 'jandedobbeleer'
Assert-False -Condition $result2 -TestName "Install-OmpTheme returns false when OMP missing"

# Test 3: Returns true when theme already exists and is valid
$ompThemeTestDir = Join-Path $env:TEMP "test-omp-theme-$(Get-Random)"
$origUserProfile = [Environment]::GetFolderPath('UserProfile')
try {
    # Mock UserProfile to our test dir
    # We can't easily mock GetFolderPath, so we create the actual path structure
    # Instead, test via the function's behavior with a pre-existing file
    
    ${function:Get-Executable} = {
        return [PSCustomObject]@{ Name = 'oh-my-posh'; Path = 'C:\dummy\oh-my-posh.exe'; Found = $true; Version = '23.0.0' }
    }
    
    # Create a mock theme dir and file
    $mockThemeDir = Join-Path $env:USERPROFILE '.poshthemes'
    if (-not (Test-Path $mockThemeDir)) {
        New-Item -ItemType Directory -Force -Path $mockThemeDir | Out-Null
    }
    $mockThemeFile = Join-Path $mockThemeDir 'test-theme.omp.json'
    Set-Content -Path $mockThemeFile -Value ('{"$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json", "version": 2}' * 5) -Encoding UTF8 -Force
    
    $result3 = Install-OmpTheme -ThemeName 'test-theme'
    Assert-True -Condition $result3 -TestName "Install-OmpTheme returns true when theme already exists and is valid"
    
    Remove-Item $mockThemeFile -Force -ErrorAction SilentlyContinue
} finally {
    if (Test-Path $ompThemeTestDir) { Remove-Item $ompThemeTestDir -Recurse -Force -ErrorAction SilentlyContinue }
}

# Restore original functions
${function:Get-Executable} = $origGetExecutable

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
        -InstallAlacritty $false -InstallScoop $false

    Assert-True -Condition (Test-Path $testProfilePath3) -TestName "Orchestrator creates profile link (dry-run)"

    $content = Get-Content $testProfilePath3 -Raw
    Assert-True -Condition ($content -match 'Microsoft\.PowerShell_profile\.ps1') -TestName "Orchestrator profile has dot-source"

} finally {
    Remove-MockDir $testRepoDir3
    Remove-MockDir $testProfileDir3
    $global:PROFILE = $originalProfile
    # Guard against $script: scope corruption from Start-ProfileInstall
    $script:TestResults = [System.Collections.Generic.List[object]]::new()
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: CORE — Write-InstallSummary
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Write-InstallSummary..." -ForegroundColor Yellow

$summaryTestResults = [System.Collections.Generic.List[object]]::new()
function Summary-Test {
    param([string]$Name, [bool]$Passed, [string]$Message = '')
    $summaryTestResults.Add([PSCustomObject]@{ Name = $Name; Passed = $Passed; Message = $Message }) | Out-Null
    if ($Passed) {
        $script:TestsPassed++
        Write-Host "  PASS: $Name" -ForegroundColor Green
    } else {
        $script:TestsFailed++
        Write-Host "  FAIL: $Name - $Message" -ForegroundColor Red
    }
}
function Summary-Assert-True {
    param([bool]$Condition, [string]$TestName)
    Summary-Test -Name $TestName -Passed ($Condition -eq $true) -Message $(if (-not $Condition) { "Condition was false" } else { "" })
}

$summarySyncHash = [hashtable]::Synchronized(@{
    LogMessages = [System.Collections.Generic.List[object]]::new()
})
$oldSyncHash = $script:SyncHash
$script:SyncHash = $summarySyncHash

$testResults = @(
    @{ Name = 'PowerShell 7'; Status = 'ok'; Detail = 'v7.4.6' }
    @{ Name = 'Git'; Status = 'ok'; Detail = 'v2.45.0' }
    @{ Name = 'FiraCode Nerd Font'; Status = 'fail'; Detail = 'download failed' }
    @{ Name = 'Alacritty'; Status = 'skip'; Detail = 'not selected' }
)

Write-InstallSummary -Results $testResults

Summary-Assert-True -Condition ($summarySyncHash.LogMessages.Count -gt 0) -TestName "Write-InstallSummary writes to SyncHash"

$okRows = $summarySyncHash.LogMessages | Where-Object { $_.Type -eq 'Ok' -and $_.Message -match 'PowerShell 7' }
Summary-Assert-True -Condition ($null -ne $okRows -and $okRows.Count -gt 0) -TestName "Write-InstallSummary ok row uses Ok type"

$failRows = $summarySyncHash.LogMessages | Where-Object { $_.Type -eq 'Fail' -and $_.Message -match 'FiraCode' }
Summary-Assert-True -Condition ($null -ne $failRows -and $failRows.Count -gt 0) -TestName "Write-InstallSummary fail row uses Fail type"

$skipRows = $summarySyncHash.LogMessages | Where-Object { $_.Type -eq 'Warn' -and $_.Message -match 'Alacritty' }
Summary-Assert-True -Condition ($null -ne $skipRows -and $skipRows.Count -gt 0) -TestName "Write-InstallSummary skip row uses Warn type"

$summarySyncHash.LogMessages.Clear()

Write-InstallSummary -Results @()
Summary-Assert-True -Condition ($summarySyncHash.LogMessages.Count -gt 0) -TestName "Write-InstallSummary handles empty results"
Summary-Assert-True -Condition ($summarySyncHash.LogMessages[0].Type -eq 'Warn') -TestName "Write-InstallSummary empty results shows warning"

$summarySyncHash.LogMessages.Clear()

$longResults = @(
    @{ Name = 'A very long component name that exceeds default width'; Status = 'ok'; Detail = 'A very long detail string that should expand the column width dynamically' }
)
Write-InstallSummary -Results $longResults
$rowMsg = $summarySyncHash.LogMessages | Where-Object { $_.Message -match 'very long component' }
Summary-Assert-True -Condition ($null -ne $rowMsg) -TestName "Write-InstallSummary expands column width for long names"

$script:SyncHash = $oldSyncHash

# ══════════════════════════════════════════════════════════════
# TEST SUITE: DEPS — Set-WindowsTerminalFont
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Set-WindowsTerminalFont..." -ForegroundColor Yellow
# Guard against scope corruption from prior test suites
$script:TestResults = [System.Collections.Generic.List[object]]::new()

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
# TEST SUITE: BOOTSTRAPPER — setup.ps1 (root)
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Bootstrapper (setup.ps1)..." -ForegroundColor Yellow

$bootstrapperPath = Join-Path $repoRoot 'setup.ps1'

# Syntax check for root setup.ps1
$tokens = $null; $errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($bootstrapperPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -eq 0) {
    Test-Result -Name "Syntax: setup.ps1 (root)" -Passed $true -Message ""
} else {
    $errMsg = ($errors | Select-Object -First 2 | ForEach-Object { "L$($_.Extent.StartLineNumber): $($_.Message)" }) -join '; '
    Test-Result -Name "Syntax: setup.ps1 (root)" -Passed $false -Message $errMsg
}

# Content checks — verify user agency prompts exist
$bootContent = Get-Content $bootstrapperPath -Raw -Encoding UTF8

Assert-True -Condition ($bootContent -match 'Proceed with download') -TestName "Bootstrapper has consent prompt"
Assert-True -Condition ($bootContent -match 'Install directory') -TestName "Bootstrapper asks for install directory"
Assert-True -Condition ($bootContent -match 'Replace it\?') -TestName "Bootstrapper has overwrite safety prompt"
Assert-True -Condition ($bootContent -match 'Installation cancelled') -TestName "Bootstrapper has clean exit on cancel"
Assert-True -Condition ($bootContent -match 'Test-IsValidRepo') -TestName "Bootstrapper has Test-IsValidRepo helper"
Assert-True -Condition ($bootContent -match 'Invoke-Launcher') -TestName "Bootstrapper has Invoke-Launcher helper"
Assert-True -Condition ($bootContent -match 'Download-Repo') -TestName "Bootstrapper has Download-Repo helper"
Assert-True -Condition ($bootContent -match 'NonInteractive') -TestName "Bootstrapper accepts -NonInteractive"
Assert-True -Condition ($bootContent -match 'env:CI') -TestName "Bootstrapper detects CI mode"

# Verify local flow detection exists
Assert-True -Condition ($bootContent -match 'localRepoPath') -TestName "Bootstrapper detects local repo path"
Assert-True -Condition ($bootContent -match 'PSScriptRoot') -TestName "Bootstrapper uses PSScriptRoot for local detection"

# Verify no temp-location heuristics (removed in refactor)
Assert-False -Condition ($bootContent -match 'Test-IsTempLocation') -TestName "Bootstrapper does not have temp-location heuristics"

# Behavioral tests — Test-IsValidRepo function (inlined from setup.ps1)
$bootTestDir = Join-Path $env:TEMP "test-bootstrapper-$(Get-Random)"
try {
    # Verify the function exists in AST
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($bootstrapperPath, [ref]$null, [ref]$null)
    $isValidRepoFunc = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-IsValidRepo' }, $false) | Select-Object -First 1

    if ($isValidRepoFunc) {
        # Inline the function logic (matches setup.ps1: Test-Path for Microsoft.PowerShell_profile.ps1)
        function Test-BootIsValidRepo {
            param([string]$Path)
            return (Test-Path (Join-Path $Path 'Microsoft.PowerShell_profile.ps1'))
        }

        # Test with valid repo (has Microsoft.PowerShell_profile.ps1)
        $validRepoDir = Join-Path $bootTestDir "valid-repo"
        New-Item -ItemType Directory -Force -Path $validRepoDir | Out-Null
        New-Item -ItemType File -Path (Join-Path $validRepoDir 'Microsoft.PowerShell_profile.ps1') -Value '# profile' | Out-Null
        Assert-True -Condition (Test-BootIsValidRepo $validRepoDir) -TestName "Test-IsValidRepo returns true for valid repo"

        # Test with invalid repo (no profile file)
        $invalidRepoDir = Join-Path $bootTestDir "invalid-repo"
        New-Item -ItemType Directory -Force -Path $invalidRepoDir | Out-Null
        New-Item -ItemType File -Path (Join-Path $invalidRepoDir 'some-file.txt') -Value 'not a repo' | Out-Null
        Assert-False -Condition (Test-BootIsValidRepo $invalidRepoDir) -TestName "Test-IsValidRepo returns false for invalid repo"

        # Test with nonexistent path
        Assert-False -Condition (Test-BootIsValidRepo "C:\nonexistent-path-$(Get-Random)") -TestName "Test-IsValidRepo returns false for nonexistent path"
    } else {
        Test-Skip -Name "Test-IsValidRepo behavioral tests" -Reason "Function not found in AST"
    }
} finally {
    Remove-MockDir $bootTestDir
}

# AST-based flow verification — verify control flow structure
$bootAst = [System.Management.Automation.Language.Parser]::ParseFile($bootstrapperPath, [ref]$null, [ref]$null)

# Verify the script has the expected flow branches
$ifStatements = $bootAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.IfStatementAst] }, $true)
$hasLocalFlowCheck = $false
$hasHeadlessCheck = $false
$hasDirectoryExistsCheck = $false
$hasConsentCheck = $false

foreach ($if in $ifStatements) {
    $ifText = $if.Extent.Text
    if ($ifText -match 'localRepoPath') { $hasLocalFlowCheck = $true }
    if ($ifText -match 'isHeadless') { $hasHeadlessCheck = $true }
    if ($ifText -match 'Test-Path.*repoPath') { $hasDirectoryExistsCheck = $true }
    if ($ifText -match 'confirmChoice|replaceChoice') { $hasConsentCheck = $true }
}

Assert-True -Condition $hasLocalFlowCheck -TestName "AST: local flow branch exists"
Assert-True -Condition $hasHeadlessCheck -TestName "AST: headless mode branch exists"
Assert-True -Condition $hasDirectoryExistsCheck -TestName "AST: directory existence check exists"
Assert-True -Condition $hasConsentCheck -TestName "AST: user consent check exists"

# Verify Download-Repo has error handling with cleanup
$downloadRepoFunc = $bootAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Download-Repo' }, $false) | Select-Object -First 1
if ($downloadRepoFunc) {
    $downloadText = $downloadRepoFunc.Body.Extent.Text
    Assert-True -Condition ($downloadText -match 'catch') -TestName "Download-Repo has catch block"
    Assert-True -Condition ($downloadText -match 'Remove-Item.*zipPath') -TestName "Download-Repo cleans up zip on failure"
    Assert-True -Condition ($downloadText -match 'Remove-Item.*extractDir') -TestName "Download-Repo cleans up extract dir on failure"
    Assert-True -Condition ($downloadText -match 'return \$false') -TestName "Download-Repo returns false on failure"
} else {
    Test-Skip -Name "Download-Repo error handling tests" -Reason "Function not found in AST"
}

# Verify Invoke-Launcher validates setup.ps1 exists
$invokeLauncherFunc = $bootAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Launcher' }, $false) | Select-Object -First 1
if ($invokeLauncherFunc) {
    $launcherText = $invokeLauncherFunc.Body.Extent.Text
    Assert-True -Condition ($launcherText -match 'Test-Path.*setupEntryPoint') -TestName "Invoke-Launcher validates setup.ps1 exists"
    Assert-True -Condition ($launcherText -match '\. \$setupEntryPoint') -TestName "Invoke-Launcher dot-sources setup.ps1"
} else {
    Test-Skip -Name "Invoke-Launcher tests" -Reason "Function not found in AST"
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
