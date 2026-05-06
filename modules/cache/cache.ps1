# ── 2. PLUGINS & CACHE v2 ────────────────────────────────────
# Cache com TTL (Time-To-Live): evita recálculo de fingerprint MD5
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

# Verifica se já carregado antes de chamar Import-Module
function Import-TerminalIcons {
    if (Get-Module Terminal-Icons) {
        return
    }
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}
Set-Alias icons Import-TerminalIcons

# MD5 encapsulado em try/finally: garante Dispose() mesmo em falha.
# fingerprint inclui versão dos binários via VersionInfo, não apenas caminho
# Inclui hash do conteúdo do tema para detecção profunda de mudanças
function script:Get-PluginFingerprint {
    $zcmd = Get-Command zoxide -ErrorAction SilentlyContinue
    $ocmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
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
            $themeHash = (Get-FileHash $script:Config.ThemePath -Algorithm MD5 -ErrorAction SilentlyContinue).Hash
            $parts += if ($themeHash) { $themeHash } else { 'nohash' }
        } catch {
            $parts += 'nohash'
        }
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($parts -join '|')
    $md5   = [System.Security.Cryptography.MD5]::Create()
    try    { [System.BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '' }
    finally{ $md5.Dispose() }
}

# Lógica de rebuild extraída: testável, nomeada, sem bloco `& {}` anônimo
function script:Update-PluginCache {
    $buf = [System.Text.StringBuilder]::new()
    $ts  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $fp  = script:Get-PluginFingerprint
    [void]$buf.AppendLine("# fp:${fp} ts:${ts}")

    $zcmd = Get-Command zoxide -ErrorAction SilentlyContinue
    if ($zcmd) {
        try {
            [void]$buf.AppendLine((zoxide init powershell 2>&1 | Out-String))
            [void]$buf.AppendLine("`$script:StartupModules.Add('Zoxide')")
        } catch {
            Write-Verbose "Update-PluginCache: zoxide init falhou - $_"
        }
    }

    $ocmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
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
            Write-Verbose "Update-PluginCache: oh-my-posh init falhou - $_"
        }
    }

    try   { Set-Content -Path $script:Config.CachePath -Value $buf.ToString() -Encoding UTF8 -ErrorAction Stop }
    catch { Write-Verbose "Update-PluginCache: Falha ao salvar cache - $_" }
}

# ── LÓGICA DE INICIALIZAÇÃO COM TTL ──────────────────────────
# Encapsulada em função para evitar poluição do scope $script:
# 1. Se cache existe e TTL não expirou → dot-source direto (HOT PATH: ~5ms)
# 2. Se cache existe mas TTL expirou  → recalcular fingerprint, rebuild se diferente
# 3. Se cache não existe              → rebuild completo

function script:Initialize-PluginCache {
    $needRebuild = $true

    if (Test-Path $script:Config.CachePath) {
        $firstLine = Get-Content $script:Config.CachePath -TotalCount 1 -ErrorAction SilentlyContinue
        if ($firstLine -match '^# fp:(\S+)\s+ts:(\d+)$') {
            $cachedFP = $Matches[1]
            $cachedTS = [long]$Matches[2]
            $nowTS    = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $ageMin   = ($nowTS - $cachedTS) / 60

            if ($ageMin -lt $script:Config.CacheTTLMinutes) {
                # HOT PATH: TTL válido, pular fingerprint completamente
                $needRebuild = $false
            } else {
                # TTL expirado: recalcular fingerprint para verificar mudanças
                $currentFP = script:Get-PluginFingerprint
                if ($cachedFP -eq $currentFP) {
                    # Fingerprint idêntico — apenas atualizar o timestamp (touch)
                    $content = Get-Content $script:Config.CachePath -Raw -ErrorAction SilentlyContinue
                    $newTs   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                    $content = $content -replace '^# fp:(\S+)\s+ts:\d+', "# fp:`$1 ts:${newTs}"
                    Set-Content -Path $script:Config.CachePath -Value $content -Encoding UTF8 -ErrorAction SilentlyContinue
                    $needRebuild = $false
                }
                # Se fingerprint diferente, needRebuild permanece $true
            }
        }
        # Se header não bate no regex → formato antigo, rebuild
    }

    if ($needRebuild) { script:Update-PluginCache }
    if (Test-Path $script:Config.CachePath) { . $script:Config.CachePath }
}

script:Initialize-PluginCache
