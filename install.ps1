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
$RepoZip   = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/main.zip"

# Caminhos dinâmicos — NEVER use $HOME\Documents (blindado contra OneDrive)
$DocsDir      = [Environment]::GetFolderPath('MyDocuments')
$PermanentDir = Join-Path $DocsDir $RepoName
$AppDataDir   = [Environment]::GetFolderPath('ApplicationData')
$AlacrittyDir = Join-Path $AppDataDir 'alacritty'
$OmpThemeDir  = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.poshthemes'
$UserFontDir  = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\Windows\Fonts'

$WinTermPaths = @(
    "$([Environment]::GetFolderPath('LocalApplicationData'))\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$([Environment]::GetFolderPath('LocalApplicationData'))\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    "$([Environment]::GetFolderPath('LocalApplicationData'))\Microsoft\Windows Terminal\settings.json"
)

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
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Warn "Este script precisa ser executado como Administrador."
    Write-Step "Reiniciando como Administrador..."

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/install.ps1'))`""
        $psi.Verb = 'RunAs'
        $psi.UseShellExecute = $true
        if (-not [System.Diagnostics.Process]::Start($psi)) {
            throw "Falha ao iniciar processo elevado."
        }
        exit 0
    } catch {
        Write-Fail "Não foi possível elevar privilégios: $($_.Exception.Message)"
        Write-Info "Execute manualmente como Administrador e tente novamente."
        exit 1
    }
}

Write-OK "Executando como Administrador."

# ═══════════════════════════════════════════════════════════════
# 2. UTILITÁRIOS
# ═══════════════════════════════════════════════════════════════
function Install-Winget {
    try {
        $winget = Get-Command winget -ErrorAction SlientlyContinue
        if (-not $winget) { throw "WinGet não encontrado." }
        return $winget.Source
    } catch {
        Write-Step "Instalando WinGet..."
        $url = 'https://aka.ms/getwinget'
        $msi = Join-Path $env:TEMP 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        try {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            }
            Invoke-WebRequest -Uri $url -OutFile $msi -ErrorAction Stop
            Add-AppxPackage -Path $msi -ErrorAction Stop
            Write-OK "WinGet instalado."
            return 'winget'
        } catch {
            throw "Falha ao instalar WinGet. Baixe manualmente em: https://aka.ms/getwinget"
        }
    }
}

function Install-WingetPackage {
    param([string]$Id, [string]$Nome)

    $existe = Get-Command ($Nome -replace '\..*', '').ToLower() -ErrorAction SilentlyContinue
    if ($existe) {
        Write-OK "$Nome já instalado: $($existe.Source)"
        return $true
    }

    Write-Step "Instalando $Nome via WinGet..."
    try {
        $proc = Start-Process -FilePath 'winget' -ArgumentList @(
            'install', "--id=$Id",
            '--silent',
            '--accept-source-agreements',
            '--accept-package-agreements'
        ) -Wait -PassThru -NoNewWindow

        if ($proc.ExitCode -eq 0) {
            Write-OK "$Nome instalado com sucesso."
            return $true
        } elseif ($proc.ExitCode -eq -1978335189) {
            Write-OK "$Nome já estava instalado."
            return $true
        } else {
            Write-Warn "WinGet retornou código $($proc.ExitCode) para $Nome."
            return $false
        }
    } catch {
        Write-Warn "Falha ao instalar $Nome: $($_.Exception.Message)"
        return $false
    }
}

function Download-ComRepositorio {
    $profilePath = Join-Path $PermanentDir 'Microsoft.PowerShell_profile.ps1'
    if ((Test-Path $profilePath) -and (Test-Path (Join-Path $PermanentDir 'modules'))) {
        Write-OK "Repositório já existe em: $PermanentDir"
        return $PermanentDir
    }

    Write-Step "Baixando repositório $RepoOwner/$RepoName ..."
    $zipPath = Join-Path $env:TEMP "$RepoName.zip"
    $tempDir = Join-Path $env:TEMP "$RepoName-extract"

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $RepoZip -OutFile $zipPath -ErrorAction Stop
    } catch { throw "Falha ao baixar repositório — verifique sua internet. $($_.Exception.Message)" }

    try {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        if (Test-Path $PermanentDir) { Remove-Item $PermanentDir -Recurse -Force }

        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir)

        $inner = Get-ChildItem $tempDir -Directory | Select-Object -First 1
        if (-not $inner) { throw "ZIP vazio ou inválido." }

        Move-Item $inner.FullName $PermanentDir -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

        # Desbloqueia arquivos baixados
        Get-ChildItem $PermanentDir -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue

        Write-OK "Repositório instalado em: $PermanentDir"
        return $PermanentDir
    } catch { throw "Falha ao extrair repositório. $($_.Exception.Message)" }
}

