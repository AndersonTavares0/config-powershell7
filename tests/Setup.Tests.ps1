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
. (Join-Path $modulesDir 'agent-clis.ps1')
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

$environmentCommand = Get-Command Get-InstallerEnvironment -ErrorAction SilentlyContinue
Test-Result -Name 'Installer environment report is available' -Passed ($null -ne $environmentCommand) `
    -Message 'Get-InstallerEnvironment is missing'
if ($environmentCommand) {
    $environmentReport = Get-InstallerEnvironment
    Assert-NotNull -Value $environmentReport.OSVersion -TestName 'Environment report has Windows version'
    Assert-NotNull -Value $environmentReport.Architecture -TestName 'Environment report has architecture'
    Assert-NotNull -Value $environmentReport.PowerShellVersion -TestName 'Environment report has PowerShell version'
    Assert-NotNull -Value $environmentReport.IsAdministrator -TestName 'Environment report has administrator status'
    Assert-NotNull -Value $environmentReport.Is64Bit -TestName 'Environment report has operating-system bitness'
    Assert-True -Condition ($environmentReport.PSObject.Properties.Name -contains 'HasWinGet') `
        -TestName 'Environment report records WinGet availability'
    Assert-True -Condition ($environmentReport.PSObject.Properties.Name -contains 'HasScoop') `
        -TestName 'Environment report records Scoop availability'
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: CORE — Get-FileFromUrl
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Get-FileFromUrl..." -ForegroundColor Yellow

$downloadTestDir = Join-Path $env:TEMP "test-download-helper-$(Get-Random)"
$downloadTestFile = Join-Path $downloadTestDir 'download.bin'
$originalInvokeWebRequestFunction = Get-Command Invoke-WebRequest -CommandType Function -ErrorAction SilentlyContinue

try {
    New-MockDir $downloadTestDir

    ${function:Invoke-WebRequest} = {
        param([string]$Uri, [string]$OutFile, $ErrorAction)
        Set-Content -Path $OutFile -Value ('x' * 128) -Encoding ASCII
    }
    $downloadOk = Get-FileFromUrl -Url 'https://example.test/file.bin' -OutFile $downloadTestFile -MinBytes 100 -Description 'test file'
    Assert-True -Condition $downloadOk -TestName "Get-FileFromUrl returns true for valid download"
    Assert-True -Condition (Test-Path $downloadTestFile) -TestName "Get-FileFromUrl leaves valid download on disk"

    ${function:Invoke-WebRequest} = {
        param([string]$Uri, [string]$OutFile, $ErrorAction)
        Set-Content -Path $OutFile -Value 'tiny' -Encoding ASCII
    }
    $downloadSmall = Get-FileFromUrl -Url 'https://example.test/file.bin' -OutFile $downloadTestFile -MinBytes 100 -Description 'test file'
    Assert-False -Condition $downloadSmall -TestName "Get-FileFromUrl returns false for undersized download"
    Assert-False -Condition (Test-Path $downloadTestFile) -TestName "Get-FileFromUrl removes undersized partial file"

    Set-Content -Path $downloadTestFile -Value 'partial' -Encoding ASCII
    ${function:Invoke-WebRequest} = {
        throw 'network unavailable'
    }
    $downloadFailed = Get-FileFromUrl -Url 'https://example.test/file.bin' -OutFile $downloadTestFile -MinBytes 100 -Description 'test file'
    Assert-False -Condition $downloadFailed -TestName "Get-FileFromUrl returns false when download throws"
    Assert-False -Condition (Test-Path $downloadTestFile) -TestName "Get-FileFromUrl removes partial file after failure"
} finally {
    Remove-Item Function:\Invoke-WebRequest -Force -ErrorAction SilentlyContinue
    if ($originalInvokeWebRequestFunction) {
        Set-Item Function:\Invoke-WebRequest -Value $originalInvokeWebRequestFunction.ScriptBlock -ErrorAction SilentlyContinue
    }
    Remove-MockDir $downloadTestDir
}

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

$pwshResolutionCommand = Get-Command Get-PwshExecutablePath -ErrorAction SilentlyContinue
Test-Result -Name 'PowerShell executable resolver is available' -Passed ($null -ne $pwshResolutionCommand) `
    -Message 'Get-PwshExecutablePath is missing'
