# ── 2. PLUGINS & CACHE ───────────────────────────────────────
$script:CachePath  = "$HOME\.cache_pwsh_plugins.ps1"
$script:ThemePath  = "$HOME\.poshthemes\atomic.omp.json"

# Nomes em inglês + alias, convenção unificada
function Clear-PluginCache {
    Remove-Item $script:CachePath -ErrorAction SilentlyContinue
    Write-Host "Cache removido. Reinicie o terminal." -ForegroundColor Green
}
Set-Alias Clear-Cache Clear-PluginCache

# Verifica se ja carregado antes de chamar Import-Module
function Import-TerminalIcons {
    if (Get-Module Terminal-Icons) {
        Write-Host "Terminal-Icons ja esta carregado." -ForegroundColor Yellow
        return
    }
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    if (Get-Module Terminal-Icons) { Write-Host "Terminal-Icons carregado." -ForegroundColor Green }
    else { Write-Warning "Terminal-Icons nao encontrado. Execute: Install-Module Terminal-Icons" }
}
Set-Alias icons Import-TerminalIcons

# MD5 encapsulado em try/finally: garante Dispose() mesmo em falha.
# $script:ThemePath centralizado - um unico ponto de referencia para o tema.
function script:Get-PluginFingerprint {
    $zcmd = Get-Command zoxide -ErrorAction SilentlyContinue
    $ocmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    $parts = @(
        if ($zcmd) { $zcmd.Source } else { $null }
        if ($ocmd) { $ocmd.Source } else { $null }
        $script:ThemePath
        [int](Test-Path $script:ThemePath)
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($parts -join '|')
    $md5   = [System.Security.Cryptography.MD5]::Create()
    try    { [System.BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '' }
    finally{ $md5.Dispose() }
}

# Logica de rebuild extraida: testavel, nomeada, sem bloco `& {}` anonimo
function script:Update-PluginCache {
    Write-Host "Atualizando cache de plugins..." -ForegroundColor DarkGray
    $buf = [System.Text.StringBuilder]::new()
    [void]$buf.AppendLine("# fp:$(script:Get-PluginFingerprint)")

    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        [void]$buf.AppendLine((zoxide init powershell | Out-String))
        [void]$buf.AppendLine("`$script:StartupModules.Add('Zoxide')")
    }

    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        $themeExists = Test-Path $script:ThemePath
        $label       = if ($themeExists) { 'OMP:atomic' } else { 'OMP:default' }
        $initCmd     = if ($themeExists) { oh-my-posh init pwsh --config $script:ThemePath }
                       else              { oh-my-posh init pwsh }
        [void]$buf.AppendLine(($initCmd | Out-String))
        [void]$buf.AppendLine("`$script:StartupModules.Add('$label')")
    }

    try   { Set-Content -Path $script:CachePath -Value $buf.ToString() -Encoding UTF8 -ErrorAction Stop }
    catch { Write-Warning "Falha ao salvar cache: $_" }
}

$script:CurrentFP = script:Get-PluginFingerprint
$script:CachedFP  = ''

if (Test-Path $script:CachePath) {
    $firstLine = Get-Content $script:CachePath -TotalCount 1 -ErrorAction SilentlyContinue
    if ($firstLine -match '^# fp:(.+)$') { $script:CachedFP = $Matches[1] }
}

if ($script:CachedFP -ne $script:CurrentFP) { script:Update-PluginCache }
if (Test-Path $script:CachePath)             { . $script:CachePath }