function Install-FonteNerd {
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    if ([System.Drawing.FontFamily]::Families | Where-Object { $_.Name -match 'FiraCode Nerd' }) {
        Write-OK "FiraCode Nerd Font já instalada."
        return $true
    }

    Write-Step "Instalando FiraCode Nerd Font..."
    $url = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip'
    $zip = Join-Path $env:TEMP 'FiraCode-NerdFont.zip'
    $dir = Join-Path $env:TEMP 'FiraCode-NerdFont'

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $url -OutFile $zip -ErrorAction Stop
    } catch { throw "Falha ao baixar fonte — verifique sua internet. $($_.Exception.Message)" }

    try {
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir)

        if (-not (Test-Path $UserFontDir)) { New-Item -ItemType Directory -Path $UserFontDir -Force | Out-Null }

        $shell = New-Object -ComObject Shell.Application
        $fonts = $shell.Namespace(0x14)
        $count = 0
        foreach ($f in (Get-ChildItem $dir -Filter '*.ttf' -Recurse)) {
            try { $fonts.CopyHere($f.FullName, 0x14); $count++ } catch { }
        }
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue

        if ($count -gt 0) { Write-OK "FiraCode Nerd Font instalada ($count variantes)."; return $true }
        Write-Warn "Nenhuma fonte foi instalada."
        return $false
    } catch { throw "Falha ao instalar fontes. $($_.Exception.Message)" }
}

function Install-ConfigAlacritty {
    $configPath = Join-Path $AlacrittyDir 'alacritty.toml'
    if (-not (Test-Path $AlacrittyDir)) { New-Item -ItemType Directory -Path $AlacrittyDir -Force | Out-Null }

    if (Test-Path $configPath) {
        $bak = "$configPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $configPath $bak -Force
        Write-Info "Backup do Alacritty: $bak"
    }

    try {
        Set-Content -Path $configPath -Value @'
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
'@ -Encoding UTF8 -Force

        Write-OK "Alacritty configurado: $configPath"
        return $true
    } catch { throw "Falha ao escrever config do Alacritty. $($_.Exception.Message)" }
}

function Install-TemaOhMyPosh {
    $themePath = Join-Path $OmpThemeDir 'atomic.omp.json'

    if (Test-Path $themePath) {
        try {
            $raw = Get-Content $themePath -Raw -ErrorAction SilentlyContinue
            if ($raw -and $raw.Length -gt 100) { Write-OK "Tema OMP já existe."; return $true }
        } catch { }
    }

    if (-not (Test-Path $OmpThemeDir)) { New-Item -ItemType Directory -Path $OmpThemeDir -Force | Out-Null }

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json' -OutFile $themePath -ErrorAction Stop
        Write-OK "Tema OMP baixado: $themePath"
        return $true
    } catch {
        Write-Warn "Não foi possível baixar o tema OMP: $($_.Exception.Message)"
        return $false
    }
}

function Install-ConfigWindowsTerminal {
    $settingsPath = $WinTermPaths | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
    if (-not $settingsPath) { Write-Info "Windows Terminal não encontrado. Pulando."; return $false }

    try {
        $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $settings.profiles) { return $false }

        $fontName = 'FiraCode Nerd Font'
        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -Name 'defaults' -Value @{} -MemberType NoteProperty -Force
        }
        $fontObj = if ($settings.profiles.defaults.PSObject.Properties['font']) { $settings.profiles.defaults.font } else { $null }
        if (-not $fontObj) {
            $fontObj = [PSCustomObject]@{}
            $settings.profiles.defaults | Add-Member -Name 'font' -Value $fontObj -MemberType NoteProperty -Force
        }
        if ($fontObj.face -eq $fontName) { Write-OK "WT já usa $fontName."; return $true }

        $fontObj | Add-Member -Name 'face' -Value $fontName -MemberType NoteProperty -Force
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8 -Force
        Write-OK "Fonte do WT alterada para: $fontName"
        return $true
    } catch { Write-Warn "Falha ao configurar WT: $($_.Exception.Message)"; return $false }
}

