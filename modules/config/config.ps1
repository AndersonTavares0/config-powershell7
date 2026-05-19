Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 0. CONFIGURAÇÃO CENTRALIZADA ─────────────────────────────
# Ponto único de verdade para caminhos, constantes e detecção de plataforma.
# Todos os módulos consomem $script:Config — nenhum módulo repete essa lógica.

# Detecção cross-platform inline — lib/platform.ps1 é para scripts standalone,
# módulos do profile devem ser autossuficientes (sem dependência de diretório lib/).
# Profile já define $script:IsWin antes de carregar config.ps1; fallback para standalone.
if (-not (Get-Variable -Name 'IsWin' -Scope Script -ErrorAction SilentlyContinue)) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $script:IsWin = $IsWindows
        $script:IsLnx = $IsLinux
        $script:IsMac = $IsMacOS
    } else {
        $script:IsWin = $true
        $script:IsLnx = $false
        $script:IsMac = $false
    }
}

if ($script:IsWin) {
    $script:IsAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} else {
    $script:IsAdmin = ((id -u 2>$null) -eq '0')
}

$psMajor = $PSVersionTable.PSVersion.Major
$isLinuxOrMac = $script:IsLnx -or $script:IsMac

# Caminhos resolvidos inline (sem função = sem overhead de parsing + parameter binding)
# Windows: $HOME\.cache_pwsh_plugins.ps1 | Linux (XDG): $XDG_CACHE_HOME/pwsh/
$cachePath = if ($isLinuxOrMac) {
    $xdgCache = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' }
    $cacheDir = Join-Path $xdgCache 'pwsh'
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Force -Path $cacheDir -ErrorAction SilentlyContinue | Out-Null
    }
    Join-Path $cacheDir 'plugins_cache.ps1'
} else {
    Join-Path $HOME '.cache_pwsh_plugins.ps1'
}

$themePath = if ($isLinuxOrMac) {
    $xdgData = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path $HOME '.local/share' }
    $t = Join-Path $xdgData 'poshthemes/atomic.omp.json'
    if (Test-Path $t) { $t }
    else { $f = Join-Path $HOME '.poshthemes/atomic.omp.json'; if (Test-Path $f) { $f } else { $f } }
} else {
    Join-Path $HOME '.poshthemes\atomic.omp.json'
}

$script:Config = [PSCustomObject]@{
    IsWindows   = $script:IsWin
    IsLinux     = $script:IsLnx
    IsMacOS     = $script:IsMac
    IsAdmin     = $script:IsAdmin
    PSMajor     = $psMajor
    CachePath   = $cachePath
    ThemePath   = $themePath
    CacheTTLMinutes = 1440
}
