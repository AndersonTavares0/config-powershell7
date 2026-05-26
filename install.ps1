#Requires -Version 5.1
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ═══════════════════════════════════════════════════════════════
# CONFIGURAÇÕES
# ═══════════════════════════════════════════════════════════════
$RepoOwner = 'AndersonTavares0'
$RepoName  = 'config-powershell7'
$RepoUrl   = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/main.zip"

# Usa [Environment]::GetFolderPath — funciona com OneDrive e caminhos customizados
$DocsPath = [Environment]::GetFolderPath('MyDocuments')
$PermanentDir = Join-Path $DocsPath $RepoName

# ═══════════════════════════════════════════════════════════════
# FUNÇÕES DE LOG
# ═══════════════════════════════════════════════════════════════
function Write-OK    { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Fail  { Write-Host "[FAIL] $args" -ForegroundColor Red }
function Write-Step  { Write-Host "`n[>>>] $args" -ForegroundColor Cyan }
function Write-Info  { Write-Host "[--] $args" -ForegroundColor Gray }

# ═══════════════════════════════════════════════════════════════
# 1. ELEVAÇÃO DE PRIVILÉGIO
# ═══════════════════════════════════════════════════════════════
function Test-IsAdministrator {
    if ($PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux) { return $false }
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Warn "Este script precisa ser executado como Administrador."
    Write-Step "Reiniciando como Administrador..."

    try {
        $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { "$PSScriptRoot\install.ps1" }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $psi.Verb = 'RunAs'
        $psi.UseShellExecute = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        if (-not $proc) { throw "Falha ao iniciar processo elevado." }
        exit 0
    } catch {
        Write-Fail "Não foi possível elevar privilégios: $($_.Exception.Message)"
        Write-Info "Execute manualmente como Administrador e tente novamente."
        exit 1
    }
}

Write-OK "Executando como Administrador."

# ═══════════════════════════════════════════════════════════════
# 2. DETECÇÃO DE PLATAFORMA (caminhos dinâmicos)
# ═══════════════════════════════════════════════════════════════
$script:IsWin = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }

# Caminhos dinâmicos — NEVER use $HOME\Documents
$script:UserFontsDir  = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\Windows\Fonts'
$script:AppDataDir    = [Environment]::GetFolderPath('ApplicationData')
$script:AlacrittyDir  = Join-Path $script:AppDataDir 'alacritty'
$script:ChocoFontReg  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$script:UserFontReg   = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$script:WinTermPaths  = @(
    "$([Environment]::GetFolderPath('LocalApplicationData'))\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$([Environment]::GetFolderPath('LocalApplicationData'))\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    "$([Environment]::GetFolderPath('LocalApplicationData'))\Microsoft\Windows Terminal\settings.json"
)

# ═══════════════════════════════════════════════════════════════
# 3. FUNÇÕES PRINCIPAIS (idempotentes)
# ═══════════════════════════════════════════════════════════════

function Install-Repositorio {
    <#
    .DESCRIÇÃO
        Baixa o repositório para a pasta Documentos (se não existir)
        e retorna o caminho. Idempotente: se já existe, apenas retorna.
    #>
    $repoProfilePath = Join-Path $PermanentDir 'Microsoft.PowerShell_profile.ps1'

    if ((Test-Path $repoProfilePath) -and (Test-Path (Join-Path $PermanentDir 'modules')) -and (Test-Path (Join-Path $PermanentDir 'setup'))) {
        Write-OK "Repositório já existe em: $PermanentDir"
        return $PermanentDir
    }

    Write-Step "Baixando repositório de $RepoOwner/$RepoName ..."
    $zipPath = Join-Path $env:TEMP "$RepoName.zip"
    $extractDir = Join-Path $env:TEMP "$RepoName-extract"

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }

        Invoke-WebRequest -Uri $RepoUrl -OutFile $zipPath -ErrorAction Stop
        Write-OK "Download concluído ($([Math]::Round((Get-Item $zipPath).Length / 1KB, 1)) KB)."
    } catch {
        throw "Falha ao baixar o repositório — verifique sua conexão com a internet. Detalhes: $($_.Exception.Message)"
    }

    try {
        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        if (Test-Path $PermanentDir) { Remove-Item $PermanentDir -Recurse -Force }

        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

        $innerDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
        if (-not $innerDir) { throw "Nenhuma pasta encontrada dentro do arquivo ZIP." }

        Move-Item $innerDir.FullName $PermanentDir -Force

        # Remove lixo
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

        # Desbloqueia arquivos baixados
        Get-ChildItem $PermanentDir -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue

        Write-OK "Repositório instalado em: $PermanentDir"
        return $PermanentDir
    } catch {
        throw "Falha ao extrair o repositório. Detalhes: $($_.Exception.Message)"
    }
}

