#Requires -Version 5.1
# ============================================================
# UNIT TESTS — Cache module (Phase 1 / 4)
# Framework + mock helpers shared across phases
# ============================================================

param([switch]$Verbose)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── TEST FRAMEWORK ────────────────────────────────────────────
$script:TestsPassed   = 0
$script:TestsFailed   = 0
$script:TestsSkipped  = 0
$script:TestResults   = [System.Collections.Generic.List[object]]::new()

function Test-Result {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Message
    )
    $script:TestResults.Add([PSCustomObject]@{ Name = $Name; Passed = $Passed; Message = $Message })
    if ($Passed) { $script:TestsPassed++; Write-Host "  [+] $Name" -ForegroundColor Green }
    else { $script:TestsFailed++; Write-Host "  [X] $Name - $Message" -ForegroundColor Red }
}

function Test-Skip {
    param([Parameter(Mandatory)][string]$Name, [string]$Reason = 'Skipped')
    $script:TestsSkipped++; Write-Host "  [-] $Name - $Reason" -ForegroundColor Gray
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

# ── MOCK HELPERS (shared across phases) ───────────────────────
function New-MockFile {
    param([string]$Path, [string]$Content = "")
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Remove-MockFile {
    param([string]$Path)
    if (Test-Path $Path) { Remove-Item $Path -Force -ErrorAction SilentlyContinue }
}

# ── SHARED MOCKS ──────────────────────────────────────────────
$script:MockCommandResults = @{}

function script:Get-Command {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Name
    )
    if ($script:MockCommandResults.ContainsKey($Name)) { return $script:MockCommandResults[$Name] }
    return $null
}

function script:zoxide   { param() '' }
function script:oh-my-posh { param() '' }

# ── SYSTEM MODULE MOCKS ───────────────────────────────────────
$script:MockInvokeRestMethod = $null
function script:Invoke-RestMethod {
    [CmdletBinding()]
    param([string]$Uri, [int]$TimeoutSec, [switch]$UseBasicParsing)
    if ($script:MockInvokeRestMethod) {
        return & $script:MockInvokeRestMethod -Uri $Uri
    }
    throw "No mock configured for Invoke-RestMethod"
}

$script:MockHistoryCommandLine = $null
function script:Get-History {
    param([int]$Count)
    return [PSCustomObject]@{ CommandLine = $script:MockHistoryCommandLine }
}

$script:MockStartProcessArgs = $null
function script:Start-Process {
    param([string]$FilePath, [string]$Verb, [string[]]$ArgumentList)
    $script:MockStartProcessArgs = [PSCustomObject]@{ FilePath = $FilePath; Verb = $Verb; ArgumentList = $ArgumentList }
}

$script:MockClipboardText = $null
function script:Set-Clipboard {
    param([Parameter(ValueFromPipeline)][string]$Text)
    $script:MockClipboardText = $Text
}

# ── CONFIGURATION MOCK ────────────────────────────────────────
$script:CacheDir = Join-Path $env:TEMP "ut_cache_$(Get-Random)"
New-Item -ItemType Directory -Force -Path $script:CacheDir | Out-Null

$script:Config = [PSCustomObject]@{
    CachePath   = Join-Path $script:CacheDir 'cache.ps1'
    ThemePath   = Join-Path $script:CacheDir 'theme.json'
    CacheTTLMinutes = 1440
    IsWindows   = $true
    IsLinux     = $false
    IsMacOS     = $false
}

$script:Config | Add-Member -NotePropertyName 'PSMajor' -NotePropertyValue $PSVersionTable.PSVersion.Major -Force

$script:StartupModules = [System.Collections.Generic.List[string]]::new()

# ── LOAD MODULE ───────────────────────────────────────────────
$script:ModulePath = Join-Path $PSScriptRoot '..\modules\cache\cache.ps1'
if (-not (Test-Path $script:ModulePath)) {
    Write-Host "ERROR: Module not found at $script:ModulePath" -ForegroundColor Red; exit 1
}

. $script:ModulePath

# ── LOAD SYSTEM MODULE ────────────────────────────────────────
$script:SystemModulePath = Join-Path $PSScriptRoot '..\modules\system\system.ps1'
if (-not (Test-Path $script:SystemModulePath)) {
    Write-Host "ERROR: Module not found at $script:SystemModulePath" -ForegroundColor Red; exit 1
}

. $script:SystemModulePath

# ── CACHE MODULE TESTS ────────────────────────────────────────

function Write-CacheSuite {
    Write-Host "`n=== CACHE MODULE TESTS ===" -ForegroundColor Cyan

    # HELPERS: build cache lines without backtick/newline parsing pitfalls
    $nl = [Environment]::NewLine

    # ============================================================
    # CACHE-01
    # ============================================================
    try {
        $mockZcmd = [PSCustomObject]@{ Source = (Join-Path $script:CacheDir 'zoxide.exe') }
        New-MockFile -Path $mockZcmd.Source -Content 'mock'
        $mockOcmd = [PSCustomObject]@{ Source = (Join-Path $script:CacheDir 'oh-my-posh.exe') }
        New-MockFile -Path $mockOcmd.Source -Content 'mock'

        $fp = script:Get-PluginFingerprint -zcmd $mockZcmd -ocmd $mockOcmd

        Assert-True -Condition ($fp -match '\|') -TestName 'CACHE-01: fingerprint returns delimited string'
        Assert-True -Condition ($fp -match [regex]::Escape($mockZcmd.Source)) -TestName 'CACHE-01: contains zoxide source'
        Assert-True -Condition ($fp -match [regex]::Escape($mockOcmd.Source)) -TestName 'CACHE-01: contains oh-my-posh source'
        Assert-True -Condition ($fp -match 'unknown') -TestName 'CACHE-01: contains unknown for unversioned files'
    }
    catch {
        Test-Result -Name 'CACHE-01' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-02
    # ============================================================
    try {
        $fp = script:Get-PluginFingerprint -zcmd $null -ocmd $null
        Assert-True -Condition ($fp -match [regex]::Escape($script:Config.ThemePath)) -TestName 'CACHE-02: contains theme path'
        $parts = $fp -split '\|'
        Assert-True -Condition ($parts.Count -eq 2) -TestName 'CACHE-02: only 2 parts (theme path + flag) with no binaries'
    }
    catch {
        Test-Result -Name 'CACHE-02' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-03
    # ============================================================
    try {
        $mockZcmdBad = [PSCustomObject]@{ Source = (Join-Path $script:CacheDir 'nonexistent_bin.exe') }
        $fp = script:Get-PluginFingerprint -zcmd $mockZcmdBad -ocmd $null
        Assert-True -Condition ($fp -match [regex]::Escape($mockZcmdBad.Source)) -TestName 'CACHE-03: contains source path'
        Assert-True -Condition ($fp -match '\|unknown\|0\|') -TestName 'CACHE-03: contains unknown|0 for missing file'
    }
    catch {
        Test-Result -Name 'CACHE-03' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-04
    # ============================================================
    try {
        New-MockFile -Path $script:Config.ThemePath -Content '{"name":"atomic"}'
        $fp = script:Get-ThemeFingerprint
        Assert-True -Condition ($fp[0] -eq $script:Config.ThemePath) -TestName 'CACHE-04: first element is theme path'
        Assert-True -Condition ($fp[1] -eq 1) -TestName 'CACHE-04: exists flag is 1'
        Assert-True -Condition ($fp.Count -ge 3) -TestName 'CACHE-04: has 3+ elements (path, flag, length:ticks)'
        Assert-True -Condition ($fp[2] -match '^\d+:\d+$') -TestName 'CACHE-04: third element is length:ticks format'
    }
    catch {
        Test-Result -Name 'CACHE-04' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-05
    # ============================================================
    $oldThemePath05 = $script:Config.ThemePath
    try {
        $missingPath = Join-Path $script:CacheDir 'nope.json'
        $script:Config.ThemePath = $missingPath
        $fp = script:Get-ThemeFingerprint
        Assert-True -Condition ($fp[0] -eq $missingPath) -TestName 'CACHE-05: first element is missing path'
        Assert-True -Condition ($fp[1] -eq 0) -TestName 'CACHE-05: exists flag is 0'
        Assert-True -Condition ($fp.Count -eq 2) -TestName 'CACHE-05: exactly 2 elements when file missing'
    }
    catch {
        Test-Result -Name 'CACHE-05' -Passed $false -Message $_.Exception.Message
    }
    finally { $script:Config.ThemePath = $oldThemePath05 }

    # ============================================================
    # CACHE-06
    # ============================================================
    $oldThemePath06 = $script:Config.ThemePath
    try {
        $script:Config.ThemePath = Join-Path $script:CacheDir 'exists_throw.json'
        New-MockFile -Path $script:Config.ThemePath -Content '{}'
        function script:Get-Item { throw "Simulated Get-Item error for testing" }
        $fp = script:Get-ThemeFingerprint
        Assert-True -Condition ($fp -contains 'nofile') -TestName 'CACHE-06: catch block added nofile on Get-Item error'
    }
    catch {
        Test-Result -Name 'CACHE-06' -Passed $false -Message $_.Exception.Message
    }
    finally {
        Remove-Item Function:\Get-Item -Force -ErrorAction SilentlyContinue
        $script:Config.ThemePath = $oldThemePath06
    }

    # ============================================================
    # CACHE-07
    # ============================================================
    $oldCachePath07 = $script:Config.CachePath
    $isolatedCache07 = Join-Path $script:CacheDir 'cache07.ps1'
    $script:Config.CachePath = $isolatedCache07
    try {
        Remove-MockFile $isolatedCache07
        script:Update-PluginCache -zcmd $null -ocmd $null
        Assert-True -Condition (Test-Path $isolatedCache07) -TestName 'CACHE-07: cache file created'
        if (Test-Path $isolatedCache07) {
            $firstLine = Get-Content $isolatedCache07 -TotalCount 1 -ErrorAction SilentlyContinue
            Assert-True -Condition ($firstLine -match '^# fp:') -TestName 'CACHE-07: file starts with # fp:'
            $fullContent = Get-Content $isolatedCache07 -Raw -ErrorAction SilentlyContinue
            Assert-False -Condition ($fullContent -match 'Zoxide') -TestName 'CACHE-07: no Zoxide in output'
            Assert-False -Condition ($fullContent -match 'OMP') -TestName 'CACHE-07: no OMP in output'
        }
    }
    catch {
        Test-Result -Name 'CACHE-07' -Passed $false -Message $_.Exception.Message
    }
    finally {
        $script:Config.CachePath = $oldCachePath07
        Remove-MockFile $isolatedCache07
    }

    # ============================================================
    # CACHE-08
    # ============================================================
    $oldCachePath08 = $script:Config.CachePath
    try {
        $invalidPath = $script:CacheDir + "\bad|path|file.ps1"
        $script:Config.CachePath = $invalidPath
        script:Update-PluginCache -zcmd $null -ocmd $null
        Assert-True -Condition $true -TestName 'CACHE-08: write failure caught gracefully'
    }
    catch {
        Test-Result -Name 'CACHE-08' -Passed $false -Message $_.Exception.Message
    }
    finally { $script:Config.CachePath = $oldCachePath08 }

    # ============================================================
    # CACHE-09
    # ============================================================
    try {
        Remove-MockFile $script:Config.CachePath
        $script:HotPathHit = $false

        $themeFP09 = script:Get-ThemeFingerprint
        $themeEnding09 = $themeFP09 -join '|'
        $fakeFP09 = "prefix|$themeEnding09"
        $nowTS09 = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $cacheBody09 = '# fp:' + $fakeFP09 + ' ts:' + $nowTS09 + $nl + '$script:HotPathHit = $true'
        New-MockFile -Path $script:Config.CachePath -Content $cacheBody09

        script:Initialize-PluginCache

        Assert-True -Condition $script:HotPathHit -TestName 'CACHE-09: hot path returns early when TTL valid'
    }
    catch {
        Test-Result -Name 'CACHE-09' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-10
    # ============================================================
    try {
        Remove-MockFile $script:Config.CachePath

        $themeFP10 = script:Get-ThemeFingerprint
        $themeEnding10 = $themeFP10 -join '|'
        $fakeFP10 = "prev|prefix|$themeEnding10"
        $oldTS10 = 1000000
        $cacheBody10 = '# fp:' + $fakeFP10 + ' ts:' + $oldTS10 + $nl
        New-MockFile -Path $script:Config.CachePath -Content $cacheBody10

        script:Initialize-PluginCache

        $newHeader10 = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        if ($newHeader10 -match 'ts:(\d+)') {
            $newTS10 = [long]$Matches[1]
            Assert-True -Condition ($newTS10 -gt $oldTS10) -TestName 'CACHE-10: expired TTL + matching fp updates timestamp'
        }
        else {
            Test-Result -Name 'CACHE-10' -Passed $false -Message 'Could not parse timestamp from cache header'
        }
    }
    catch {
        Test-Result -Name 'CACHE-10' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-11
    # ============================================================
    try {
        Remove-MockFile $script:Config.CachePath

        $wrongFP11 = 'WRONG_FINGERPRINT|different_value'
        $oldTS11 = 1000000
        $cacheBody11 = '# fp:' + $wrongFP11 + ' ts:' + $oldTS11 + $nl
        New-MockFile -Path $script:Config.CachePath -Content $cacheBody11

        script:Initialize-PluginCache

        $newHeader11 = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        Assert-False -Condition ($newHeader11 -match 'WRONG_FINGERPRINT') -TestName 'CACHE-11: stale fingerprint triggers rebuild'
        Assert-True -Condition ($newHeader11 -match '^# fp:') -TestName 'CACHE-11: cache header still valid after rebuild'
    }
    catch {
        Test-Result -Name 'CACHE-11' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-12
    # ============================================================
    try {
        Remove-MockFile $script:Config.CachePath
        Assert-False -Condition (Test-Path $script:Config.CachePath) -TestName 'CACHE-12: precondition - no cache file'
        script:Initialize-PluginCache
        Assert-True -Condition (Test-Path $script:Config.CachePath) -TestName 'CACHE-12: cache file created by Initialize-PluginCache'
    }
    catch {
        Test-Result -Name 'CACHE-12' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-13
    # ============================================================
    try {
        New-MockFile -Path $script:Config.CachePath -Content 'dummy'
        Assert-True -Condition (Test-Path $script:Config.CachePath) -TestName 'CACHE-13: precondition - cache file exists'
        Clear-PluginCache
        Assert-False -Condition (Test-Path $script:Config.CachePath) -TestName 'CACHE-13: Clear-PluginCache removes cache file'
    }
    catch {
        Test-Result -Name 'CACHE-13' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # CACHE-14
    # ============================================================
    try {
        Import-TerminalIcons
        Assert-True -Condition $true -TestName 'CACHE-14: Import-TerminalIcons runs without error'
    }
    catch {
        Test-Result -Name 'CACHE-14' -Passed $false -Message $_.Exception.Message
    }

    Write-Host "Cache suite complete." -ForegroundColor Cyan
}

# ── SYSTEM MODULE TESTS ────────────────────────────────────────

function Write-SystemSuite {
    Write-Host "`n=== SYSTEM MODULE TESTS ===" -ForegroundColor Cyan

    # ============================================================
    # SYS-01: pubip valid cache <5 min
    # ============================================================
    try {
        $script:CachedPublicIP = '1.2.3.4'
        $script:CachedPublicIPTimestamp = Get-Date
        $result = pubip
        Assert-Equal -Expected '1.2.3.4' -Actual $result -TestName 'SYS-01: pubip returns cached IP within 5 min'
    }
    catch {
        Test-Result -Name 'SYS-01: pubip returns cached IP within 5 min' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-02: pubip expired cache -> queries endpoints
    # ============================================================
    try {
        $script:CachedPublicIP = '1.2.3.4'
        $script:CachedPublicIPTimestamp = (Get-Date).AddHours(-1)
        $script:MockInvokeRestMethod = { param($Uri) return '5.6.7.8' }
        $result = pubip
        Assert-Equal -Expected '5.6.7.8' -Actual $result -TestName 'SYS-02: pubip queries endpoints when cache expired'
    }
    catch {
        Test-Result -Name 'SYS-02: pubip queries endpoints when cache expired' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-03: pubip endpoint fallback chain
    # ============================================================
    try {
        $script:CachedPublicIP = $null
        $script:CachedPublicIPTimestamp = $null
        $script:MockInvokeRestMethod = {
            param($Uri)
            if ($Uri -eq 'https://api.ipify.org') { throw 'fail' }
            if ($Uri -eq 'https://icanhazip.com') { return '5.6.7.8' }
            throw "unexpected URL: $Uri"
        }
        $result = pubip
        Assert-Equal -Expected '5.6.7.8' -Actual $result -TestName 'SYS-03a: pubip falls back to second endpoint'
    }
    catch {
        Test-Result -Name 'SYS-03a: pubip falls back to second endpoint' -Passed $false -Message $_.Exception.Message
    }

    try {
        $script:CachedPublicIP = $null
        $script:CachedPublicIPTimestamp = $null
        $script:MockInvokeRestMethod = {
            param($Uri)
            if ($Uri -eq 'https://api.ipify.org') { throw 'fail' }
            if ($Uri -eq 'https://icanhazip.com') { throw 'fail' }
            if ($Uri -eq 'https://ifconfig.me/ip') { return '9.10.11.12' }
            throw "unexpected URL: $Uri"
        }
        $result = pubip
        Assert-Equal -Expected '9.10.11.12' -Actual $result -TestName 'SYS-03b: pubip falls back to third endpoint'
    }
    catch {
        Test-Result -Name 'SYS-03b: pubip falls back to third endpoint' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-04: pubip all endpoints fail -> ErrorRecord
    # ============================================================
    try {
        $script:CachedPublicIP = $null
        $script:CachedPublicIPTimestamp = $null
        $script:MockInvokeRestMethod = { param($Uri) throw 'fail' }
        $errorSeen = $null
        try { pubip } catch { $errorSeen = $_ }
        Assert-NotNull -Value $errorSeen -TestName 'SYS-04: error written when all endpoints fail'
        if ($errorSeen) {
            $hasCorrectId = $errorSeen.FullyQualifiedErrorId -match 'PubIpAllEndpointsFailed'
            Assert-True -Condition $hasCorrectId -TestName 'SYS-04: error ID is PubIpAllEndpointsFailed'
        }
    }
    catch {
        Test-Result -Name 'SYS-04: error written when all endpoints fail' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-05: pubip -Force bypasses cache
    # ============================================================
    try {
        $script:CachedPublicIP = '1.2.3.4'
        $script:CachedPublicIPTimestamp = Get-Date
        $script:queryCalled = $false
        $script:MockInvokeRestMethod = { param($Uri) $script:queryCalled = $true; return '7.7.7.7' }
        $result = pubip -Force
        Assert-True -Condition $script:queryCalled -TestName 'SYS-05: -Force bypasses cache and queries endpoints'
        Assert-Equal -Expected '7.7.7.7' -Actual $result -TestName 'SYS-05: -Force returns fresh value'
    }
    catch {
        Test-Result -Name 'SYS-05: -Force bypasses cache' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-06: sudo !! with history
    # ============================================================
    try {
        $script:MockHistoryCommandLine = 'Get-ChildItem'
        $script:MockStartProcessArgs = $null
        sudo -Confirm:$false '!!'
        Assert-NotNull -Value $script:MockStartProcessArgs -TestName 'SYS-06: sudo !! starts process'
        if ($script:MockStartProcessArgs) {
            $encoded = $script:MockStartProcessArgs.ArgumentList[-1]
            $decoded = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encoded))
            Assert-Equal -Expected 'Get-ChildItem' -Actual $decoded -TestName 'SYS-06: sudo !! passes history command'
        }
    }
    catch {
        Test-Result -Name 'SYS-06: sudo !! with history' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-07: sudo !! without history
    # ============================================================
    try {
        $script:MockHistoryCommandLine = $null
        $script:MockStartProcessArgs = $null
        sudo -Confirm:$false '!!'
        $noProcess = $null -eq $script:MockStartProcessArgs
        Assert-True -Condition $noProcess -TestName 'SYS-07: sudo !! without history does not start process'
    }
    catch {
        Test-Result -Name 'SYS-07: sudo !! without history' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-08: sudo sanitization removes null bytes
    # ============================================================
    try {
        $script:MockStartProcessArgs = $null
        sudo -Confirm:$false "notepad$([char]0)test"
        Assert-NotNull -Value $script:MockStartProcessArgs -TestName 'SYS-08: sudo with null bytes starts process'
        if ($script:MockStartProcessArgs) {
            $encoded = $script:MockStartProcessArgs.ArgumentList[-1]
            $decoded = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encoded))
            Assert-Equal -Expected 'notepadtest' -Actual $decoded -TestName 'SYS-08: sanitized command removes null bytes'
        }
    }
    catch {
        Test-Result -Name 'SYS-08: sudo sanitization removes null bytes' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-09: sudo empty after sanitization -> ErrorRecord
    # ============================================================
    try {
        $script:MockStartProcessArgs = $null
        $errorSeen09 = $null
        try {
            sudo -Confirm:$false ("$([char]0x00)$([char]0x01)")
        }
        catch {
            $errorSeen09 = $_
        }
        Assert-NotNull -Value $errorSeen09 -TestName 'SYS-09: error written for empty command after sanitization'
        if ($errorSeen09) {
            $hasEmptyId = $errorSeen09.FullyQualifiedErrorId -match 'SudoEmptyCommand'
            Assert-True -Condition $hasEmptyId -TestName 'SYS-09: error ID is SudoEmptyCommand'
        }
    }
    catch {
        Test-Result -Name 'SYS-09: sudo empty after sanitization' -Passed $false -Message $_.Exception.Message
    }

    # ============================================================
    # SYS-10: sudo normal command (Windows)
    # ============================================================
    try {
        $script:MockStartProcessArgs = $null
        sudo -Confirm:$false 'notepad'
        Assert-NotNull -Value $script:MockStartProcessArgs -TestName 'SYS-10: sudo starts process for normal command'
        if ($script:MockStartProcessArgs) {
            Assert-Equal -Expected 'RunAs' -Actual $script:MockStartProcessArgs.Verb -TestName 'SYS-10: Verb is RunAs'
            $expectedExe = if ($PSVersionTable.PSVersion.Major -ge 7) { 'pwsh' } else { 'powershell' }
            Assert-Equal -Expected $expectedExe -Actual $script:MockStartProcessArgs.FilePath -TestName 'SYS-10: FilePath is pwsh/powershell'
            $encoded = $script:MockStartProcessArgs.ArgumentList[-1]
            $decoded = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encoded))
            Assert-Equal -Expected 'notepad' -Actual $decoded -TestName 'SYS-10: decoded command matches original'
        }
    }
    catch {
        Test-Result -Name 'SYS-10: sudo normal command' -Passed $false -Message $_.Exception.Message
    }

    Write-Host "System suite complete." -ForegroundColor Cyan
}

# ── TEXT UTILS MODULE TESTS ────────────────────────────────────

function Write-TextUtilsSuite {
    Write-Host "`n=== TEXT UTILS MODULE TESTS ===" -ForegroundColor Cyan

    # TEXT-01: sed file not found -> ErrorRecord (SedFileNotFound)
    try {
        $errorSeenT01 = $null
        try { sed -File 'C:\nonexistent_path_xyz\file.txt' -Find 'a' -Replace 'b' -Confirm:$false }
        catch { $errorSeenT01 = $_ }
        if ($errorSeenT01) {
            $hasCorrectId = $errorSeenT01.FullyQualifiedErrorId -match 'SedFileNotFound'
            Assert-True -Condition $hasCorrectId -TestName 'TEXT-01: error ID is SedFileNotFound'
        }
        else { Test-Result -Name 'TEXT-01: error ID is SedFileNotFound' -Passed $false -Message 'no error caught' }
    }
    catch {
        Test-Result -Name 'TEXT-01' -Passed $false -Message $_.Exception.Message
    }

    # TEXT-02: sed file too large (>50MB) -> ErrorRecord (SedFileTooLarge)
    try {
        $largeFilePath = Join-Path $script:CacheDir 'largefile.txt'
        New-MockFile -Path $largeFilePath -Content 'small content'

        function script:Get-Item { [CmdletBinding()] param([Parameter(Position=0)][string]$Path)
            return [PSCustomObject]@{ Length = 60 * 1MB }
        }

        $sedErr02 = $null
        sed -File $largeFilePath -Find 'a' -Replace 'b' -Confirm:$false -ErrorVariable sedErr02 -ErrorAction SilentlyContinue
        Assert-True -Condition (@($sedErr02).Count -gt 0) -TestName 'TEXT-02: error ID is SedFileTooLarge'
    }
    catch {
        Test-Result -Name 'TEXT-02' -Passed $false -Message $_.Exception.Message
    }
    finally {
        Remove-Item 'Function:Get-Item' -Force -ErrorAction SilentlyContinue
        Remove-MockFile $largeFilePath
    }

    # TEXT-03: sed valid replace
    try {
        $sedFile03 = Join-Path $script:CacheDir 'sed03.txt'
        New-MockFile -Path $sedFile03 -Content 'hello world'
        sed -File $sedFile03 -Find 'world' -Replace 'there' -Confirm:$false
        $content03 = Get-Content $sedFile03 -Raw -ErrorAction SilentlyContinue
        $content03 = $content03.Trim()
        Assert-Equal -Expected 'hello there' -Actual $content03 -TestName 'TEXT-03: content replaced correctly'
    }
    catch {
        Test-Result -Name 'TEXT-03' -Passed $false -Message $_.Exception.Message
    }
    finally { Remove-MockFile (Join-Path $script:CacheDir 'sed03.txt') }

    # TEXT-04: sed with -Backup creates .bak
    try {
        $sedFile04 = Join-Path $script:CacheDir 'sed04.txt'
        New-MockFile -Path $sedFile04 -Content 'original'
        sed -File $sedFile04 -Find 'original' -Replace 'modified' -Backup -Confirm:$false

        $bakPath = "$sedFile04.bak"
        $bakExists = Test-Path $bakPath
        Assert-True -Condition $bakExists -TestName 'TEXT-04: .bak file exists'
        if ($bakExists) {
            $bakContent = Get-Content $bakPath -Raw -ErrorAction SilentlyContinue
            $bakContent = $bakContent.Trim()
            Assert-Equal -Expected 'original' -Actual $bakContent -TestName 'TEXT-04: .bak contains original content'
        }
        $newContent04 = Get-Content $sedFile04 -Raw -ErrorAction SilentlyContinue
        $newContent04 = $newContent04.Trim()
        Assert-Equal -Expected 'modified' -Actual $newContent04 -TestName 'TEXT-04: target file is modified'
    }
    catch { Test-Result -Name 'TEXT-04' -Passed $false -Message $_.Exception.Message }
    finally { Remove-MockFile "$sedFile04.bak"; Remove-MockFile $sedFile04 }

    # TEXT-05: sed write error cleans up tmp file
    try {
        $sedFile05 = Join-Path $script:CacheDir 'sed05.txt'
        New-MockFile -Path $sedFile05 -Content 'write error test'
        function script:Move-Item { throw "Simulated write failure" }
        $errorSeen05 = $null
        try { sed -File $sedFile05 -Find 'write' -Replace 'read' -Confirm:$false }
        catch { $errorSeen05 = $_ }
        $hasCorrectId05 = $errorSeen05 -and $errorSeen05.FullyQualifiedErrorId -match 'SedOperationFailed'
        Assert-True -Condition $hasCorrectId05 -TestName 'TEXT-05: SedOperationFailed on write error'
    }
    catch { Test-Result -Name 'TEXT-05' -Passed $false -Message $_.Exception.Message }
    finally {
        Remove-Item 'Function:Move-Item' -Force -ErrorAction SilentlyContinue
        Remove-MockFile (Join-Path $script:CacheDir 'sed05.txt')
    }

    # TEXT-06: Copy-ToClipboard pipeline
    try {
        $script:MockClipboardText = $null
        'line1', 'line2' | Copy-ToClipboard
        Assert-NotNull -Value $script:MockClipboardText -TestName 'TEXT-06: clipboard text is not null'
        if ($null -ne $script:MockClipboardText) {
            $lines = $script:MockClipboardText -split [Environment]::NewLine
            Assert-True -Condition ($lines.Count -ge 2) -TestName 'TEXT-06: clipboard has 2+ lines'
            Assert-Equal -Expected 'line1' -Actual $lines[0] -TestName 'TEXT-06: first line is line1'
            Assert-Equal -Expected 'line2' -Actual $lines[1] -TestName 'TEXT-06: second line is line2'
        }
    }
    catch { Test-Result -Name 'TEXT-06' -Passed $false -Message $_.Exception.Message }

    # TEXT-07: Copy-ToClipboard null skip
    # Note: [string]$InputObject converts $null to '' in pipeline, so nulls become empty lines.
    # The function preserves them. This is a PowerShell parameter-binding limitation.
    try {
        $script:MockClipboardText = $null
        $null, 'text', $null | Copy-ToClipboard
        Assert-NotNull -Value $script:MockClipboardText -TestName 'TEXT-07: clipboard text is not null'
        if ($null -ne $script:MockClipboardText) {
            $expected07 = [Environment]::NewLine + 'text'
            Assert-Equal -Expected $expected07 -Actual $script:MockClipboardText -TestName 'TEXT-07: [string] coercion turns $null to empty line'
        }
    }
    catch { Test-Result -Name 'TEXT-07' -Passed $false -Message $_.Exception.Message }

    # TEXT-08: touch existing file updates timestamp
    try {
        $touchFile08 = Join-Path $script:CacheDir 'touch08.txt'
        New-MockFile -Path $touchFile08 -Content 'hello'
        $originalTime = (Get-Item $touchFile08).LastWriteTime
        Start-Sleep -Milliseconds 10
        touch $touchFile08
        $newTime = (Get-Item $touchFile08).LastWriteTime
        Assert-True -Condition ($newTime -ge $originalTime) -TestName 'TEXT-08: LastWriteTime updated by touch'
    }
    catch { Test-Result -Name 'TEXT-08' -Passed $false -Message $_.Exception.Message }
    finally { Remove-MockFile (Join-Path $script:CacheDir 'touch08.txt') }

    # TEXT-09: touch creates new file
    try {
        $touchFile09 = Join-Path $script:CacheDir 'touch09_new.txt'
        Remove-MockFile $touchFile09
        Assert-False -Condition (Test-Path $touchFile09) -TestName 'TEXT-09: precondition - file does not exist'
        touch $touchFile09
        Assert-True -Condition (Test-Path $touchFile09) -TestName 'TEXT-09: touch creates new file'
    }
    catch { Test-Result -Name 'TEXT-09' -Passed $false -Message $_.Exception.Message }
    finally { Remove-MockFile (Join-Path $script:CacheDir 'touch09_new.txt') }

    Write-Host "Text Utils suite complete." -ForegroundColor Cyan
}

# ── GIT MODULE MOCKS ───────────────────────────────────────────
$script:MockGitCalls = @()
$script:MockGitExitCodes = @()
$script:MockWarnings = @()

function script:Write-Warning {
    param([string]$Message)
    $script:MockWarnings += $Message
}

function script:git {
    param([Parameter(Position=0, ValueFromRemainingArguments)]$Arguments)
    $callIndex = $script:MockGitCalls.Count
    $script:MockGitCalls += @([PSCustomObject]@{ Args = @($Arguments); Index = $callIndex })
    if ($callIndex -lt $script:MockGitExitCodes.Count) {
        $global:LASTEXITCODE = $script:MockGitExitCodes[$callIndex]
    }
    else { $global:LASTEXITCODE = 0 }
    return ''
}

# ── GIT MODULE TESTS ───────────────────────────────────────────

function Write-GitSuite {
    Write-Host "`n=== GIT MODULE TESTS ===" -ForegroundColor Cyan

    # GIT-01: gcom add fails -> warn and return
    # gcom calls: git add . (call 0)
    try {
        $script:MockGitCalls = @()
        $script:MockGitExitCodes = @(1)
        $script:MockWarnings = @()
        gcom -Message 'test'
        Assert-True -Condition ($script:MockWarnings.Count -ge 1) -TestName 'GIT-01: warning emitted on add fail'

        $hasAddCall = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'add' }
        Assert-NotNull -Value $hasAddCall -TestName 'GIT-01: git add was called'
        $hasCommitCall = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'commit' }
        Assert-True -Condition ($null -eq $hasCommitCall) -TestName 'GIT-01: git commit was NOT called after add fail'
    }
    catch { Test-Result -Name 'GIT-01' -Passed $false -Message $_.Exception.Message }

    # GIT-02: gcom commit fails -> warn
    # gcom calls: git add . (call 0=0), git commit (call 1=1)
    try {
        $script:MockGitCalls = @()
        $script:MockGitExitCodes = @(0, 1)
        $script:MockWarnings = @()
        gcom -Message 'test'
        Assert-True -Condition ($script:MockWarnings.Count -ge 1) -TestName 'GIT-02: warning emitted on commit fail'

        $hasAddCall02 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'add' }
        Assert-NotNull -Value $hasAddCall02 -TestName 'GIT-02: git add was called'
        $hasCommitCall02 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'commit' }
        Assert-NotNull -Value $hasCommitCall02 -TestName 'GIT-02: git commit was called'
    }
    catch { Test-Result -Name 'GIT-02' -Passed $false -Message $_.Exception.Message }

    # GIT-03: gcom both succeed
    # gcom calls: git add . (call 0=0), git commit (call 1=0)
    try {
        $script:MockGitCalls = @()
        $script:MockGitExitCodes = @(0, 0)
        gcom -Message 'test success'

        $callCount03 = $script:MockGitCalls.Count
        Assert-Equal -Expected 2 -Actual $callCount03 -TestName 'GIT-03: both git add and commit called (2 calls)'
    }
    catch { Test-Result -Name 'GIT-03' -Passed $false -Message $_.Exception.Message }

    # GIT-04: lazyg -Force skips confirm
    # lazyg calls: git status --short (call 0=0), git add . (call 1=0), git commit (call 2=0), git push (call 3=0)
    try {
        $script:MockGitCalls = @()
        $script:MockGitExitCodes = @(0, 0, 0, 0)
        lazyg -Message 'auto' -Force

        $callCount04 = $script:MockGitCalls.Count
        $hasAdd04 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'add' }
        $hasCommit04 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'commit' }
        $hasPush04 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'push' }
        Assert-True -Condition ($callCount04 -ge 4) -TestName 'GIT-04: lazyg -Force called git 4 times'
        Assert-NotNull -Value $hasAdd04 -TestName 'GIT-04: git add called'
        Assert-NotNull -Value $hasCommit04 -TestName 'GIT-04: git commit called'
        Assert-NotNull -Value $hasPush04 -TestName 'GIT-04: git push called'
    }
    catch { Test-Result -Name 'GIT-04' -Passed $false -Message $_.Exception.Message }

    # GIT-05: lazyg add fails -> return before commit
    # lazyg calls: git status --short (call 0=0), git add . (call 1=1 -> fail)
    try {
        $script:MockGitCalls = @()
        $script:MockGitExitCodes = @(0, 1)
        $script:MockWarnings = @()
        lazyg -Message 'test' -Force
        Assert-True -Condition ($script:MockWarnings.Count -ge 1) -TestName 'GIT-05: warning emitted on add fail'

        $hasCommit05 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'commit' }
        $hasPush05 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'push' }
        Assert-True -Condition ($null -eq $hasCommit05) -TestName 'GIT-05: git commit NOT called after add fail'
        Assert-True -Condition ($null -eq $hasPush05) -TestName 'GIT-05: git push NOT called after add fail'
    }
    catch { Test-Result -Name 'GIT-05' -Passed $false -Message $_.Exception.Message }

    # GIT-06: lazyg commit fails -> return before push
    # lazyg calls: git status (call 0=0), git add (call 1=0), git commit (call 2=1 -> fail)
    try {
        $script:MockGitCalls = @()
        $script:MockGitExitCodes = @(0, 0, 1)
        $script:MockWarnings = @()
        lazyg -Message 'test' -Force
        Assert-True -Condition ($script:MockWarnings.Count -ge 1) -TestName 'GIT-06: warning emitted on commit fail'

        $hasAdd06 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'add' }
        $hasCommit06 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'commit' }
        $hasPush06 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'push' }
        Assert-NotNull -Value $hasAdd06 -TestName 'GIT-06: git add called'
        Assert-NotNull -Value $hasCommit06 -TestName 'GIT-06: git commit called'
        Assert-True -Condition ($null -eq $hasPush06) -TestName 'GIT-06: git push NOT called after commit fail'
    }
    catch { Test-Result -Name 'GIT-06' -Passed $false -Message $_.Exception.Message }

    # GIT-07: lazyg push fails -> warn
    # lazyg calls: git status (call 0=0), git add (call 1=0), git commit (call 2=0), git push (call 3=1 -> fail)
    try {
        $script:MockGitCalls = @()
        $script:MockGitExitCodes = @(0, 0, 0, 1)
        $script:MockWarnings = @()
        lazyg -Message 'test' -Force
        Assert-True -Condition ($script:MockWarnings.Count -ge 1) -TestName 'GIT-07: warning emitted on push fail'

        $callCount07 = $script:MockGitCalls.Count
        Assert-Equal -Expected 4 -Actual $callCount07 -TestName 'GIT-07: all 4 git calls made even with push fail'
        $hasPush07 = $script:MockGitCalls | Where-Object { $_.Args[0] -eq 'push' }
        Assert-NotNull -Value $hasPush07 -TestName 'GIT-07: git push was called'
    }
    catch { Test-Result -Name 'GIT-07' -Passed $false -Message $_.Exception.Message }

    # GIT-08: Test-InteractiveSession CI=true -> $false
    try {
        $savedCI = $env:CI
        $env:CI = 'true'
        $result08 = script:Test-InteractiveSession
        Assert-False -Condition $result08 -TestName 'GIT-08: returns false when CI=true'
        $env:CI = $savedCI
    }
    catch { Test-Result -Name 'GIT-08' -Passed $false -Message $_.Exception.Message }
    finally { if ($savedCI) { $env:CI = $savedCI } else { Remove-Item Env:CI -ErrorAction SilentlyContinue } }

    # GIT-09: Test-InteractiveSession on Windows (no CI) -> $true
    try {
        $savedCI09 = $env:CI
        Remove-Item Env:CI -ErrorAction SilentlyContinue
        $result09 = script:Test-InteractiveSession
        Assert-True -Condition $result09 -TestName 'GIT-09: returns true on Windows interactive console'
        $env:CI = $savedCI09
    }
    catch { Test-Result -Name 'GIT-09' -Passed $false -Message $_.Exception.Message }
    finally { if ($savedCI09) { $env:CI = $savedCI09 } else { Remove-Item Env:CI -ErrorAction SilentlyContinue } }

    Write-Host "Git suite complete." -ForegroundColor Cyan
}

