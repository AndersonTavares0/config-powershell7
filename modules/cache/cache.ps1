Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 2. PLUGINS & CACHE v2 ────────────────────────────────────
# Cache com TTL (Time-To-Live): evita recálculo de fingerprint
# se o arquivo de cache foi atualizado recentemente.
#
# Fingerprint usa LastWriteTime + tamanho do arquivo (mais rápido
# que SHA256) para detectar mudanças no tema e binários.
#
# Formato do header do cache:
#   # fp:<hash> ts:<unix_epoch>
#
# Hot path (cache válido + TTL ok): ~5ms para validar cache,
# ~120ms para dot-source (executa init do oh-my-posh).
# Cold path (TTL expirado): ~210ms + dot-source.

# Nomes em inglês + alias, convenção unificada
function Clear-PluginCache {
    if (Test-Path $script:Config.CachePath) {
        Remove-Item $script:Config.CachePath -ErrorAction SilentlyContinue
    }
}
Set-Alias Clear-Cache Clear-PluginCache

function Import-TerminalIcons {
    if (Get-Module Terminal-Icons) {
        return
    }
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}
Set-Alias icons Import-TerminalIcons

# Retorna fingerprint apenas do tema: path + exists flag +
# (opcional) Length:LastWriteTimeTicks. Usada no hot path para
# validar que o tema não mudou dentro da janela TTL.
function script:Get-ThemeFingerprint {
    $result = @()
    $result += $script:Config.ThemePath
    $result += [int](Test-Path $script:Config.ThemePath)
    if (Test-Path $script:Config.ThemePath) {
        try {
            $info = Get-Item $script:Config.ThemePath -ErrorAction SilentlyContinue
            if ($info) {
                $result += "$($info.Length):$($info.LastWriteTimeUtc.Ticks)"
            }
        } catch {
            $result += 'nofile'
        }
    }
    $result
}

# Fingerprint inclui caminho + versão dos binários e LastWriteTime + tamanho
# do arquivo de tema para detectar mudanças sem SHA256 (muito mais rápido).
function script:Get-PluginFingerprint {
    param([object]$zcmd, [object]$ocmd)

    if (-not $zcmd)  { $zcmd  = Get-Command zoxide -ErrorAction SilentlyContinue }
    if (-not $ocmd)  { $ocmd  = Get-Command oh-my-posh -ErrorAction SilentlyContinue }
    $parts = @()

    if ($zcmd) {
        $parts += $zcmd.Source
        try {
            $zItem = Get-Item $zcmd.Source -ErrorAction SilentlyContinue
            $zVersion = if ($zItem) { $zItem.VersionInfo.FileVersion } else { $null }
            $parts += if ($zVersion) { $zVersion } else { 'unknown' }
            # Inclui LastWriteTime do binário para detectar atualizações
            $parts += if ($zItem) { $zItem.LastWriteTimeUtc.Ticks.ToString() } else { '0' }
        } catch {
            $parts += 'unknown'; $parts += '0'
        }
    }

    if ($ocmd) {
        $parts += $ocmd.Source
        try {
            $oItem = Get-Item $ocmd.Source -ErrorAction SilentlyContinue
            $oVersion = if ($oItem) { $oItem.VersionInfo.FileVersion } else { $null }
            $parts += if ($oVersion) { $oVersion } else { 'unknown' }
            $parts += if ($oItem) { $oItem.LastWriteTimeUtc.Ticks.ToString() } else { '0' }
        } catch {
            $parts += 'unknown'; $parts += '0'
        }
    }

    $parts += script:Get-ThemeFingerprint
    $parts -join '|'
}

