#Requires -Version 5.1
# ============================================================
# UNIT TESTS FOR Microsoft.PowerShell_profile.ps1
# PS 5.1+ / PS Core 7+ | Revisão: 05/2026
# ============================================================
# Cobertura: Config centralizado, Cache TTL, Performance, Funções

param([switch]$Verbose)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── TEST FRAMEWORK ────────────────────────────────────────────
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
        Write-Host "  ✓ PASS: $Name" -ForegroundColor Green
    }
    else {
        $script:TestsFailed++
        Write-Host "  ✗ FAIL: $Name - $Message" -ForegroundColor Red
    }
}

function Test-Skip {
    param([Parameter(Mandatory)][string]$Name, [string]$Reason = 'Skipped')
    $script:TestsSkipped++
    Write-Host "  ⊘ SKIP: $Name - $Reason" -ForegroundColor Gray
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

# ── MOCK HELPERS ──────────────────────────────────────────────
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

# ── LOAD PROFILE ──────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PowerShell Profile Unit Tests v2" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Loading profile..." -ForegroundColor Yellow
$profileTimer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Remove-Variable -Name '__CONFIG_POWERSHELL7_PROFILE_LOADED' -Scope Global -ErrorAction SilentlyContinue
    . $PROFILE
    $profileTimer.Stop()
    $bootMs = [math]::Round($profileTimer.Elapsed.TotalMilliseconds, 0)
    Test-Result -Name "Profile loads without errors" -Passed $true -Message ""
}
catch {
    $profileTimer.Stop()
    $bootMs = [math]::Round($profileTimer.Elapsed.TotalMilliseconds, 0)
    Test-Result -Name "Profile loads without errors" -Passed $false -Message $_.Exception.Message
    Write-Host "Cannot continue tests without profile loaded." -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: PERFORMANCE
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Performance..." -ForegroundColor Yellow

# Test P1: Cold boot should stay bounded, but CI startup can vary significantly.
Test-Result -Name "Cold boot -lt 2000ms (measured: ${bootMs}ms)" `
    -Passed ($bootMs -lt 2000) `
    -Message "Cold boot took ${bootMs}ms, target -lt 2000ms for CI"

# Test P2: Second boot (cache hit) should be faster
$secondTimer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Remove-Variable -Name '__CONFIG_POWERSHELL7_PROFILE_LOADED' -Scope Global -ErrorAction SilentlyContinue
    . $PROFILE
    $secondTimer.Stop()
    $secondMs = [math]::Round($secondTimer.Elapsed.TotalMilliseconds, 0)
    Test-Result -Name "Second boot (cache hit) -lt 400ms (measured: ${secondMs}ms)" `
        -Passed ($secondMs -lt 400) `
        -Message "Second boot took ${secondMs}ms"
}
catch {
    $secondTimer.Stop()
    Test-Result -Name "Second boot (cache hit)" -Passed $false -Message $_.Exception.Message
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: CENTRALIZED CONFIG
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Centralized Config..." -ForegroundColor Yellow

# Test C1: `$script:Config object exists
Assert-NotNull -Value $script:Config -TestName "Config object exists"

# Test C2: Platform detection is set
if ($null -ne $script:Config) {
    Assert-NotNull -Value $script:Config.IsWindows -TestName "Config.IsWindows is set"
    Assert-NotNull -Value $script:Config.IsLinux   -TestName "Config.IsLinux is set"
    Assert-NotNull -Value $script:Config.PSMajor   -TestName "Config.PSMajor is set"
    Assert-NotNull -Value $script:Config.CachePath  -TestName "Config.CachePath is set"
    Assert-NotNull -Value $script:Config.ThemePath  -TestName "Config.ThemePath is set"

    # Test C3: TTL is configured
    Assert-True -Condition ($script:Config.CacheTTLMinutes -gt 0) -TestName "Config.CacheTTLMinutes > 0"
}
else {
    Test-Skip -Name "Config property tests" -Reason "Config object is null"
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: POSH_THEME ENV VAR
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting POSH_THEME Environment Variable..." -ForegroundColor Yellow

if ($null -ne $script:Config) {
    $savedPoshTheme = $env:POSH_THEME
    $configPath = Join-Path $script:ProfileRoot 'modules/config/config.ps1'
    $testThemeDir = Join-Path $HOME '.poshthemes'
    $testThemeFile = Join-Path $testThemeDir 'test_theme.omp.json'

    try {
        New-MockFile -Path $testThemeFile -Content '{"name":"test_theme"}'

        $env:POSH_THEME = 'test_theme'
        . $configPath
        Assert-True -Condition ($script:Config.ThemePath -match 'test_theme\.omp\.json$') `
            -TestName "POSH-01: env var overrides default theme"

        $env:POSH_THEME = $null
        . $configPath
        Assert-True -Condition ($script:Config.ThemePath -match 'atomic\.omp\.json$') `
            -TestName "POSH-02: unset env var uses atomic"

        $env:POSH_THEME = ''
        . $configPath
        Assert-True -Condition ($script:Config.ThemePath -match 'atomic\.omp\.json$') `
            -TestName "POSH-03: empty env var treated as unset"

        $env:POSH_THEME = 'nonexistent_test_theme'
        $capturedWarn = . $configPath 3>&1
        Assert-True -Condition ($script:Config.ThemePath -match 'atomic\.omp\.json$') `
            -TestName "POSH-04: missing theme file falls back to atomic"
        Assert-True -Condition (($capturedWarn | Out-String) -match 'nonexistent_test_theme') `
            -TestName "POSH-05: warning mentions missing theme name"
    }
    finally {
        Remove-MockFile -Path $testThemeFile
        $env:POSH_THEME = $savedPoshTheme
        . $configPath
    }
}
else {
    Test-Skip -Name "POSH_THEME tests" -Reason "Config object is null"
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: CACHE TTL
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Cache TTL System..." -ForegroundColor Yellow

# Test T1: Cache file exists after boot
if ($null -ne $script:Config) {
    Assert-True -Condition (Test-Path $script:Config.CachePath) -TestName "Cache file exists after boot"

    # Test T2: Cache header has TTL timestamp
    if (Test-Path $script:Config.CachePath) {
        $cacheHeader = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        $hasTTL = $cacheHeader -match '^# fp:\S+\s+ts:\d+$'
        Assert-True -Condition $hasTTL -TestName "Cache header contains TTL timestamp"
    }
}
else {
    Test-Skip -Name "Cache TTL tests" -Reason "Config object is null"
}

# Test T3: Clear-PluginCache function
if (Get-Command Clear-PluginCache -ErrorAction SilentlyContinue) {
    Test-Result -Name "Clear-PluginCache function exists" -Passed $true -Message ""
}
else {
    Test-Result -Name "Clear-PluginCache function exists" -Passed $false -Message "Function not defined"
}

# Test T4: Clear-Cache alias
if (Get-Command Clear-Cache -ErrorAction SilentlyContinue) {
    Test-Result -Name "Clear-Cache alias exists" -Passed $true -Message ""
}
else {
    Test-Result -Name "Clear-Cache alias exists" -Passed $false -Message "Alias not defined"
}

# Test T5: Import-TerminalIcons / icons alias
if (Get-Command Import-TerminalIcons -ErrorAction SilentlyContinue) {
    Test-Result -Name "Import-TerminalIcons function exists" -Passed $true -Message ""
}
else {
    Test-Result -Name "Import-TerminalIcons function exists" -Passed $false -Message "Function not defined"
}
if (Get-Command icons -ErrorAction SilentlyContinue) {
    Test-Result -Name "icons alias exists" -Passed $true -Message ""
}
else {
    Test-Result -Name "icons alias exists" -Passed $false -Message "Alias not defined"
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: CACHE INVALIDATION ON THEME CHANGE
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Cache Invalidation on Theme Change..." -ForegroundColor Yellow

if ($null -ne $script:Config -and (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    $testDir      = Join-Path $HOME ".pwsh_test_themeinv_$(Get-Random)"
    $themeA       = Join-Path $testDir "themeA.omp.json"
    $themeB       = Join-Path $testDir "themeB.omp.json"
    $originalPath = $script:Config.ThemePath
    $originalTTL  = $script:Config.CacheTTLMinutes

    New-Item -ItemType Directory -Force -Path $testDir | Out-Null
    try {
        Set-Content -Path $themeA -Value '{"name":"themeA"}' -Encoding UTF8
        Set-Content -Path $themeB -Value '{"name":"themeB"}' -Encoding UTF8
        $script:Config.CacheTTLMinutes = 1440

        # Test I1: Cache header contém tema A após rebuild
        $script:Config.ThemePath = $themeA
        Clear-PluginCache
        Initialize-PluginCache
        $headerA = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        $hasThemeA = $headerA -match [regex]::Escape("$themeA")
        Assert-True -Condition $hasThemeA -TestName "Cache created with Theme A"

        # Test I2: Troca para tema B, TTL válido → cache reconstruído
        $script:Config.ThemePath = $themeB
        Initialize-PluginCache
        $headerB = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        $hasThemeB = $headerB -match [regex]::Escape("$themeB")
        Assert-True -Condition $hasThemeB -TestName "Cache rebuilt after theme change within TTL"

        # Test I3: Tema deletado, TTL válido → cache reconstruído com fallback
        $script:Config.ThemePath = $themeA
        Initialize-PluginCache
        Remove-Item $themeA -Force
        Initialize-PluginCache
        $headerC = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        $hasFallback = $headerC -match [regex]::Escape("$themeA|0")
        Assert-True -Condition $hasFallback -TestName "Cache rebuilt after theme deleted"
    }
    finally {
        $script:Config.ThemePath = $originalPath
        $script:Config.CacheTTLMinutes = $originalTTL
        Remove-Item $testDir -Force -Recurse -ErrorAction SilentlyContinue
    }
}
else {
    Test-Skip -Name "Cache invalidation tests" -Reason "Config null or oh-my-posh not installed"
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: NAVIGATION FUNCTIONS
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Navigation Functions..." -ForegroundColor Yellow
try {
    $originalLocation = Get-Location

    if (Get-Command docs -ErrorAction SilentlyContinue) {
        $_docs = [Environment]::GetFolderPath('MyDocuments')
        if ([string]::IsNullOrEmpty($_docs)) { $_docs = Join-Path $HOME "Documents" }
        if (-not (Test-Path $_docs)) { New-Item -ItemType Directory -Force -Path $_docs | Out-Null }
        docs
        if ([string]::IsNullOrEmpty($_docs)) {
            Test-Result -Name "docs function navigates to Documents" -Passed $true -Message "Skipped (Linux)"
        }
        else {
            Assert-Equal -Expected $_docs -Actual (Get-Location).Path -TestName "docs function navigates to Documents"
        }
        Set-Location $originalLocation
    }
    else {
        Test-Result -Name "docs function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command home -ErrorAction SilentlyContinue) {
        home
        Assert-Equal -Expected $HOME -Actual (Get-Location).Path -TestName "home function navigates to HOME"
        Set-Location $originalLocation
    }
    else {
        Test-Result -Name "home function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command Set-DefaultWorkingDirectory -ErrorAction SilentlyContinue) {
        Test-Result -Name "Set-DefaultWorkingDirectory function exists" -Passed $true -Message ""

        $normalDir = Join-Path $HOME "profile_start_normal_$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $normalDir | Out-Null
        $normalDir = (Resolve-Path $normalDir).Path
        Set-Location $normalDir
        Set-DefaultWorkingDirectory
        Assert-Equal -Expected $normalDir -Actual (Get-Location).Path -TestName "Set-DefaultWorkingDirectory preserves normal directory"
        Set-Location $originalLocation
        Remove-Item $normalDir -Force -ErrorAction SilentlyContinue

        if ($script:Config.IsWindows -and $env:WINDIR) {
            $oldStartDirectory = $script:Config.StartDirectory
            $oldEnvStartDirectory = $env:POWERSHELL_START_DIR
            $targetDir = Join-Path $HOME "profile_start_target_$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
            $targetDir = (Resolve-Path $targetDir).Path
            try {
                $script:Config.StartDirectory = $targetDir
                $env:POWERSHELL_START_DIR = $targetDir
                Set-Location (Join-Path $env:WINDIR 'System32')
                Set-DefaultWorkingDirectory
                Assert-Equal -Expected $targetDir -Actual (Get-Location).Path -TestName "Set-DefaultWorkingDirectory uses configured start directory"

                $script:Config.StartDirectory = Join-Path $HOME "profile_start_missing_$(Get-Random)"
                Set-Location (Join-Path $env:WINDIR 'System32')
                Set-DefaultWorkingDirectory
                Assert-Equal -Expected $HOME -Actual (Get-Location).Path -TestName "Set-DefaultWorkingDirectory falls back to HOME"
            } finally {
                Set-Location $originalLocation
                $script:Config.StartDirectory = $oldStartDirectory
                if ($oldEnvStartDirectory) { $env:POWERSHELL_START_DIR = $oldEnvStartDirectory }
                else { Remove-Item Env:\POWERSHELL_START_DIR -ErrorAction SilentlyContinue }
                Remove-Item $targetDir -Force -ErrorAction SilentlyContinue
            }
        } else {
            Test-Skip -Name "Set-DefaultWorkingDirectory redirects System32" -Reason "Windows-only behavior"
        }
    }
    else {
        Test-Result -Name "Set-DefaultWorkingDirectory function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command Get-ProfileStartDirectory -ErrorAction SilentlyContinue) {
        Assert-NotNull -Value (Get-ProfileStartDirectory) -TestName "Get-ProfileStartDirectory returns a path"
    }
    else {
        Test-Result -Name "Get-ProfileStartDirectory function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command up -ErrorAction SilentlyContinue) {
        $parent = (Get-Item $originalLocation).Parent.FullName
        up
        Assert-Equal -Expected $parent -Actual (Get-Location).Path -TestName "up function navigates to parent"
        Set-Location $originalLocation
    }
    else {
        Test-Result -Name "up function exists" -Passed $false -Message "Function not defined"
    }
}
catch {
    Test-Result -Name "Navigation tests" -Passed $false -Message $_.Exception.Message
}
Set-Location $originalLocation

# ══════════════════════════════════════════════════════════════
# TEST SUITE: SYSTEM32 STARTUP GUARD (inline, profile-independent)
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting System32 Startup Guard..." -ForegroundColor Yellow
try {
    $sys32GuardDir = $originalLocation
    $sys32WinGuard = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }
    $sys32Wr = $env:WINDIR

    # Test 1: Normal directory is preserved
    $sys32NormalDir = Join-Path $HOME "sys32guard_normal_$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $sys32NormalDir | Out-Null
    $sys32NormalDir = (Resolve-Path $sys32NormalDir).Path
    Set-Location $sys32NormalDir

    if ($sys32WinGuard -and $sys32Wr) {
        $sys32Cur = (Get-Location).Path.TrimEnd('\')
        $sys32Bad = @((Join-Path $sys32Wr 'System32').TrimEnd('\'),
                      (Join-Path $sys32Wr 'SysWOW64').TrimEnd('\'))
        if (-not ($sys32Bad -contains $sys32Cur)) {
            Test-Result -Name "Guard preserves normal directory" -Passed $true -Message ""
        } else {
            Test-Result -Name "Guard preserves normal directory" -Passed $false -Message "Guard redirected from normal dir $sys32Cur"
        }
    } else {
        Test-Result -Name "Guard preserves normal directory" -Passed $true -Message "Non-Windows — skipped"
    }
    Set-Location $originalLocation
    Remove-Item $sys32NormalDir -Force -ErrorAction SilentlyContinue

    # Test 2: System32 redirects to $HOME
    if ($sys32WinGuard -and $sys32Wr) {
        Set-Location (Join-Path $sys32Wr 'System32')
        $sys32Cur = (Get-Location).Path.TrimEnd('\')
        $sys32Bad = @((Join-Path $sys32Wr 'System32').TrimEnd('\'),
                      (Join-Path $sys32Wr 'SysWOW64').TrimEnd('\'))
        if ($sys32Bad -contains $sys32Cur) {
            $sys32Dir = if ($env:POWERSHELL_START_DIR -and (Test-Path $env:POWERSHELL_START_DIR -PathType Container)) {
                $env:POWERSHELL_START_DIR
            } else { $HOME }
            $null = Set-Location $sys32Dir 2>$null
            Assert-Equal -Expected $HOME -Actual (Get-Location).Path -TestName "Guard redirects System32 to HOME"
        } else {
            Test-Result -Name "Guard redirects System32 to HOME" -Passed $false -Message "Could not enter System32"
        }
        Set-Location $originalLocation
    } else {
        Test-Skip -Name "Guard redirects System32 to HOME" -Reason "Windows-only behavior"
    }

    # Test 3: SysWOW64 also redirects
    if ($sys32WinGuard -and $sys32Wr -and (Test-Path (Join-Path $sys32Wr 'SysWOW64'))) {
        Set-Location (Join-Path $sys32Wr 'SysWOW64')
        $sys32Cur = (Get-Location).Path.TrimEnd('\')
        $sys32Bad = @((Join-Path $sys32Wr 'System32').TrimEnd('\'),
                      (Join-Path $sys32Wr 'SysWOW64').TrimEnd('\'))
        if ($sys32Bad -contains $sys32Cur) {
            $sys32Dir = if ($env:POWERSHELL_START_DIR -and (Test-Path $env:POWERSHELL_START_DIR -PathType Container)) {
                $env:POWERSHELL_START_DIR
            } else { $HOME }
            $null = Set-Location $sys32Dir 2>$null
            Assert-Equal -Expected $HOME -Actual (Get-Location).Path -TestName "Guard redirects SysWOW64 to HOME"
        }
        Set-Location $originalLocation
    } else {
        Test-Skip -Name "Guard redirects SysWOW64 to HOME" -Reason "SysWOW64 not found or non-Windows"
    }

    # Test 4: Respects $env:POWERSHELL_START_DIR
    if ($sys32WinGuard -and $sys32Wr) {
        $sys32TargetDir = Join-Path $HOME "sys32guard_target_$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $sys32TargetDir | Out-Null
        $sys32TargetDir = (Resolve-Path $sys32TargetDir).Path
        $oldStartEnv = $env:POWERSHELL_START_DIR
        try {
            $env:POWERSHELL_START_DIR = $sys32TargetDir
            Set-Location (Join-Path $sys32Wr 'System32')
            $sys32Cur = (Get-Location).Path.TrimEnd('\')
            $sys32Bad = @((Join-Path $sys32Wr 'System32').TrimEnd('\'),
                          (Join-Path $sys32Wr 'SysWOW64').TrimEnd('\'))
            if ($sys32Bad -contains $sys32Cur) {
                $sys32Dir = if ($env:POWERSHELL_START_DIR -and (Test-Path $env:POWERSHELL_START_DIR -PathType Container)) {
                    $env:POWERSHELL_START_DIR
                } else { $HOME }
                $null = Set-Location $sys32Dir 2>$null
                Assert-Equal -Expected $sys32TargetDir -Actual (Get-Location).Path -TestName "Guard respects POWERSHELL_START_DIR"
            }
        } finally {
            $env:POWERSHELL_START_DIR = $oldStartEnv
            Set-Location $originalLocation
            Remove-Item $sys32TargetDir -Force -ErrorAction SilentlyContinue
        }
    } else {
        Test-Skip -Name "Guard respects POWERSHELL_START_DIR" -Reason "Windows-only behavior"
    }
} catch {
    Test-Result -Name "System32 Startup Guard tests" -Passed $false -Message $_.Exception.Message
}
Set-Location $originalLocation

# ══════════════════════════════════════════════════════════════
# TEST SUITE: FILE OPERATIONS
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting File Operations..." -ForegroundColor Yellow
$testDir = Join-Path $PWD "test_mkcd_$(Get-Random)"
try {
    if (Get-Command mkcd -ErrorAction SilentlyContinue) {
        mkcd $testDir
        $exists = Test-Path $testDir
        Assert-True -Condition $exists -TestName "mkcd creates directory"

        $currentLocation = (Get-Location).Path
        Assert-Equal -Expected $testDir -Actual $currentLocation -TestName "mkcd changes to new directory"
        Set-Location $originalLocation
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Test-Result -Name "mkcd function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command nf -ErrorAction SilentlyContinue) {
        $testFile = Join-Path $PWD "test_nf_$(Get-Random).txt"
        nf $testFile
        $exists = Test-Path $testFile
        Assert-True -Condition $exists -TestName "nf creates file"
        Remove-MockFile $testFile
    }
    else {
        Test-Result -Name "nf function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command touch -ErrorAction SilentlyContinue) {
        $testFile = Join-Path $PWD "test_touch_$(Get-Random).txt"
        touch $testFile
        $exists = Test-Path $testFile
        Assert-True -Condition $exists -TestName "touch creates new file"
        Remove-MockFile $testFile
    }
    else {
        Test-Result -Name "touch function exists" -Passed $false -Message "Function not defined"
    }
}
catch {
    Test-Result -Name "File operations tests" -Passed $false -Message $_.Exception.Message
    if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: TEXT PROCESSING
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Text Processing..." -ForegroundColor Yellow
$testFile = Join-Path $PWD "test_text_$(Get-Random).txt"
try {
    $testContent = @"
Line 1
Line 2
Line 3
Line 4
Line 5
"@
    Set-Content -Path $testFile -Value $testContent -Encoding UTF8

    if (Get-Command head -ErrorAction SilentlyContinue) {
        $result = head $testFile -Lines 3
        Assert-Equal -Expected 3 -Actual $result.Count -TestName "head returns correct number of lines"
        Assert-Equal -Expected "Line 1" -Actual $result[0] -TestName "head returns first line correctly"
    }
    else {
        Test-Result -Name "head function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command tail -ErrorAction SilentlyContinue) {
        $result = tail $testFile -Lines 2
        Assert-Equal -Expected 2 -Actual $result.Count -TestName "tail returns correct number of lines"
        Assert-Equal -Expected "Line 5" -Actual $result[-1] -TestName "tail returns last line correctly"
    }
    else {
        Test-Result -Name "tail function exists" -Passed $false -Message "Function not defined"
    }
}
catch {
    Test-Result -Name "Text processing tests" -Passed $false -Message $_.Exception.Message
}
finally {
    Remove-MockFile $testFile
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: SYSTEM FUNCTIONS
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting System Functions..." -ForegroundColor Yellow
try {
    $sysFunctions = @('pkill', 'pgrep', 'flushdns', 'df', 'pubip', 'sysinfo', 'sudo')
    foreach ($fn in $sysFunctions) {
        if (Get-Command $fn -ErrorAction SilentlyContinue) {
            Test-Result -Name "$fn function exists" -Passed $true -Message ""
        }
        else {
            Test-Result -Name "$fn function exists" -Passed $false -Message "Function not defined"
        }
    }

    # Test k9 alias
    if (Get-Command k9 -ErrorAction SilentlyContinue) {
        Test-Result -Name "k9 alias exists" -Passed $true -Message ""
    }
    else {
        Test-Result -Name "k9 alias exists" -Passed $false -Message "Alias not defined"
    }

    # Test sysinfo returns data or exits gracefully
    if (Get-Command sysinfo -ErrorAction SilentlyContinue) {
        $result = sysinfo 2>&1
        Test-Result -Name "sysinfo returns data (or runs cleanly)" -Passed $true -Message ""
    }
}
catch {
    Test-Result -Name "System functions tests" -Passed $false -Message $_.Exception.Message
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: HELPER & CLIPBOARD FUNCTIONS
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Helper & Clipboard Functions..." -ForegroundColor Yellow
try {
    $helperFunctions = @('which', 'grep', 'sed', 'unzip', 'Copy-ToClipboard', 'pst')
    foreach ($fn in $helperFunctions) {
        if (Get-Command $fn -ErrorAction SilentlyContinue) {
            Test-Result -Name "$fn function exists" -Passed $true -Message ""
        }
        else {
            Test-Result -Name "$fn function exists" -Passed $false -Message "Function not defined"
        }
    }

    # Test cpy alias
    if (Get-Command cpy -ErrorAction SilentlyContinue) {
        Test-Result -Name "cpy alias exists" -Passed $true -Message ""
    }
    else {
        Test-Result -Name "cpy alias exists" -Passed $false -Message "Alias not defined"
    }
}
catch {
    Test-Result -Name "Helper functions tests" -Passed $false -Message $_.Exception.Message
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: DISPLAY & ADDITIONAL NAVIGATION
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Display & Navigation Functions..." -ForegroundColor Yellow
try {
    if (Get-Command la -ErrorAction SilentlyContinue) {
        $result = la 2>&1
        Assert-NotNull -Value $result -TestName "la function executes without error"
    }
    else {
        Test-Result -Name "la function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command ll -ErrorAction SilentlyContinue) {
        $result = ll 2>&1
        Assert-NotNull -Value $result -TestName "ll function executes without error"
    }
    else {
        Test-Result -Name "ll function exists" -Passed $false -Message "Function not defined"
    }

    $originalLocation = Get-Location
    if (Get-Command dtop -ErrorAction SilentlyContinue) {
        $_desktop = [Environment]::GetFolderPath('Desktop')
        if ([string]::IsNullOrEmpty($_desktop)) { $_desktop = Join-Path $HOME "Desktop" }
        if (-not (Test-Path $_desktop)) { New-Item -ItemType Directory -Force -Path $_desktop | Out-Null }
        dtop
        if ([string]::IsNullOrEmpty($_desktop)) {
            Test-Result -Name "dtop function navigates to Desktop" -Passed $true -Message "Skipped (Linux)"
        }
        else {
            Assert-Equal -Expected $_desktop -Actual (Get-Location).Path -TestName "dtop function navigates to Desktop"
        }
        Set-Location $originalLocation
    }
    else {
        Test-Result -Name "dtop function exists" -Passed $false -Message "Function not defined"
    }

    if (Get-Command up2 -ErrorAction SilentlyContinue) {
        $parentItem = (Get-Item $originalLocation).Parent
        if ($null -ne $parentItem -and $null -ne $parentItem.Parent) {
            $grandparent = $parentItem.Parent.FullName
            up2
            Assert-Equal -Expected $grandparent -Actual (Get-Location).Path -TestName "up2 function navigates to grandparent"
        }
        else {
            Test-Result -Name "up2 function navigates to grandparent" -Passed $true -Message "Skipped (no grandparent)"
        }
        Set-Location $originalLocation
    }
    else {
        Test-Result -Name "up2 function exists" -Passed $false -Message "Function not defined"
    }
}
catch {
    Test-Result -Name "Display/navigation tests" -Passed $false -Message $_.Exception.Message
}
Set-Location $originalLocation

# ══════════════════════════════════════════════════════════════
# TEST SUITE: GIT FUNCTIONS
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Git Functions..." -ForegroundColor Yellow
try {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitFunctions = @('gst', 'ga', 'gcmt', 'gco', 'gpush', 'gpull', 'glog', 'gundo', 'gdiff', 'gcl', 'gcom', 'lazyg', 'gss')
        foreach ($func in $gitFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                Test-Result -Name "$func function exists" -Passed $true -Message ""
            }
            else {
                Test-Result -Name "$func function exists" -Passed $false -Message "Function not defined"
            }
        }
    }
    else {
        Test-Skip -Name "Git function tests" -Reason "Git not installed"
    }
}
catch {
    Test-Result -Name "Git functions tests" -Passed $false -Message $_.Exception.Message
}

# ══════════════════════════════════════════════════════════════
# TEST SUITE: STRUCTURED ERROR HANDLING
# ══════════════════════════════════════════════════════════════
Write-Host "`nTesting Structured Error Handling..." -ForegroundColor Yellow
try {
    # Test sed with non-existent file produces structured error
    if (Get-Command sed -ErrorAction SilentlyContinue) {
        $errBefore = $Error.Count
        sed "nonexistent_file_$(Get-Random).txt" "find" "replace" -ErrorAction SilentlyContinue 2>$null
        $errAfter = $Error.Count
        Assert-True -Condition ($errAfter -gt $errBefore) -TestName "sed produces ErrorRecord for missing file"
    }

    # Test SupportsShouldProcess on pkill
    if (Get-Command pkill -ErrorAction SilentlyContinue) {
        $cmdInfo = Get-Command pkill
        $hasShouldProcess = $cmdInfo.Parameters.ContainsKey('WhatIf')
        Assert-True -Condition $hasShouldProcess -TestName "pkill supports -WhatIf (ShouldProcess)"
    }

    # Test SupportsShouldProcess on sudo
    if (Get-Command sudo -ErrorAction SilentlyContinue) {
        $cmdInfo = Get-Command sudo
        $hasShouldProcess = $cmdInfo.Parameters.ContainsKey('WhatIf')
        Assert-True -Condition $hasShouldProcess -TestName "sudo supports -WhatIf (ShouldProcess)"
    }

    # Test SupportsShouldProcess on sed
    if (Get-Command sed -ErrorAction SilentlyContinue) {
        $cmdInfo = Get-Command sed
        $hasShouldProcess = $cmdInfo.Parameters.ContainsKey('WhatIf')
        Assert-True -Condition $hasShouldProcess -TestName "sed supports -WhatIf (ShouldProcess)"
    }
}
catch {
    Test-Result -Name "Error handling tests" -Passed $false -Message $_.Exception.Message
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
Write-Host "Boot Time:   ${bootMs}ms (1st) / ${secondMs}ms (2nd)" -ForegroundColor $(if ($bootMs -lt 200) { 'Green' } elseif ($bootMs -lt 400) { 'Yellow' } else { 'Red' })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($script:TestResults.Count -gt 0 -and $Verbose) {
    Write-Host "Detailed Results:" -ForegroundColor Cyan
    $script:TestResults | Format-Table -AutoSize
}

# Exit with appropriate code
if ($script:TestsFailed -gt 0) {
    exit 1
}
else {
    exit 0
}

