# ── 2. PLUGINS & CACHE ───────────────────────────────────────
$script:CachePath  = "$HOME\.cache_pwsh_plugins.ps1"
$script:ThemePath  = "$HOME\.poshthemes\atomic.omp.json"

# Nomes em inglês + alias, convenção unificada
function Clear-PluginCache {
    if (Test-Path $script:CachePath) {
        Remove-Item $script:CachePath -ErrorAction SilentlyContinue
    }
    # Removido Write-Host para não atrasar o boot - usuário pode verificar manualmente
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
            $parts += ($zVersion ?? 'unknown')
        } catch {
            $parts += 'unknown'
        }
    }

    if ($ocmd) {
        $parts += $ocmd.Source
        try {
            $oVersion = (Get-Item $ocmd.Source -ErrorAction SilentlyContinue).VersionInfo.FileVersion
            $parts += ($oVersion ?? 'unknown')
        } catch {
            $parts += 'unknown'
        }
    }

    $parts += $script:ThemePath
    $parts += [int](Test-Path $script:ThemePath)

    # Include theme content hash if exists for deeper change detection
    if (Test-Path $script:ThemePath) {
        try {
            $themeHash = (Get-FileHash $script:ThemePath -Algorithm MD5 -ErrorAction SilentlyContinue).Hash
            $parts += ($themeHash ?? 'nohash')
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
# Removido Write-Host para não atrasar boot - cache é silencioso por padrão
function script:Update-PluginCache {
    $buf = [System.Text.StringBuilder]::new()
    [void]$buf.AppendLine("# fp:$(script:Get-PluginFingerprint)")

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
            $themeExists = Test-Path $script:ThemePath
            $label       = if ($themeExists) { 'OMP:atomic' } else { 'OMP:default' }
            $initCmd     = if ($themeExists) {
                oh-my-posh init pwsh --config $script:ThemePath 2>&1
            } else {
                oh-my-posh init pwsh 2>&1
            }
            [void]$buf.AppendLine(($initCmd | Out-String))
            [void]$buf.AppendLine("`$script:StartupModules.Add('$label')")
        } catch {
            Write-Verbose "Update-PluginCache: oh-my-posh init falhou - $_"
        }
    }

    try   { Set-Content -Path $script:CachePath -Value $buf.ToString() -Encoding UTF8 -ErrorAction Stop }
    catch { Write-Verbose "Update-PluginCache: Falha ao salvar cache - $_" }
}

$script:CurrentFP = script:Get-PluginFingerprint
$script:CachedFP  = ''

if (Test-Path $script:CachePath) {
    $firstLine = Get-Content $script:CachePath -TotalCount 1 -ErrorAction SilentlyContinue
    if ($firstLine -match '^# fp:(.+)$') { $script:CachedFP = $Matches[1] }
}

if ($script:CachedFP -ne $script:CurrentFP) { script:Update-PluginCache }
if (Test-Path $script:CachePath)             { . $script:CachePath }