# Lógica de rebuild extraída: testável, nomeada, sem bloco `& {}` anônimo
function script:Update-PluginCache {
    param([object]$zcmd, [object]$ocmd)

    if (-not $zcmd)  { $zcmd  = Get-Command zoxide -ErrorAction SilentlyContinue }
    if (-not $ocmd)  { $ocmd  = Get-Command oh-my-posh -ErrorAction SilentlyContinue }

    $buf = [System.Text.StringBuilder]::new()
    $ts  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $fp  = script:Get-PluginFingerprint -zcmd $zcmd -ocmd $ocmd
    [void]$buf.AppendLine("# fp:${fp} ts:${ts}")

    if ($zcmd) {
        try {
            [void]$buf.AppendLine((zoxide init powershell 2>&1 | Out-String))
            [void]$buf.AppendLine("`$script:StartupModules.Add('Zoxide')")
        } catch {
            Write-Warning "Update-PluginCache: zoxide init falhou — Zoxide não inicializado. $_"
        }
    }

    if ($ocmd) {
        try {
            $themeExists = Test-Path $script:Config.ThemePath
            $label       = if ($themeExists) { "OMP:$($script:Config.ThemeName)" } else { 'OMP:default' }
            $initCmd     = if ($themeExists) {
                oh-my-posh init pwsh --config $script:Config.ThemePath 2>&1
            } else {
                oh-my-posh init pwsh 2>&1
            }
            [void]$buf.AppendLine(($initCmd | Out-String))
            [void]$buf.AppendLine("`$script:StartupModules.Add('$label')")
        } catch {
            Write-Warning "Update-PluginCache: oh-my-posh init falhou — Oh My Posh não inicializado. $_"
        }
    }

    try   { Set-Content -Path $script:Config.CachePath -Value $buf.ToString() -Encoding UTF8 -ErrorAction Stop }
    catch { Write-Warning "Update-PluginCache: falha ao salvar cache — cache será regenerado na próxima sessão. $_" }
}

# ── LÓGICA DE INICIALIZAÇÃO COM TTL ──────────────────────────
# Encapsulada em função para evitar poluição do scope $script:
# 1. Se cache existe, TTL válido e tema inalterado → dot-source direto (HOT PATH: ~5ms)
# 2. Se cache existe mas TTL expirou              → recalcular fingerprint, rebuild se diferente
# 3. Se cache existe, TTL válido mas tema mudou   → rebuild imediato (invalidação forçada)
# 4. Se cache não existe                          → rebuild completo

function script:Initialize-PluginCache {
    $cachedFP = $null

    # HOT PATH: cache válido com TTL ok — valida só fingerprint do tema (~0ms)
    if (Test-Path $script:Config.CachePath) {
        $firstLine = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        if ($firstLine -match '^# fp:(\S+)\s+ts:(\d+)$') {
            $cachedTS = [long]$Matches[2]
            $cachedFP = $Matches[1]
            $nowTS    = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $ageMin   = ($nowTS - $cachedTS) / 60

            if ($ageMin -lt $script:Config.CacheTTLMinutes) {
                # TTL válido — valida fingerprint do tema antes do early return
                $themeEnding = (script:Get-ThemeFingerprint) -join '|'
                if ($cachedFP.EndsWith($themeEnding)) {
                    . $script:Config.CachePath
                    return
                }
                # Theme changed — cai no cold path (cachedFP preservado)
            }
            # TTL expirado ou tema alterado — cachedFP já setado
        }
    }

    # COLD PATH: cache ausente, expirado ou com header inválido — discovery completo
    $zcmd = Get-Command zoxide -ErrorAction SilentlyContinue
    $ocmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue

    $needRebuild = $true

    if ($cachedFP) {
        $currentFP = script:Get-PluginFingerprint -zcmd $zcmd -ocmd $ocmd
        if ($cachedFP -eq $currentFP) {
            # Fingerprint idêntico — apenas atualizar o timestamp (touch)
            $content = Get-Content $script:Config.CachePath -Raw -ErrorAction SilentlyContinue
            $newTs   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $content = $content -replace '^# fp:(\S+)\s+ts:\d+', "# fp:`$1 ts:${newTs}"
            Set-Content -Path $script:Config.CachePath -Value $content -Encoding UTF8 -ErrorAction SilentlyContinue
            $needRebuild = $false
        }
    }

    if ($needRebuild) { script:Update-PluginCache -zcmd $zcmd -ocmd $ocmd }
    if (Test-Path $script:Config.CachePath) { . $script:Config.CachePath }
}

script:Initialize-PluginCache