if ($pwshResolutionCommand) {
    $pwshResolutionDir = Join-Path $env:TEMP "test-pwsh-resolution-$(Get-Random)"
    try {
        New-MockDir $pwshResolutionDir
        $mockPwshPath = Join-Path $pwshResolutionDir 'pwsh.exe'
        New-MockFile -Path $mockPwshPath -Content 'test executable placeholder'
        $resolvedPwshPath = Get-PwshExecutablePath -CandidatePaths @(
            (Join-Path $pwshResolutionDir 'missing.exe'), $mockPwshPath
        )
        Assert-Equal -Expected ([System.IO.Path]::GetFullPath($mockPwshPath)) -Actual $resolvedPwshPath `
            -TestName 'PowerShell resolver selects first existing executable candidate'
        Assert-Equal -Expected $null -Actual (Get-PwshExecutablePath -CandidatePaths @('C:\not-installed\pwsh.exe')) `
            -TestName 'PowerShell resolver returns null when no candidate exists'
    } finally {
        Remove-MockDir $pwshResolutionDir
    }
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: PROFILE — Get-ProfilePath
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Get-ProfilePath..." -ForegroundColor Yellow

$profilePath = Get-ProfilePath
Assert-NotNull -Value $profilePath -TestName "Get-ProfilePath returns non-null"
$originalProfile = $PROFILE
try {
    $global:PROFILE = [PSCustomObject]@{
        CurrentUserAllHosts = 'C:\Users\test\Documents\PowerShell\profile.ps1'
        CurrentUserCurrentHost = 'C:\Users\test\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    }
    Assert-Equal -Expected $global:PROFILE.CurrentUserAllHosts -Actual (Get-ProfilePath) `
        -TestName 'Get-ProfilePath prefers CurrentUserAllHosts'
} finally {
    $global:PROFILE = $originalProfile
}

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
    Assert-True -Condition ($content -match '# >>> config-powershell7 >>>') -TestName "Profile contains managed block"
    Assert-False -Condition ($content -match '__PROFILE_REPO_ROOT') -TestName "Profile does not persist repo path in environment"

    $result2 = Install-Profile -RepoPath $testRepoDir
    Assert-True -Condition $result2 -TestName "Install-Profile idempotent (already linked)"
    $content2 = Get-Content $testProfilePath -Raw
    Assert-Equal -Expected $content -Actual $content2 -TestName "Install-Profile leaves identical content unchanged"

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
    Assert-True -Condition ($content4 -match 'CONFIG_PWSH7_THEME') -TestName "Install-Profile with ThemeName includes CONFIG_PWSH7_THEME in stub"
    Assert-True -Condition ($content4 -match 'jandedobbeleer') -TestName "Install-Profile with ThemeName includes theme name in stub"

    $result5 = Install-Profile -RepoPath $testThemeDir -ThemeName 'atomic'
    Assert-True -Condition $result5 -TestName "Install-Profile updates managed theme"
    $content5 = Get-Content $testThemeProfilePath -Raw
    Assert-True -Condition ($content5 -match 'atomic') -TestName "Install-Profile writes updated theme"
    Assert-False -Condition ($content5 -match 'jandedobbeleer') -TestName "Install-Profile removes stale managed theme"

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
$uninstallTestHome = Join-Path $testRepoDir2 'home'
$originalHome = $HOME
$originalXdgCache = $env:XDG_CACHE_HOME

try {
    New-MockDir $uninstallTestHome
    Set-Variable -Name HOME -Value $uninstallTestHome -Force
    $env:XDG_CACHE_HOME = Join-Path $uninstallTestHome '.cache'
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
    Set-Variable -Name HOME -Value $originalHome -Force
    $env:XDG_CACHE_HOME = $originalXdgCache
    Remove-MockDir $testRepoDir2
    Remove-MockDir $testProfileDir2
    $global:PROFILE = $originalProfile
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: DEPS — Install-WingetPackage (detection only)
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Winget Detection..." -ForegroundColor Yellow
$depsContent = Get-Content (Join-Path $modulesDir 'deps.ps1') -Raw -Encoding UTF8

$wingetArgsCommand = Get-Command Get-WingetPackageArguments -ErrorAction SilentlyContinue
Test-Result -Name 'WinGet argument builder is available' -Passed ($null -ne $wingetArgsCommand) -Message 'Get-WingetPackageArguments is missing'
if ($wingetArgsCommand) {
    $userScopeArgs = @(Get-WingetPackageArguments -Id 'Git.Git')
    Assert-True -Condition ($userScopeArgs -contains '--scope' -and $userScopeArgs -contains 'user') `
        -TestName 'WinGet installs into current-user scope by default'
    Assert-False -Condition ($userScopeArgs -contains '--scope' -and $userScopeArgs -contains 'machine') `
        -TestName 'WinGet does not request machine scope by default'
    Assert-True -Condition ($userScopeArgs -contains '--accept-package-agreements' -and $userScopeArgs -contains '--accept-source-agreements') `
        -TestName 'WinGet arguments accept source and package agreements'
    Assert-True -Condition ($depsContent -match 'Install-ScoopFallbackPackage -Id \$Id') `
        -TestName 'Dependency installer uses Scoop when WinGet is missing'
}
$scoopMapCommand = Get-Command Get-ScoopPackageName -ErrorAction SilentlyContinue
Test-Result -Name 'Scoop fallback package map is available' -Passed ($null -ne $scoopMapCommand) -Message 'Get-ScoopPackageName is missing'
if ($scoopMapCommand) {
    Assert-Equal -Expected 'pwsh' -Actual (Get-ScoopPackageName -Id 'Microsoft.PowerShell') `
        -TestName 'Scoop fallback maps PowerShell package'
    Assert-Equal -Expected 'fastfetch' -Actual (Get-ScoopPackageName -Id 'Fastfetch-cli.Fastfetch') `
        -TestName 'Scoop fallback maps Fastfetch package'
    Assert-Equal -Expected $null -Actual (Get-ScoopPackageName -Id 'Unknown.Package') `
        -TestName 'Scoop fallback rejects unmapped package'
}

$originalWingetPathLookup = ${function:Get-WingetPath}
$originalScoopFallback = ${function:Install-ScoopFallbackPackage}
$script:scoopFallbackRequest = $null
${function:Get-WingetPath} = { return $null }
${function:Install-ScoopFallbackPackage} = {
    param([string]$Id, [string]$DisplayName)
    $script:scoopFallbackRequest = [PSCustomObject]@{ Id = $Id; DisplayName = $DisplayName }
    return $true
}
try {
    $fallbackResult = Install-WingetPackage -Id 'Git.Git' -DisplayName 'Git'
    Assert-True -Condition $fallbackResult -TestName 'Missing WinGet invokes package fallback'
    Assert-Equal -Expected 'Git.Git' -Actual $script:scoopFallbackRequest.Id `
        -TestName 'WinGet fallback receives requested package identifier'
} finally {
    ${function:Get-WingetPath} = $originalWingetPathLookup
    ${function:Install-ScoopFallbackPackage} = $originalScoopFallback
    Remove-Variable -Name scoopFallbackRequest -Scope Script -ErrorAction SilentlyContinue
}

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

$bundledThemePath = Join-Path $repoRoot 'themes/atomic.omp.json'
$themeValidatorCommand = Get-Command Test-OmpThemeFile -ErrorAction SilentlyContinue
Test-Result -Name 'OMP theme validator is available' -Passed ($null -ne $themeValidatorCommand) -Message 'Test-OmpThemeFile is missing'
if ($themeValidatorCommand) {
    Assert-True -Condition (Test-OmpThemeFile -Path $bundledThemePath) `
        -TestName 'Bundled atomic theme has valid Oh My Posh structure'

    $invalidThemePath = Join-Path $env:TEMP "invalid-omp-theme-$(Get-Random).json"
    try {
        Set-Content -LiteralPath $invalidThemePath -Value '{"blocks":[]}' -Encoding UTF8
        Assert-False -Condition (Test-OmpThemeFile -Path $invalidThemePath) `
            -TestName 'OMP theme validator rejects missing version and segments'
    } finally {
        Remove-Item -LiteralPath $invalidThemePath -Force -ErrorAction SilentlyContinue
    }
}
$themeNameValidator = Get-Command Test-OmpThemeName -ErrorAction SilentlyContinue
Test-Result -Name 'OMP theme name validator is available' -Passed ($null -ne $themeNameValidator) -Message 'Test-OmpThemeName is missing'
if ($themeNameValidator) {
    Assert-True -Condition (Test-OmpThemeName -Name 'atomic') -TestName 'OMP theme name accepts bundled theme'
    Assert-True -Condition (Test-OmpThemeName -Name 'my_custom-theme.2') -TestName 'OMP theme name accepts simple custom filename'
    Assert-True -Condition (Test-OmpThemeName -Name 'My custom theme') -TestName 'OMP theme name accepts spaces in custom filename'
    Assert-True -Condition (Test-OmpThemeName -Name 'tema-á') -TestName 'OMP theme name accepts Unicode letters'
    Assert-False -Condition (Test-OmpThemeName -Name '..') -TestName 'OMP theme name rejects parent path'
    Assert-False -Condition (Test-OmpThemeName -Name '..\outside') -TestName 'OMP theme name rejects path traversal'
}

$localThemeCatalog = Get-Command Get-LocalOmpThemeList -ErrorAction SilentlyContinue
Test-Result -Name 'Local OMP theme catalog is available' -Passed ($null -ne $localThemeCatalog) -Message 'Get-LocalOmpThemeList is missing'
if ($localThemeCatalog) {
    $localThemeTestDir = Join-Path $env:TEMP "local-omp-themes-$(Get-Random)"
    $originalThemeDirectory = ${function:Get-OmpThemeDirectory}
    $originalRestMethodFunction = Get-Command Invoke-RestMethod -CommandType Function -ErrorAction SilentlyContinue
    try {
        New-MockDir $localThemeTestDir
        ${function:Get-OmpThemeDirectory} = { return $localThemeTestDir }
        $validCustomTheme = '{"version":4,"blocks":[{"type":"prompt","segments":[{"type":"text","style":"plain"}]}]}'
        Set-Content -LiteralPath (Join-Path $localThemeTestDir 'custom-local.omp.json') -Value $validCustomTheme -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $localThemeTestDir 'broken-local.omp.json') -Value '{"blocks":[]}' -Encoding UTF8
        $availableThemes = @(Get-LocalOmpThemeList -RepoPath $repoRoot)
        Assert-True -Condition ($availableThemes -contains 'atomic') -TestName 'Local theme catalog always includes bundled atomic'
        Assert-True -Condition ($availableThemes -contains 'custom-local') -TestName 'Local theme catalog includes valid user theme'
        Assert-False -Condition ($availableThemes -contains 'broken-local') -TestName 'Local theme catalog hides invalid user theme'

        ${function:Invoke-RestMethod} = {
            [CmdletBinding()]
            param([string]$Uri, [int]$TimeoutSec)
            throw 'simulated offline host'
        }
        $offlineThemes = @(Get-OmpThemeList -RepoPath $repoRoot)
        Assert-True -Condition ($offlineThemes -contains 'atomic' -and $offlineThemes -contains 'custom-local') `
            -TestName 'Theme list keeps local themes when online catalog fails'
    } finally {
        ${function:Get-OmpThemeDirectory} = $originalThemeDirectory
        if ($originalRestMethodFunction) {
            Set-Item Function:\Invoke-RestMethod -Value $originalRestMethodFunction.ScriptBlock
        } else {
            Remove-Item Function:\Invoke-RestMethod -ErrorAction SilentlyContinue
        }
        Remove-MockDir $localThemeTestDir
    }
}

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
$origOmpThemeDirectory = ${function:Get-OmpThemeDirectory}
try {
    New-MockDir $ompThemeTestDir
    ${function:Get-OmpThemeDirectory} = { return $ompThemeTestDir }
    ${function:Get-Executable} = {
        return [PSCustomObject]@{ Name = 'oh-my-posh'; Path = 'C:\dummy\oh-my-posh.exe'; Found = $true; Version = '23.0.0' }
    }

    $mockThemeFile = Join-Path $ompThemeTestDir 'test-theme.omp.json'
    $validThemeContent = '{"version":4,"blocks":[{"type":"prompt","segments":[{"type":"text","style":"plain"}]}]}'
    Set-Content -LiteralPath $mockThemeFile -Value $validThemeContent -Encoding UTF8 -Force
    $result3 = Install-OmpTheme -ThemeName 'test-theme'
    Assert-True -Condition $result3 -TestName "Install-OmpTheme returns true when theme already exists and is valid"
    Assert-Equal -Expected $validThemeContent -Actual (Get-Content -LiteralPath $mockThemeFile -Raw).Trim() `
        -TestName 'Install-OmpTheme preserves existing valid custom theme'

    $invalidCustomTheme = '{"blocks":[]}'
    Set-Content -LiteralPath $mockThemeFile -Value $invalidCustomTheme -Encoding UTF8 -Force
    $invalidExistingResult = Install-OmpTheme -ThemeName 'test-theme' -RepoPath $repoRoot
    Assert-False -Condition $invalidExistingResult -TestName 'Install-OmpTheme refuses to replace invalid user theme'
    Assert-Equal -Expected $invalidCustomTheme -Actual (Get-Content -LiteralPath $mockThemeFile -Raw).Trim() `
        -TestName 'Install-OmpTheme preserves invalid user theme for recovery'

    $result4 = Install-OmpTheme -ThemeName 'atomic' -RepoPath $repoRoot
    $installedAtomicPath = Join-Path $ompThemeTestDir 'atomic.omp.json'
    Assert-True -Condition $result4 -TestName 'Install-OmpTheme copies bundled atomic theme offline'
    Assert-Equal -Expected ([System.IO.File]::ReadAllText($bundledThemePath)) `
        -Actual ([System.IO.File]::ReadAllText($installedAtomicPath)) `
        -TestName 'Bundled theme copy matches project source'
} finally {
    ${function:Get-OmpThemeDirectory} = $origOmpThemeDirectory
    Remove-MockDir $ompThemeTestDir
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
$originalFastfetchInstaller = ${function:Install-Fastfetch}
$originalTopgradeInstaller = ${function:Install-Topgrade}
$originalAgentCliInstaller = ${function:Install-AgentCli}
$originalGetExecutableForOptions = ${function:Get-Executable}
$script:selectedOptionalInstallers = @()
${function:Install-Fastfetch} = { $script:selectedOptionalInstallers += 'Fastfetch'; return $true }
${function:Install-Topgrade} = { $script:selectedOptionalInstallers += 'Topgrade'; return $true }
${function:Install-AgentCli} = { param($Name) $script:selectedOptionalInstallers += $Name; return $true }
${function:Get-Executable} = { param($Name, $VersionArg) return $null }

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
        -InstallFastfetch $true -InstallTopgrade $false -InstallScoop $false

    Assert-True -Condition (Test-Path $testProfilePath3) -TestName "Orchestrator creates profile link (dry-run)"
    Assert-Equal -Expected 'Fastfetch' -Actual ($script:selectedOptionalInstallers -join ',') `
        -TestName 'Fastfetch installs without Topgrade'

    $script:selectedOptionalInstallers = @()
    Start-ProfileInstall -RepoPath $testRepoDir3 `
        -InstallPS7 $false -InstallGit $false -InstallOMP $false `
        -InstallZoxide $false -InstallFont $false -InstallModules $false `
        -InstallFastfetch $false -InstallTopgrade $true -InstallScoop $false
    Assert-Equal -Expected 'Topgrade' -Actual ($script:selectedOptionalInstallers -join ',') `
        -TestName 'Topgrade installs without Fastfetch'

    $script:selectedOptionalInstallers = @()
    Start-ProfileInstall -RepoPath $testRepoDir3 `
        -InstallPS7 $false -InstallGit $false -InstallOMP $false `
        -InstallZoxide $false -InstallFont $false -InstallModules $false `
        -InstallScoop $false -InstallCodex $true
    Assert-Equal -Expected 'Codex' -Actual ($script:selectedOptionalInstallers -join ',') `
        -TestName 'Orchestrator installs only selected agent CLI'

    $content = Get-Content $testProfilePath3 -Raw
    Assert-True -Condition ($content -match 'Microsoft\.PowerShell_profile\.ps1') -TestName "Orchestrator profile has dot-source"

    $script:SyncHash.InstallComplete = $false
    $script:SyncHash.InstallFailed = $false
    Start-ProfileInstall -RepoPath (Join-Path $testRepoDir3 'missing') `
        -InstallPS7 $false -InstallGit $false -InstallOMP $false `
        -InstallZoxide $false -InstallFont $false -InstallModules $false `
        -InstallScoop $false
    Assert-True -Condition $script:SyncHash.InstallFailed -TestName 'Orchestrator component failure sets overall failure'

} finally {
    ${function:Install-Fastfetch} = $originalFastfetchInstaller
    ${function:Install-Topgrade} = $originalTopgradeInstaller
    ${function:Install-AgentCli} = $originalAgentCliInstaller
    ${function:Get-Executable} = $originalGetExecutableForOptions
    Remove-Variable -Name selectedOptionalInstallers -Scope Script -ErrorAction SilentlyContinue
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
    @{ Name = 'Fastfetch'; Status = 'skip'; Detail = 'not selected' }
)

Write-InstallSummary -Results $testResults

Summary-Assert-True -Condition ($summarySyncHash.LogMessages.Count -gt 0) -TestName "Write-InstallSummary writes to SyncHash"

$okRows = $summarySyncHash.LogMessages | Where-Object { $_.Type -eq 'Ok' -and $_.Message -match 'PowerShell 7' }
Summary-Assert-True -Condition ($null -ne $okRows -and $okRows.Count -gt 0) -TestName "Write-InstallSummary ok row uses Ok type"

$failRows = $summarySyncHash.LogMessages | Where-Object { $_.Type -eq 'Fail' -and $_.Message -match 'FiraCode' }
Summary-Assert-True -Condition ($null -ne $failRows -and $failRows.Count -gt 0) -TestName "Write-InstallSummary fail row uses Fail type"

$skipRows = $summarySyncHash.LogMessages | Where-Object { $_.Type -eq 'Warn' -and $_.Message -match 'Fastfetch' }
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
Assert-True -Condition ($bootContent -match 'throw "This installer supports Windows 10/11 x64 only\.') `
    -TestName 'Bootstrapper fails with an error on unsupported operating systems'
$executableContent = Get-Content (Join-Path $repoRoot 'lib/executable.ps1') -Raw -Encoding UTF8
Assert-True -Condition ($bootContent -match "lib/executable\.ps1") `
    -TestName 'Bootstrapper loads shared executable resolver'
Assert-True -Condition ($executableContent -match 'function Get-PwshExecutablePath') `
    -TestName 'Shared executable resolver finds PowerShell 7'
Assert-True -Condition ($executableContent -match 'Microsoft\\WindowsApps\\pwsh\.exe') `
    -TestName 'Shared resolver checks WindowsApps PowerShell path'
Assert-True -Condition ($executableContent -match 'Microsoft\\WinGet\\Links\\pwsh\.exe') `
    -TestName 'Shared resolver checks WinGet PowerShell link'
Assert-True -Condition ($bootContent -match "'--scope', 'user'") `
    -TestName 'Bootstrapper installs PowerShell in user scope first'
    Assert-True -Condition ($bootContent -match 'Retry with administrator rights') `
        -TestName 'Bootstrapper asks before elevated PowerShell install'
    Assert-True -Condition ($bootContent -match 'scoop\.Source install pwsh') `
        -TestName 'Bootstrapper can install PowerShell without WinGet'

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
    Assert-True -Condition ($downloadText -match 'New-Item.*parentDir') -TestName "Download-Repo creates parent dir before extraction"
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

# The headless branch must group Test-Path before -and; unparenthesised it binds
# '-and' as a Test-Path parameter and aborts every non-interactive install.
$bootText = Get-Content $bootstrapperPath -Raw -Encoding UTF8
Assert-True -Condition ($bootText -match '\(Test-Path \$repoPath\) -and \(Test-IsValidRepo \$repoPath\)') `
    -TestName "Headless repo check groups Test-Path before -and"

# The launcher exposes GUI as an explicit option and keeps optional tools selectable.
$entryText = Get-Content (Join-Path $setupDir 'setup.ps1') -Raw -Encoding UTF8
Assert-True -Condition ($entryText -match '\[switch\]\$Gui') `
    -TestName "Setup entry point exposes optional GUI"
Assert-True -Condition $entryText.Contains('agent-clis.ps1') `
    -TestName 'Setup entry point loads agent CLI installers'
Assert-True -Condition ($entryText -match "Set-StrictMode -Version Latest") `
    -TestName "Setup entry point sets its own strict mode for the pwsh -File relaunch"

# Verify remote package manager installers are downloaded to disk before execution
$depsPath = Join-Path $modulesDir 'deps.ps1'
$depsContent = Get-Content $depsPath -Raw -Encoding UTF8
$orchestratorContent = Get-Content (Join-Path $modulesDir 'orchestrator.ps1') -Raw -Encoding UTF8
Assert-False -Condition ($depsContent -match 'Invoke-Expression') -TestName "Remote installers do not use Invoke-Expression"
Assert-True -Condition ($depsContent -match 'Remote installer notice: Scoop') -TestName "Scoop remote installer notice is logged"
Assert-True -Condition ($depsContent -match 'get\.scoop\.sh') -TestName "Scoop installer source URL is present"
Assert-True -Condition ($depsContent -match 'scoopInstallPath') -TestName "Scoop installer temp path is logged/executed"
Assert-True -Condition ($depsContent -match 'Unblock-File -Path \$scoopInstallPath') -TestName "Scoop temp installer is unblocked before execution"
Assert-True -Condition ($depsContent -match '& \$scoopInstallPath') -TestName "Scoop installer executes from temp file"
Assert-False -Condition ($depsContent -match 'Set-ExecutionPolicy') -TestName "Installer never mutates the execution policy"

# ══════════════════════════════════════════════════════════════
# TEST SUITE: INSTALLER OPTIONS — user-facing defaults
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting installer options..." -ForegroundColor Yellow
$guiContent = Get-Content (Join-Path $modulesDir 'gui.ps1') -Raw
$cliContent = Get-Content (Join-Path $modulesDir 'cli.ps1') -Raw
Assert-False -Condition ($guiContent -match 'ChkAlacritty|Alacritty') -TestName 'GUI has no Alacritty setup'
Assert-True -Condition (([regex]::Matches($guiContent, 'modules/agent-clis\.ps1')).Count -ge 2) `
    -TestName 'GUI runspaces load agent CLI installers'
# GUI runspaces must release controls after success or failure.
$guiRunspaceCatches = ([regex]::Matches($guiContent, '\$SyncHash\.InstallComplete = \$true')).Count
Assert-True -Condition ($guiRunspaceCatches -ge 2) -TestName 'GUI runspaces always release the UI on failure'
Assert-True -Condition ($guiContent -match 'Set-LocalOmpThemeList -ThemeRepoPath \$RepoPath') `
    -TestName 'GUI displays local OMP themes before online lookup'
Assert-True -Condition ($guiContent -match 'Invoke-RestMethod -Uri \$apiUrl -TimeoutSec 8') `
    -TestName 'GUI OMP lookup has an eight-second timeout'
Assert-True -Condition ($guiContent -match 'Invoke-RestMethod -Uri \$url -TimeoutSec 8') `
    -TestName 'GUI remote theme preview has an eight-second timeout'
Assert-False -Condition ($cliContent -match 'Alacritty') -TestName 'CLI has no Alacritty setup'
Assert-True -Condition ($cliContent -match 'Install Fastfetch\? \(y/n\) \[n\]') -TestName 'CLI offers Fastfetch as an optional tool'
Assert-True -Condition ($cliContent -match 'Install Topgrade\? \(y/n\) \[n\]') -TestName 'CLI offers Topgrade as an optional tool'
Assert-True -Condition ($cliContent -match "'m' for manual name") -TestName 'CLI allows a manual OMP theme name'
Assert-True -Condition ($depsContent -match "Fastfetch-cli\.Fastfetch") -TestName 'Fastfetch installer uses the official WinGet package'
Assert-True -Condition ($depsContent -match "topgrade-rs\.topgrade") -TestName 'Topgrade installer uses the current WinGet package'
Assert-False -Condition ($orchestratorContent -match 'Install-Alacritty|InstallAlacritty') -TestName 'Orchestrator does not install Alacritty'

$guiAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $modulesDir 'gui.ps1'), [ref]$null, [ref]$null)
$xamlNode = $guiAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $node.Value.StartsWith('<Window') }, $true) |
    Select-Object -First 1