function Install-FonteNerd {
    <#
    .DESCRIÇÃO
        Instala a FiraCode Nerd Font via Shell API do Windows.
        Idempotente: verifica se já existe antes de baixar.
    #>

    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $fontesExistentes = [System.Drawing.FontFamily]::Families | Where-Object { $_.Name -match 'FiraCode Nerd' }
    if ($fontesExistentes) {
        Write-OK "FiraCode Nerd Font já instalada ($($fontesExistentes.Count) variante(s))."
        return $true
    }

    Write-Step "Instalando FiraCode Nerd Font..."
    $fontZipUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip'
    $fontZip = Join-Path $env:TEMP 'FiraCode-NerdFont.zip'
    $fontDir = Join-Path $env:TEMP 'FiraCode-NerdFont'

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $fontZipUrl -OutFile $fontZip -ErrorAction Stop
    } catch {
        throw "Falha ao baixar a FiraCode Nerd Font — verifique sua conexão. Detalhes: $($_.Exception.Message)"
    }

    try {
        if (Test-Path $fontDir) { Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $fontDir -Force | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($fontZip, $fontDir)

        # Garante que a pasta de fontes do usuário existe
        if (-not (Test-Path $script:UserFontsDir)) {
            New-Item -ItemType Directory -Path $script:UserFontsDir -Force | Out-Null
        }

        # Usa Shell API em vez de New-ItemProperty (evita erro de nome de registro)
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $shell = New-Object -ComObject Shell.Application
        $fontsFolder = $shell.Namespace(0x14)

        $instaladas = 0
        foreach ($fonte in (Get-ChildItem $fontDir -Filter '*.ttf' -Recurse)) {
            try {
                $fontsFolder.CopyHere($fonte.FullName, 0x14)
                $instaladas++
            } catch {
                Write-Warn "Não foi possível instalar $($fonte.Name): $($_.Exception.Message)"
            }
        }

        Remove-Item $fontZip -Force -ErrorAction SilentlyContinue
        Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue

        if ($instaladas -gt 0) {
            Write-OK "FiraCode Nerd Font instalada ($instaladas variantes)."
            return $true
        } else {
            Write-Warn "Nenhuma fonte foi instalada."
            return $false
        }
    } catch {
        throw "Falha ao instalar as fontes. Detalhes: $($_.Exception.Message)"
    }
}

function Install-ConfigAlacritty {
    <#
    .DESCRIÇÃO
        Cria/configura o arquivo alacritty.toml.
        Idempotente: faz backup do existente antes de sobrescrever.
    #>

    $configPath = Join-Path $script:AlacrittyDir 'alacritty.toml'

    if (-not (Test-Path $script:AlacrittyDir)) {
        New-Item -ItemType Directory -Path $script:AlacrittyDir -Force | Out-Null
    }

    if (Test-Path $configPath) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$configPath.bak-$timestamp"
        Copy-Item $configPath $backup -Force
        Write-Info "Backup do Alacritty existente criado: $backup"
    }

    $configContent = @'
[terminal.shell]
program = "pwsh.exe"
args = ["-NoLogo"]

[font]
size = 12.0
normal = { family = "FiraCode Nerd Font", style = "Regular" }
bold = { family = "FiraCode Nerd Font", style = "Bold" }
italic = { family = "FiraCode Nerd Font", style = "Italic" }
bold_italic = { family = "FiraCode Nerd Font", style = "Bold Italic" }

