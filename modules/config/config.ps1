# ── 0. CONFIGURAÇÃO CENTRALIZADA ─────────────────────────────
# Ponto único de verdade para caminhos, constantes e detecção de plataforma.
# Todos os módulos consomem $script:Config — nenhum módulo repete essa lógica.
# Variáveis intermediárias usam escopo local para não poluir $script:.

# Detecção cross-platform de sistema operacional
# PowerShell 6+ fornece variáveis automáticas SOMENTE LEITURA: $IsWindows, $IsLinux, $IsMacOS
# Fallback para PS 5.1 que não possui essas variáveis
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $platformIsWindows = $IsWindows
    $platformIsLinux   = $IsLinux
    $platformIsMacOS   = $IsMacOS
} else {
    # PS 5.1 só roda no Windows
    $platformIsWindows = $true
    $platformIsLinux   = $false
    $platformIsMacOS   = $false
}

# Detecção de privilégios administrativos (cross-platform)
if ($platformIsWindows) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} else {
    # Linux/macOS: checa se uid é 0 (root)
    $isAdmin = (id -u 2>$null) -eq '0'
}

$psMajor = $PSVersionTable.PSVersion.Major

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

$isLinuxOrMac = $platformIsLinux -or $platformIsMacOS

$script:Config = [PSCustomObject]@{
    # Plataforma
    IsWindows   = $platformIsWindows
    IsLinux     = $platformIsLinux
    IsMacOS     = $platformIsMacOS
    IsAdmin     = $isAdmin
    PSMajor     = $psMajor

    # Caminhos (resolvidos dinamicamente)
    CachePath   = (script:Resolve-CachePath -IsLinuxOrMac $isLinuxOrMac)
    ThemePath   = (script:Resolve-ThemePath -IsLinuxOrMac $isLinuxOrMac)

    # Cache TTL em minutos (pular recálculo de fingerprint se cache é recente)
    CacheTTLMinutes = 30

    # Constantes
    MaxFileSizeMB   = 50
}

