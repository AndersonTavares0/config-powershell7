# ── PLATFORM DETECTION (SHARED) ──────────────────────────────
# Ponto único de detecção de plataforma e privilégios.
# Dot-source este arquivo em qualquer script standalone (install, uninstall, tests).
# Módulos do profile devem usar $script:Config em vez deste arquivo.
#
# NOTA: Nomes $script:IsWin / IsLnx / IsMac evitam colisão com as variáveis
# automáticas read-only do PS 6+ ($IsWindows, $IsLinux, $IsMacOS).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $script:IsWin = $IsWindows
    $script:IsLnx = $IsLinux
    $script:IsMac = $IsMacOS
} else {
    # PS 5.1 só roda no Windows
    $script:IsWin = $true
    $script:IsLnx = $false
    $script:IsMac = $false
}

if ($script:IsWin) {
    $script:IsAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} else {
    $script:IsAdmin = ((id -u 2>$null) -eq '0')
}


