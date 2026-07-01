# ── EXECUTABLE DETECTION (SHARED) ─────────────────────────────
# Ponto único de detecção de executáveis com captura de versão.
# Dot-source este arquivo em scripts standalone (install, uninstall, tests).
# Módulos do profile devem usar $script:Config em vez deste arquivo.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Executable {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$VersionArg = '--version'
    )

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }

    $result = [PSCustomObject]@{
        Name    = $Name
        Path    = $cmd.Source
        Found   = $true
        Version = $null
    }

    if ($VersionArg) {
        try {
            $v = & $Name $VersionArg 2>$null
            if ($v) {
                $result.Version = ($v | Select-Object -First 1).Trim()
            }
        } catch {
            # --version failed silently
        }
    }

    $result
}