function Install-LinkProfile {
    $targetProfile = if ($PROFILE -is [string] -and $PROFILE) { $PROFILE } else { $PROFILE.CurrentUserCurrentHost }
    $targetDir  = Split-Path $targetProfile -Parent
    $source     = Join-Path $PermanentDir 'Microsoft.PowerShell_profile.ps1'

    if (-not (Test-Path $source)) { throw "Profile não encontrado no repositório: $source" }

    if (Test-Path $targetProfile) {
        $c = Get-Content $targetProfile -Raw -ErrorAction SilentlyContinue
        if ($c -match '\. "[^"]*Microsoft\.PowerShell_profile\.ps1"') {
            Write-OK "Profile já linkado corretamente."
            return $true
        }
        $bak = "$targetProfile.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path $bak) { $bak = "$targetProfile.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random)" }
        Copy-Item $targetProfile $bak -Force
        Write-Info "Backup do profile: $bak"
        Remove-Item $targetProfile -Force
    }

    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }

    try {
        Set-Content -Path $targetProfile -Value "# Generated by config-powershell7 installer`n`$env:__PROFILE_REPO_ROOT = `"$PermanentDir`"`n. `"$source`"" -Encoding UTF8 -Force
        Write-OK "Profile linkado: $targetProfile"
        return $true
    } catch { throw "Falha ao linkar profile. $($_.Exception.Message)" }
}

# ═══════════════════════════════════════════════════════════════
# 3. ORQUESTRAÇÃO
# ═══════════════════════════════════════════════════════════════
Write-Host @"

  ╔══════════════════════════════════════════════╗
  ║   config-powershell7 — Instalador Universal  ║
  ╚══════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Força TLS 1.2 para PS 5.1
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

# Passo 0: WinGet
$wingetPath = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetPath) {
    Write-Step "[0/9] Instalando WinGet..."
    $wingetPath = Install-Winget
} else {
    Write-OK "WinGet disponível: $($wingetPath.Source)"
}

# Passo 1: PowerShell 7
Install-WingetPackage -Id 'Microsoft.PowerShell' -Nome 'PowerShell 7'

# Passo 2: Git
Install-WingetPackage -Id 'Git.Git' -Nome 'Git'

# Passo 3: Oh My Posh
Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Nome 'Oh My Posh'

# Passo 4: Zoxide
Install-WingetPackage -Id 'ajeetdsouza.zoxide' -Nome 'Zoxide'

# Passo 5: Alacritty
Install-WingetPackage -Id 'Alacritty.Alacritty' -Nome 'Alacritty'

# Passo 6: Repositório
Install-WingetPackage -Id 'Microsoft.PowerShell' -Nome 'PowerShell 7'

# Passo 7: Fontes + Configs
$passos = @(
    @{ Nome = 'Baixar repositório';     Script = { Download-ComRepositorio } }
    @{ Nome = 'Instalar FiraCode Font'; Script = { Install-FonteNerd } }
    @{ Nome = 'Configurar Alacritty';   Script = { Install-ConfigAlacritty } }
    @{ Nome = 'Configurar WT';          Script = { Install-ConfigWindowsTerminal } }
    @{ Nome = 'Baixar tema OMP';        Script = { Install-TemaOhMyPosh } }
    @{ Nome = 'Linkar profile';         Script = { Install-LinkProfile } }
)

$erros = 0
for ($i = 0; $i -lt $passos.Count; $i++) {
    Write-Step "[$($i+7)/$($passos.Count+7)] $($passos[$i].Nome)"
    try { & $passos[$i].Script } catch { Write-Fail "$($passos[$i].Nome) falhou: $($_.Exception.Message)"; $erros++ }
}

# ═══════════════════════════════════════════════════════════════
# 4. SUMÁRIO
# ═══════════════════════════════════════════════════════════════
Write-Host @"
  ╔══════════════════════════════════════════════╗
"@ -ForegroundColor Cyan

if ($erros -eq 0) {
    Write-Host "  ║   Instalação concluída com sucesso!        ║" -ForegroundColor Green
} else {
    Write-Host "  ║   Concluído com $erros erro(s).                ║" -ForegroundColor Yellow
}

Write-Host @"
  ╚══════════════════════════════════════════════╝

  Repositório: $PermanentDir
  Profile:     $targetProfile

  Reinicie o terminal para aplicar as mudanças.
"@ -ForegroundColor Cyan