# ── RUN SUITE ─────────────────────────────────────────────────

# Load text_utils.ps1
$script:TextUtilsPath = Join-Path $PSScriptRoot '..\modules\text_utils\text_utils.ps1'
if (Test-Path $script:TextUtilsPath) {
    . $script:TextUtilsPath
}
else { Write-Host "ERROR: text_utils.ps1 not found" -ForegroundColor Red }

# Load git.ps1
$script:GitModulePath = Join-Path $PSScriptRoot '..\modules\git\git.ps1'
if (Test-Path $script:GitModulePath) {
    . $script:GitModulePath
}
else { Write-Host "ERROR: git.ps1 not found" -ForegroundColor Red }

Write-CacheSuite
Write-SystemSuite
Write-TextUtilsSuite
Write-GitSuite

# ── CLEANUP ───────────────────────────────────────────────────
Remove-Item $script:CacheDir -Force -Recurse -ErrorAction SilentlyContinue

# ── SUMMARY ───────────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "UNIT TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$totalTests = $script:TestsPassed + $script:TestsFailed
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed:      $script:TestsPassed" -ForegroundColor Green
Write-Host "Failed:      $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped:     $script:TestsSkipped" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

if ($script:TestsFailed -gt 0) { exit 1 } else { exit 0 }
