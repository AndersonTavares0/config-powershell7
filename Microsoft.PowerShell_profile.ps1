#Requires -Version 5.1

# ============================================================
# POWERSHELL PROFILE  
# PS 5.1+ / PS Core 7+ | Revisão: 04/27/2026
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

# Movidos para $script: — escopo explícito, evita ambiguidade em funções
$script:PSMajor  = $PSVersionTable.PSVersion.Major
$script:IsAdmin  = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ── CARREGAMENTO DE MÓDULOS ─────────────────────────────────
# Resolve o caminho real caso o perfil tenha sido carregado via Link Simbólico
$realPath = $PSCommandPath
if (Get-Item $realPath -ErrorAction SilentlyContinue | Where-Object LinkType -eq 'SymbolicLink') {
    $realPath = (Get-Item $realPath).Target
}
$moduleDir = Join-Path (Split-Path $realPath) "modules"
. "$moduleDir/cache/cache.ps1"
. "$moduleDir/system/psreadline.ps1"
. "$moduleDir/navigation/navigation.ps1"
. "$moduleDir/text_utils/text_utils.ps1"
. "$moduleDir/system/system.ps1"
. "$moduleDir/git/git.ps1"

# ── 9. BOOT SUMMARY ───────────────────────────────────────────
# Wrapped em scriptblock: $_ms, $_color etc. não vazam para a sessão do usuário
& {
    $script:BootTimer.Stop()
    $Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$(
        if ($script:IsAdmin) { ' [ADMIN]' }
    )"

    $ms      = [math]::Round($script:BootTimer.Elapsed.TotalMilliseconds, 0)
    $color   = if ($ms -lt 200) { 'Green' } elseif ($ms -lt 400) { 'Yellow' } else { 'Red' }
    $plugins = if ($script:StartupModules.Count) { " · $($script:StartupModules -join ', ')" } else { '' }
    $admin   = if ($script:IsAdmin) { ' · ADMIN' } else { '' }

    Write-Host "PS $($PSVersionTable.PSVersion)$plugins$admin" -ForegroundColor Cyan -NoNewline
    Write-Host " [${ms}ms]" -ForegroundColor $color
}