[window]
padding = { x = 12, y = 12 }
dynamic_padding = true
opacity = 0.9
blur = true
decorations = "full"

[colors.primary]
background = "#1a1b26"
foreground = "#a9b1d6"

[colors.normal]
black   = "#15161e"
red     = "#f7768e"
green   = "#9ece6a"
yellow  = "#e0af68"
blue    = "#7aa2f7"
magenta = "#bb9af7"
cyan    = "#7dcfff"
white   = "#a9b1d6"

[colors.bright]
black   = "#414868"
red     = "#f7768e"
green   = "#9ece6a"
yellow  = "#e0af68"
blue    = "#7aa2f7"
magenta = "#bb9af7"
cyan    = "#7dcfff"
white   = "#c0caf5"
'@

    try {
        Set-Content -Path $configPath -Value $configContent -Encoding UTF8 -Force
        Write-OK "Alacritty configurado em: $configPath"
        return $true
    } catch {
        throw "Falha ao escrever config do Alacritty. Detalhes: $($_.Exception.Message)"
    }
}

function Install-TemaOhMyPosh {
    <#
    .DESCRIÇÃO
        Baixa o tema atomic.omp.json para $HOME\.poshthemes.
        Idempotente: se já existe e é válido, pula.
    #>

    $themeDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.poshthemes'
    $themePath = Join-Path $themeDir 'atomic.omp.json'

    if (Test-Path $themePath) {
        try {
            $raw = Get-Content $themePath -Raw -ErrorAction SilentlyContinue
            if ($raw -and $raw.Length -gt 100) {
                Write-OK "Tema Oh My Posh já existe: $themePath"
                return $true
            }
        } catch { }
    }

    if (-not (Test-Path $themeDir)) {
        New-Item -ItemType Directory -Path $themeDir -Force | Out-Null
    }

    $temaUrl = 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json'

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $temaUrl -OutFile $themePath -ErrorAction Stop
        Write-OK "Tema Oh My Posh baixado para: $themePath"
        return $true
    } catch {
        Write-Warn "Não foi possível baixar o tema OMP: $($_.Exception.Message)"
        Write-Info "O Oh My Posh usará o tema padrão. Instale manualmente com: oh-my-posh config export --config $themePath"
        return $false
    }
}

function Install-ConfigWindowsTerminal {
    <#
    .DESCRIÇÃO
        Define FiraCode Nerd Font como fonte padrão no Windows Terminal.
        Idempotente: verifica se já está configurado.
    #>

    $settingsPath = $script:WinTermPaths | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
    if (-not $settingsPath) {
        Write-Info "Windows Terminal não encontrado. Pulando configuração de fonte."
        return $false
    }

    try {
        $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $fontName = 'FiraCode Nerd Font'

        if (-not $settings.profiles) { return $false }

        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -Name 'defaults' -Value @{} -MemberType NoteProperty -Force
        }
        $fontProp = $settings.profiles.defaults.PSObject.Properties['font']
        $fontObj = if ($fontProp) { $fontProp.Value } else { $null }
        if (-not $fontObj) {
            $fontObj = [PSCustomObject]@{}
            $settings.profiles.defaults | Add-Member -Name 'font' -Value $fontObj -MemberType NoteProperty -Force
        }

        $faceProp = $fontObj.PSObject.Properties['face']
        if ($faceProp -and $faceProp.Value -eq $fontName) {
            Write-OK "Windows Terminal já usa $fontName."
            return $true
        }

        $fontObj | Add-Member -Name 'face' -Value $fontName -MemberType NoteProperty -Force

        # Aplica também em cada perfil individual
        $profileList = $settings.profiles.PSObject.Properties['list']
        if ($profileList -and $profileList.Value) {
            foreach ($perfil in $profileList.Value) {
                $pfFontProp = $perfil.PSObject.Properties['font']
                $pfFont = if ($pfFontProp) { $pfFontProp.Value } else { $null }
                if (-not $pfFont) {
                    $pfFont = [PSCustomObject]@{}
                    $perfil | Add-Member -Name 'font' -Value $pfFont -MemberType NoteProperty -Force
                }
                $pfFont | Add-Member -Name 'face' -Value $fontName -MemberType NoteProperty -Force
            }
        }

        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8 -Force
        Write-OK "Fonte do Windows Terminal alterada para: $fontName"
        return $true
    } catch {
        Write-Warn "Não foi possível configurar a fonte do Windows Terminal: $($_.Exception.Message)"
        return $false
    }
}

