#Requires -Version 5.1
param([switch]$Verbose)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TestsPassed = 0
$script:TestsFailed = 0

function Assert-True {
    param([bool]$Condition, [string]$TestName)
    if ($Condition) { $script:TestsPassed++; Write-Host "  [+] $TestName" -ForegroundColor Green }
    else { $script:TestsFailed++; Write-Host "  [X] $TestName" -ForegroundColor Red }
}

Write-Host "`nPOSH_THEME Tests" -ForegroundColor Cyan
Write-Host "===============`n" -ForegroundColor Cyan

$script:IsWin = $true
$script:IsLnx = $false
$script:IsMac = $false

$configPath = Join-Path $PSScriptRoot '..\modules\config\config.ps1'
$testThemeDir = Join-Path $HOME '.poshthemes'
$testThemeFile = Join-Path $testThemeDir 'test_theme.omp.json'

$savedPoshTheme = $env:POSH_THEME

try {
    if (-not (Test-Path $testThemeDir)) { New-Item -ItemType Directory -Force $testThemeDir | Out-Null }
    Set-Content -Path $testThemeFile -Value '{}' -Encoding UTF8

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
    Remove-Item $testThemeFile -Force -ErrorAction SilentlyContinue
    $env:POSH_THEME = $savedPoshTheme
    . $configPath
}

Write-Host "`nResults: $($script:TestsPassed) passed, $($script:TestsFailed) failed" -ForegroundColor Cyan
if ($script:TestsFailed -gt 0) { exit 1 }
