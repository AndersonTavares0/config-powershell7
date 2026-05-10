Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 2. PLUGINS & CACHE v2 ────────────────────────────────────
# Cache com TTL (Time-To-Live): evita recálculo de fingerprint SHA256
# se o arquivo de cache foi atualizado recentemente.
#
# Formato do header do cache:
#   # fp:<hash> ts:<unix_epoch>
#
# Hot path (cache válido + TTL ok): ~5ms — sem Get-Command, sem Get-FileHash.

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

# SHA256 encapsulado em try/finally: garante Dispose() mesmo em falha.
# fingerprint inclui versão dos binários via VersionInfo, não apenas caminho
# Inclui hash do conteúdo do tema para detecção profunda de mudanças
function script:Get-PluginFingerprint {
    param([object]$zcmd, [object]$ocmd)

    if (-not $zcmd)  { $zcmd  = Get-Command zoxide -ErrorAction SilentlyContinue }
    if (-not $ocmd)  { $ocmd  = Get-Command oh-my-posh -ErrorAction SilentlyContinue }
    $parts = @()

    if ($zcmd) {
        $parts += $zcmd.Source
        try {
            $zVersion = (Get-Item $zcmd.Source -ErrorAction SilentlyContinue).VersionInfo.FileVersion
            $parts += if ($zVersion) { $zVersion } else { 'unknown' }
        } catch {
            $parts += 'unknown'
        }
    }

    if ($ocmd) {
        $parts += $ocmd.Source
        try {
            $oVersion = (Get-Item $ocmd.Source -ErrorAction SilentlyContinue).VersionInfo.FileVersion
            $parts += if ($oVersion) { $oVersion } else { 'unknown' }
        } catch {
            $parts += 'unknown'
        }
    }

    $parts += $script:Config.ThemePath
    $parts += [int](Test-Path $script:Config.ThemePath)

    # Include theme content hash if exists for deeper change detection
    if (Test-Path $script:Config.ThemePath) {
        try {
            $themeHash = (Get-FileHash $script:Config.ThemePath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
            $parts += if ($themeHash) { $themeHash } else { 'nohash' }
        } catch {
            $parts += 'nohash'
        }
    }

    $bytes    = [System.Text.Encoding]::UTF8.GetBytes($parts -join '|')
    $sha256   = [System.Security.Cryptography.SHA256]::Create()
    try       { [System.BitConverter]::ToString($sha256.ComputeHash($bytes)) -replace '-', '' }
    finally   { $sha256.Dispose() }
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
            $label       = if ($themeExists) { 'OMP:atomic' } else { 'OMP:default' }
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
# 1. Se cache existe e TTL não expirou → dot-source direto (HOT PATH: ~5ms)
# 2. Se cache existe mas TTL expirou  → recalcular fingerprint, rebuild se diferente
# 3. Se cache não existe              → rebuild completo

function script:Initialize-PluginCache {
    $cachedFP = $null

    # HOT PATH: cache válido com TTL ok — sem Get-Command, sem fingerprint
    if (Test-Path $script:Config.CachePath) {
        $firstLine = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        if ($firstLine -match '^# fp:(\S+)\s+ts:(\d+)$') {
            $cachedTS = [long]$Matches[2]
            $nowTS    = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $ageMin   = ($nowTS - $cachedTS) / 60

            if ($ageMin -lt $script:Config.CacheTTLMinutes) {
                # TTL válido: early return — dispensa Get-Command, Get-FileHash e zoxide/omp init
                . $script:Config.CachePath
                return
            }
            # TTL expirado: armazena fingerprint para comparação no cold path
            $cachedFP = $Matches[1]
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