function Install-LinkProfile {
    <#
    .DESCRIÇÃO
        Cria o link dot-source no $PROFILE apontando para o repositório.
        Idempotente: se já linkado corretamente, pula.
    #>

    $targetProfile = if ($PROFILE -is [string] -and $PROFILE) { $PROFILE } else { $PROFILE.CurrentUserCurrentHost }
    $targetDir = Split-Path $targetProfile -Parent
    $sourceProfile = Join-Path $PermanentDir 'Microsoft.PowerShell_profile.ps1'

    if (-not (Test-Path $sourceProfile)) {
        throw "Arquivo de profile não encontrado no repositório: $sourceProfile"
    }

    if (Test-Path $targetProfile) {
        $content = Get-Content $targetProfile -Raw -ErrorAction SilentlyContinue
        if ($content -match '\. "[^"]*Microsoft\.PowerShell_profile\.ps1"') {
            Write-OK "Profile já está linkado corretamente."
            return $true
        }

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = "$targetProfile.bak-$timestamp"
        if (Test-Path $backupPath) { $backupPath = "$targetProfile.bak-$timestamp-$(Get-Random)" }
        Copy-Item $targetProfile $backupPath -Force
        Write-Info "Backup do profile existente: $backupPath"
        Remove-Item $targetProfile -Force
    }

    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }

    try {
        $linkContent = "# Generated by config-powershell7 installer`n`$env:__PROFILE_REPO_ROOT = `"$PermanentDir`"`n. `"$sourceProfile`""
        Set-Content -Path $targetProfile -Value $linkContent -Encoding UTF8 -Force
        Write-OK "Profile linkado com sucesso: $targetProfile"
        return $true
    } catch {
        throw "Falha ao criar link do profile. Detalhes: $($_.Exception.Message)"
    }
}

# ═══════════════════════════════════════════════════════════════
# 4. ORQUESTRAÇÃO PRINCIPAL
# ═══════════════════════════════════════════════════════════════
Write-Host @"

  ╔══════════════════════════════════════════════╗
  ║   config-powershell7 — Instalador Universal  ║
  ╚══════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

$erros = 0
$passos = @(
    { Install-Repositorio }
    { Install-FonteNerd }
    { Install-ConfigAlacritty }
    { Install-ConfigWindowsTerminal }
    { Install-TemaOhMyPosh }
    { Install-LinkProfile }
)

for ($i = 0; $i -lt $passos.Count; $i++) {
    $nome = $passos[$i].ToString().Split('.')[-1].Replace(' ', '').Replace('}', '')
    Write-Step "[$($i+1)/$($passos.Count)] $nome"
    try {
        & $passos[$i]
    } catch {
        Write-Fail "Erro em $nome : $($_.Exception.Message)"
        $erros++
    }
}

# ═══════════════════════════════════════════════════════════════
# 5. SUMÁRIO
# ═══════════════════════════════════════════════════════════════
Write-Host @"

  ╔══════════════════════════════════════════════╗
"@ -ForegroundColor Cyan

if ($erros -eq 0) {
    Write-Host "  ║   Instalação concluída com sucesso!        ║" -ForegroundColor Green
} else {
    Write-Host "  ║   Instalação concluída com $erros erro(s).      ║" -ForegroundColor Yellow
}

Write-Host @"
  ╚══════════════════════════════════════════════╝

  Reinicie o terminal para aplicar as mudanças.

  Repositório: $PermanentDir
  Profile:     $PROFILE

"@ -ForegroundColor Cyan
