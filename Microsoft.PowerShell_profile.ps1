#Requires -Version 5.1

# ============================================================
# POWERSHELL PROFILE
# PS 5.1+ / PS Core 7+ | Revisão: 05/2026
# ============================================================
#
# PRÉ-REQUISITOS E INSTALAÇÃO:
# ----------------------------
# 1. Módodos recomendados (instalar com):
#    Install-Module -Name Terminal-Icons -Scope CurrentUser
#    Install-Module -Name PSReadLine -Scope CurrentUser -Force
#
# 2. Ferramentas externas (opcionais, mas recomendadas):
#    - oh-my-posh: https://ohmyposh.dev/docs/installation
#      winget install JanDeDobbeleer.OhMyPosh
#    - zoxide: https://github.com/ajeetdsouza/zoxide
#      winget install ajeetdsouza.zoxide
#
# 3. Temas oh-my-posh:
#    O tema padrão esperado está em: $HOME\.poshthemes\atomic.omp.json
#    Para instalar temas: oh-my-posh init pwsh --print-configs
#
# 4. Git (opcional):
#    As funções Git só serão carregadas se o comando 'git' estiver disponível
#
# 5. Cache de plugins:
#    O perfil cria automaticamente um cache em: $HOME\.cache_pwsh_plugins.ps1
#    Para limpar o cache: Clear-Cache ou Clear-PluginCache
#
# ============================================================

# ── 1. INICIALIZAÇÃO ─────────────────────────────────────────
$script:BootTimer      = [System.Diagnostics.Stopwatch]::StartNew()
$script:StartupModules = [System.Collections.Generic.List[string]]::new()
$script:CachedPublicIP = $null

# Variáveis de escopo explícito para evitar ambiguidade e vazamento
$script:PSMajor  = $PSVersionTable.PSVersion.Major
$script:IsAdmin  = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Detecção cross-platform de sistema operacional
# PowerShell 6+ fornece variáveis automáticas SOMENTE LEITURA: $IsWindows, $IsLinux, $IsMacOS
# Fallback para PS 5.1 que não possui essas variáveis
if ($PSVersionTable.PSVersion.Major -ge 6) {
    # Usa diretamente as variáveis automáticas (read-only)
    # Copiamos para variáveis com nomes diferentes para evitar erro de read-only
    $script:PlatformIsWindows = $IsWindows
    $script:PlatformIsLinux   = $IsLinux
    $script:PlatformIsMacOS   = $IsMacOS
} else {
    # PS 5.1 só roda no Windows, mas definimos por segurança
    $script:PlatformIsWindows = $true
    $script:PlatformIsLinux   = $false
    $script:PlatformIsMacOS   = $false
}

# ── CARREGAMENTO DE MÓDULOS ─────────────────────────────────
# Resolve o caminho real caso o perfil tenha sido carregado via Link Simbólico
try {
    $realPath = $PSCommandPath
    if (Test-Path $realPath -ErrorAction SilentlyContinue) {
        $item = Get-Item $realPath -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType -eq 'SymbolicLink') {
            $realPath = $item.Target
        }
    }
    $moduleDir = Join-Path (Split-Path $realPath -ErrorAction SilentlyContinue) "modules"

    # Carregamento modular com try/catch para evitar crash do terminal
    . "$moduleDir/cache/cache.ps1"
    . "$moduleDir/system/psreadline.ps1"
    . "$moduleDir/navigation/navigation.ps1"
    . "$moduleDir/text_utils/text_utils.ps1"
    . "$moduleDir/system/system.ps1"
    . "$moduleDir/git/git.ps1"
} catch {
    Write-Verbose "Profile: erro ao carregar módulos - $_"
}

# ── 9. BOOT SUMMARY ───────────────────────────────────────────
# Wrapped em scriptblock: variáveis locais não vazam para a sessão do usuário
& {
    try {
        $script:BootTimer.Stop()
        $Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$(
            if ($script:IsAdmin) { ' [ADMIN]' }
        )"

        $ms      = [math]::Round($script:BootTimer.Elapsed.TotalMilliseconds, 0)
        $color   = if ($ms -lt 200) { 'Green' } elseif ($ms -lt 400) { 'Yellow' } else { 'Red' }
        $plugins = if ($script:StartupModules.Count) { " · $($script:StartupModules -join ', ')" } else { '' }
        $admin   = if ($script:IsAdmin) { ' · ADMIN' } else { '' }

        # Write-Host mantido apenas no boot summary (informação útil ao usuário)
        Write-Host "PS $($PSVersionTable.PSVersion)$plugins$admin" -ForegroundColor Cyan -NoNewline
        Write-Host " [${ms}ms]" -ForegroundColor $color
    } catch {
        Write-Verbose "Boot summary: falha ao exibir - $_"
    }
}