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

function Get-PwshExecutablePath {
    param([AllowEmptyCollection()][string[]]$CandidatePaths = @())

    if (-not $CandidatePaths -or $CandidatePaths.Count -eq 0) {
        $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
        $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        $pathEntries = @($env:PATH -split ';') + @($machinePath -split ';') + @($userPath -split ';')
        $seenPaths = @{}
        $env:PATH = @(
            foreach ($entry in $pathEntries) {
                $normalized = $entry.Trim()
                if ($normalized -and -not $seenPaths.ContainsKey($normalized)) {
                    $seenPaths[$normalized] = $true
                    $normalized
                }
            }
        ) -join ';'

        $CandidatePaths = @()
        $command = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($command -and $command.Source) { $CandidatePaths += $command.Source }
        if ($env:ProgramFiles) { $CandidatePaths += Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe' }
        if ($env:LOCALAPPDATA) {
            $CandidatePaths += Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\pwsh.exe'
            $CandidatePaths += Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe'
            $CandidatePaths += Join-Path $env:LOCALAPPDATA 'scoop\shims\pwsh.exe'
        }
    }

    foreach ($candidate in ($CandidatePaths | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }
    return $null
}
