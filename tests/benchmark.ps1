#Requires -Version 7.0
param([int]$Runs = 5)

$root = Split-Path $PSScriptRoot -Parent
Write-Host "Benchmark do PROFILE real ($Runs runs em processos limpos)" -ForegroundColor Cyan
Write-Host ("=" * 60)

$allRuns = [System.Collections.Generic.List[double]]::new()
$allDetails = $null

foreach ($run in 1..$Runs) {
    Write-Host "  Run $run/$Runs... " -NoNewline

    $scriptBlock = {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $env:__PROFILE_LOADED = '1'
        $script:ProfileRoot = $args[0]

        . (Join-Path $script:ProfileRoot 'modules/config/config.ps1')
        $c1 = $sw.Elapsed.TotalMilliseconds; $sw.Restart()

        $script:StartupModules = [Collections.Generic.List[string]]::new()
        . (Join-Path $script:ProfileRoot 'modules/cache/cache.ps1')
        $c2 = $sw.Elapsed.TotalMilliseconds; $sw.Restart()

        . (Join-Path $script:ProfileRoot 'modules/navigation/navigation.ps1')
        $c3 = $sw.Elapsed.TotalMilliseconds; $sw.Restart()

        . (Join-Path $script:ProfileRoot 'modules/git/git.ps1')
        $c4 = $sw.Elapsed.TotalMilliseconds; $sw.Restart()

        . (Join-Path $script:ProfileRoot 'modules/system/system.ps1')
        $c5 = $sw.Elapsed.TotalMilliseconds; $sw.Restart()

        . (Join-Path $script:ProfileRoot 'modules/psreadline/psreadline.ps1')
        $c6 = $sw.Elapsed.TotalMilliseconds; $sw.Restart()

        . (Join-Path $script:ProfileRoot 'modules/text_utils/text_utils.ps1')
        $c7 = $sw.Elapsed.TotalMilliseconds

        $total = $c1+$c2+$c3+$c4+$c5+$c6+$c7
        "$([Math]::Round($c1,1)),$([Math]::Round($c2,1)),$([Math]::Round($c3,1)),$([Math]::Round($c4,1)),$([Math]::Round($c5,1)),$([Math]::Round($c6,1)),$([Math]::Round($c7,1)),$([Math]::Round($total,1))"
    }

    $raw = pwsh -NoProfile -Command $scriptBlock -args $root 2>&1
    $line = ($raw | Out-String).Trim().Split("`n") | Where-Object { $_ -match '^[\d.,]+$' } | Select-Object -Last 1

    if (-not $line) {
        Write-Host "ERRO: sem saida numerica" -ForegroundColor Red
        Write-Host $raw -ForegroundColor DarkGray
        continue
    }

    $parts = $line -split ','
    $total = [double]$parts[7]
    $allRuns.Add($total)

    $color = if ($total -lt 300) { 'Green' } elseif ($total -lt 600) { 'Yellow' } else { 'Red' }
    Write-Host "$($total)ms" -ForegroundColor $color

    if ($run -eq 1) {
        $allDetails = [PSCustomObject]@{
            Config     = [double]$parts[0]
            Cache      = [double]$parts[1]
            Navigation = [double]$parts[2]
            Git        = [double]$parts[3]
            System     = [double]$parts[4]
            PSReadLine = [double]$parts[5]
            TextUtils  = [double]$parts[6]
            Total      = $total
        }
    }
}

if ($allRuns.Count -gt 0) {
    $avg = [math]::Round(($allRuns | Measure-Object -Average).Average, 1)
    $min = [math]::Round(($allRuns | Measure-Object -Minimum).Minimum, 1)
    $max = [math]::Round(($allRuns | Measure-Object -Maximum).Maximum, 1)
    $ca = if ($avg -lt 300) { 'Green' } elseif ($avg -lt 600) { 'Yellow' } else { 'Red' }

    Write-Host "`nDetalhamento (Run 1):" -ForegroundColor Cyan
    $allDetails.PSObject.Properties | ForEach-Object {
        $c = if ($_.Value -lt 20) { 'Green' } elseif ($_.Value -lt 100) { 'Yellow' } else { 'Red' }
        Write-Host ("  {0,-15} {1,8} ms" -f $_.Name, [math]::Round($_.Value, 1)) -ForegroundColor $c
    }
    Write-Host ("`n  Media: {0}ms  Min: {1}ms  Max: {2}ms" -f $avg, $min, $max) -ForegroundColor $ca
}
