# ── 0. CONFIGURAÇÃO CENTRALIZADA ─────────────────────────────
# Ponto único de verdade para caminhos, constantes e detecção de plataforma.
# Todos os módulos consomem $script:Config — nenhum módulo repete essa lógica.

# Dot-source shared platform detection (lib/platform.ps1)
# $script:IsWin, $script:IsLnx, $script:IsMac, $script:IsAdmin
. (Join-Path $PSScriptRoot '../../lib/platform.ps1')

$psMajor = $PSVersionTable.PSVersion.Major
$isLinuxOrMac = $script:IsLnx -or $script:IsMac

# Resolução de caminhos com fallbacks multiplataforma
# Windows: $HOME\.cache_pwsh_plugins.ps1
# Linux (XDG): $XDG_CACHE_HOME/pwsh/ ou $HOME/.cache/pwsh/
function script:Resolve-CachePath {
    param([bool]$IsLinuxOrMac)
    if ($IsLinuxOrMac) {
        $xdgCache = $env:XDG_CACHE_HOME
        if (-not $xdgCache) { $xdgCache = Join-Path $HOME '.cache' }
        $cacheDir = Join-Path $xdgCache 'pwsh'
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Force -Path $cacheDir -ErrorAction SilentlyContinue | Out-Null
        }
        return (Join-Path $cacheDir 'plugins_cache.ps1')
    }
    return (Join-Path $HOME '.cache_pwsh_plugins.ps1')
}

function script:Resolve-ThemePath {
    param([bool]$IsLinuxOrMac)
    if ($IsLinuxOrMac) {
        $xdgData = $env:XDG_DATA_HOME
        if (-not $xdgData) { $xdgData = Join-Path $HOME '.local/share' }
        $themePath = Join-Path $xdgData 'poshthemes/atomic.omp.json'
        if (Test-Path $themePath) { return $themePath }
        # Fallback para caminho convencional
        $fallback = Join-Path $HOME '.poshthemes/atomic.omp.json'
        if (Test-Path $fallback) { return $fallback }
        return $fallback
    }
    return (Join-Path $HOME '.poshthemes\atomic.omp.json')
}

$script:Config = [PSCustomObject]@{
    # Plataforma
    IsWindows   = $script:IsWin
    IsLinux     = $script:IsLnx
    IsMacOS     = $script:IsMac
    IsAdmin     = $script:IsAdmin
    PSMajor     = $psMajor

    # Caminhos (resolvidos dinamicamente)
    CachePath   = (script:Resolve-CachePath -IsLinuxOrMac $isLinuxOrMac)
    ThemePath   = (script:Resolve-ThemePath -IsLinuxOrMac $isLinuxOrMac)

    # Cache TTL em minutos (pular recálculo de fingerprint se cache é recente)
    CacheTTLMinutes = 60
}
