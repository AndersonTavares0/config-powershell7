#Requires -Version 5.1

# ============================================================
# POWERSHELL PROFILE
# PS 5.1+ / PS Core 7+ | Revisão: 05/2026
# ============================================================

# Previne execução duplicada se o usuário tiver o perfil
# vinculado em múltiplos locais (AllHosts + CurrentHost)
if ((Get-Variable -Name 'ProfileLoaded' -Scope Global -ErrorAction SilentlyContinue).Value) { return }
$global:ProfileLoaded = $true

# ── STOPWATCH ────────────────────────────────────────────────
$script:BootTimer = [System.Diagnostics.Stopwatch]::StartNew()

# ── ROOT DO REPOSITÓRIO ──────────────────────────────────────
# Quando dot-sourced via $PROFILE, $PSScriptRoot resolve para o
# diretório do PROFILE e não do repositório. O instalador define
# $global:__ProfileRepoRoot com o caminho correto antes do dot-source.
$script:ProfileRoot = $global:__ProfileRepoRoot ?? $PSScriptRoot

# ── LISTA DE MÓDULOS CARREGADOS (consumida pelo cache) ───────
$script:StartupModules = [System.Collections.Generic.List[string]]::new()

# ── CARREGAMENTO MODULAR ─────────────────────────────────────
# Ordem importa: config primeiro (dependência de todos),
# cache segundo (inicializa plugins), depois o resto.
# Cada módulo é isolado em try/catch para que uma falha
# em módulo não-crítico não interrompa o carregamento.

# 0. CONFIG — Dependência crítica (sem ela nada funciona)
$configPath = Join-Path $script:ProfileRoot 'modules/config/config.ps1'
if (Test-Path $configPath) {
    . $configPath
} else {
    Write-Warning "Config module not found: $configPath"
    return
}

# Módulos não-críticos: falha em um não impede os demais
$nonCriticalModules = @(
    'cache/cache.ps1'
    'navigation/navigation.ps1'
    'git/git.ps1'
    'system/system.ps1'
    'system/psreadline.ps1'
    'text_utils/text_utils.ps1'
)

foreach ($module in $nonCriticalModules) {
    $modulePath = Join-Path $script:ProfileRoot "modules/$module"
    if (Test-Path $modulePath) {
        try {
            . $modulePath
        } catch {
            Write-Verbose "Failed to load module: $module - $($_.Exception.Message)"
        }
    }
}

# (Terminal-Icons é importado sob demanda via alias 'icons' no cache.ps1 para não atrasar o boot)

# ── BOOT SUMMARY ─────────────────────────────────────────────
$script:BootTimer.Stop()
$bootMs = $script:BootTimer.ElapsedMilliseconds

$adminTag = if ($script:Config.IsAdmin) { ' [ADMIN]' } else { '' }
$moduleList = if ($script:StartupModules.Count -gt 0) {
    ' · ' + ($script:StartupModules -join ', ')
} else { '' }

$color = if ($bootMs -lt 300) { 'Green' } elseif ($bootMs -lt 600) { 'Yellow' } else { 'Red' }

Write-Host "⚡ PS $($PSVersionTable.PSVersion)${moduleList}${adminTag}" -ForegroundColor Cyan -NoNewline
Write-Host " [${bootMs}ms]" -ForegroundColor $color