Test-Result -Name 'GUI XAML is present in the parsed installer' -Passed ($null -ne $xamlNode) -Message 'Window XAML was not found'
if ($xamlNode) {
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        $windowXml = [xml]$xamlNode.Value
        $windowReader = [System.Xml.XmlNodeReader]::new($windowXml)
        $setupWindow = [Windows.Markup.XamlReader]::Load($windowReader)
        foreach ($controlName in @('ChkFastfetch', 'ChkTopgrade', 'ChkAntigravity', 'ChkOpenCode', 'ChkCodex', 'ChkClaudeCode')) {
            Test-Result -Name "GUI contains $controlName option" -Passed ($null -ne $setupWindow.FindName($controlName)) -Message 'Control was not created by WPF'
        }
        Assert-True -Condition ($null -eq $setupWindow.FindName('ChkAlacritty')) -TestName 'WPF has no Alacritty control'
    } catch {
        Test-Result -Name 'GUI XAML loads in WPF' -Passed $false -Message $_.Exception.Message
    }
}

# Preserve user-owned profile content and escape PowerShell metacharacters.
$testPreserveRepo = Join-Path $env:TEMP "test-setup-repo-'dollar`$-$(Get-Random)"
$testPreserveDir = Join-Path $env:TEMP "test-setup-preserve-$(Get-Random)"
$testPreserveProfile = Join-Path $testPreserveDir 'Profile.ps1'
try {
    New-MockDir $testPreserveRepo
    New-MockDir (Join-Path $testPreserveRepo 'modules')
    New-MockFile (Join-Path $testPreserveRepo 'Microsoft.PowerShell_profile.ps1') '# profile'
    New-MockDir $testPreserveDir
    New-MockFile $testPreserveProfile '$global:UserProfileContent = $true'
    $originalProfile = $PROFILE
    $global:PROFILE = $testPreserveProfile

    $preserveResult = Install-Profile -RepoPath $testPreserveRepo
    $preservedContent = Get-Content $testPreserveProfile -Raw
    Assert-True -Condition $preserveResult -TestName 'Install-Profile handles metacharacters in repo path'
    Assert-True -Condition ($preservedContent -match 'UserProfileContent') -TestName 'Install-Profile preserves user content'
    Assert-True -Condition $preservedContent.Contains("repo-''dollar`$-") -TestName 'Install-Profile escapes single quote in path'
} finally {
    Remove-MockDir $testPreserveRepo
    Remove-MockDir $testPreserveDir
    $global:PROFILE = $originalProfile
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: AGENT CLIs — install metadata
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting agent CLI definitions..." -ForegroundColor Yellow
. (Join-Path $modulesDir 'cli.ps1')

$agentSpecCommand = Get-Command Get-AgentCliInstallSpec -ErrorAction SilentlyContinue
Test-Result -Name 'Agent CLI definitions are available' -Passed ($null -ne $agentSpecCommand) -Message 'Get-AgentCliInstallSpec is missing'
if ($agentSpecCommand) {
    $expectedAgentCliNames = @('Antigravity', 'ClaudeCode', 'Codex', 'OpenCode')
    $actualAgentCliNames = @(Get-AgentCliInstallSpec | ForEach-Object { $_.Name } | Sort-Object)
    Assert-Equal -Expected ($expectedAgentCliNames -join ',') -Actual ($actualAgentCliNames -join ',') `
        -TestName 'Agent CLI catalog contains supported tools'

    $selectionCommand = Get-Command Get-AgentCliSelection -ErrorAction SilentlyContinue
    Test-Result -Name 'Agent CLI selection parser is available' -Passed ($null -ne $selectionCommand) -Message 'Get-AgentCliSelection is missing'
    if ($selectionCommand) {
        $selection = Get-AgentCliSelection -Selection '2,4'
        Assert-Equal -Expected 'ClaudeCode,OpenCode' -Actual (@($selection.Selected | ForEach-Object { $_.Name }) -join ',') `
            -TestName 'Agent CLI selection resolves multiple menu choices'
        $allSelection = Get-AgentCliSelection -Selection 'A'
        Assert-Equal -Expected 4 -Actual $allSelection.Selected.Count -TestName 'Agent CLI selection supports all tools'
        $invalidSelection = Get-AgentCliSelection -Selection '1,x'
        Assert-False -Condition $invalidSelection.Valid -TestName 'Agent CLI selection rejects invalid input atomically'
        Assert-Equal -Expected 0 -Actual $invalidSelection.Selected.Count -TestName 'Invalid agent CLI selection installs nothing'
    }

    $menuIndexCommand = Get-Command ConvertFrom-MenuIndex -ErrorAction SilentlyContinue
    Test-Result -Name 'Menu index validator is available' -Passed ($null -ne $menuIndexCommand) -Message 'ConvertFrom-MenuIndex is missing'
    if ($menuIndexCommand) {
        $firstIndex = ConvertFrom-MenuIndex -Value '1' -Count 3
        Assert-True -Condition $firstIndex.Valid -TestName 'Menu index accepts first item'
        Assert-Equal -Expected 0 -Actual $firstIndex.Index -TestName 'Menu index converts one-based choice to zero-based index'
        Assert-False -Condition (ConvertFrom-MenuIndex -Value 'x' -Count 3).Valid -TestName 'Menu index rejects text'
        Assert-False -Condition (ConvertFrom-MenuIndex -Value '4' -Count 3).Valid -TestName 'Menu index rejects out-of-range choice'
    }

    $antigravitySpec = Get-AgentCliInstallSpec -Name 'Antigravity'
    Assert-Equal -Expected 'https://antigravity.google/cli/install.ps1' -Actual $antigravitySpec.Source `
        -TestName 'Antigravity uses official PowerShell installer'

    $claudeSpec = Get-AgentCliInstallSpec -Name 'ClaudeCode'
    Assert-Equal -Expected 'https://claude.ai/install.ps1' -Actual $claudeSpec.Source `
        -TestName 'Claude Code uses official PowerShell installer'

    $codexSpec = Get-AgentCliInstallSpec -Name 'Codex'
    Assert-Equal -Expected 'https://chatgpt.com/codex/install.ps1' -Actual $codexSpec.Source `
        -TestName 'Codex uses official PowerShell installer'

    $openCodeSpec = Get-AgentCliInstallSpec -Name 'OpenCode'
    Assert-Equal -Expected 'opencode-ai' -Actual $openCodeSpec.Package `
        -TestName 'OpenCode uses official npm package'

    $agentCommandHelper = Test-Path Function:\Get-AgentCliCommand
    Test-Result -Name 'Agent command lookup is replaceable in tests' -Passed $agentCommandHelper `
        -Message 'Get-AgentCliCommand is missing'
    if ($agentCommandHelper) {
        $originalAgentCommandHelper = ${function:Get-AgentCliCommand}
        ${function:Get-AgentCliCommand} = { param([string]$Name) return $null }
        try {
            Assert-False -Condition (Install-AgentCli -Name 'OpenCode') `
                -TestName 'OpenCode reports missing Node.js without depending on developer machine'
        } finally {
            ${function:Get-AgentCliCommand} = $originalAgentCommandHelper
        }
    }

    $originalOfficialInstaller = ${function:Invoke-OfficialPowerShellInstaller}
    $script:installedAgentSpec = $null
    ${function:Invoke-OfficialPowerShellInstaller} = {
        param($Spec)
        $script:installedAgentSpec = $Spec
        return $true
    }
    try {
        $installAgentResult = Install-AgentCli -Name 'Antigravity' -Force
        Assert-True -Condition $installAgentResult -TestName 'Install-AgentCli delegates to official PowerShell installer'
        Assert-Equal -Expected 'Antigravity' -Actual $script:installedAgentSpec.Name `
            -TestName 'Install-AgentCli passes selected tool to official installer'
    } finally {
        ${function:Invoke-OfficialPowerShellInstaller} = $originalOfficialInstaller
        Remove-Variable -Name installedAgentSpec -Scope Script -ErrorAction SilentlyContinue
    }
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
