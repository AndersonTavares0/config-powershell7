param(
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [switch]$NonInteractive,
    [string]$ThemeName = '',
    [switch]$InstallAlacritty
)

$ErrorActionPreference = 'Continue'

# ═══════════════════════════════════════════════════════════════
# CONFIGURAÇÕES
# ═══════════════════════════════════════════════════════════════
$RepoOwner = 'AndersonTavares0'
$RepoName  = 'config-powershell7'
$RepoZip   = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/main.zip"
$ScriptUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/install.ps1"

# Caminhos dinâmicos - NEVER use $HOME\Documents (blindado contra OneDrive)
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

# Terminal theme data (same source as setup/modules/deps.ps1)
$script:TerminalThemeDataLegacy = [ordered]@{
    'Catppuccin Mocha' = @{
        Type = 'dark'; Description = 'Dark purple theme from Catppuccin project'
        WT = @{ foreground = '#CDD6F4'; background = '#1E1E2E'; cursorColor = '#F5E0DC'; selectionBackground = '#45475A'
                black = '#45475A'; red = '#F38BA8'; green = '#A6E3A1'; yellow = '#F9E2AF'
                blue = '#89B4FA'; purple = '#F5C2E7'; cyan = '#94E2D5'; white = '#BAC2DE'
                brightBlack = '#585B70'; brightRed = '#F38BA8'; brightGreen = '#A6E3A1'
                brightYellow = '#F9E2AF'; brightBlue = '#89B4FA'; brightPurple = '#F5C2E7'
                brightCyan = '#94E2D5'; brightWhite = '#A6ADC8' }
        Ala = @{ primary = @{ background = '#1E1E2E'; foreground = '#CDD6F4' }
                 normal = @{ black = '#45475A'; red = '#F38BA8'; green = '#A6E3A1'
                             yellow = '#F9E2AF'; blue = '#89B4FA'; magenta = '#F5C2E7'
                             cyan = '#94E2D5'; white = '#BAC2DE' }
                 bright = @{ black = '#585B70'; red = '#F38BA8'; green = '#A6E3A1'
                             yellow = '#F9E2AF'; blue = '#89B4FA'; magenta = '#F5C2E7'
                             cyan = '#94E2D5'; white = '#A6ADC8' } }
    }
    'Dracula' = @{
        Type = 'dark'; Description = 'Popular dark theme with purple accents'
        WT = @{ foreground = '#F8F8F2'; background = '#282A36'; cursorColor = '#F8F8F2'; selectionBackground = '#44475A'
                black = '#21222C'; red = '#FF5555'; green = '#50FA7B'; yellow = '#F1FA8C'
                blue = '#BD93F9'; purple = '#FF79C6'; cyan = '#8BE9FD'; white = '#F8F8F2'
                brightBlack = '#6272A4'; brightRed = '#FF6E6E'; brightGreen = '#69FF94'
                brightYellow = '#FFFFA5'; brightBlue = '#D6ACFF'; brightPurple = '#FF92DF'
                brightCyan = '#A4FFFF'; brightWhite = '#FFFFFF' }
        Ala = @{ primary = @{ background = '#282A36'; foreground = '#F8F8F2' }
                 normal = @{ black = '#21222C'; red = '#FF5555'; green = '#50FA7B'
                             yellow = '#F1FA8C'; blue = '#BD93F9'; magenta = '#FF79C6'
                             cyan = '#8BE9FD'; white = '#F8F8F2' }
                 bright = @{ black = '#6272A4'; red = '#FF6E6E'; green = '#69FF94'
                             yellow = '#FFFFA5'; blue = '#D6ACFF'; magenta = '#FF92DF'
                             cyan = '#A4FFFF'; white = '#FFFFFF' } }
    }
    'Nord' = @{
        Type = 'dark'; Description = 'Arctic bluish dark theme'
        WT = @{ foreground = '#D8DEE9'; background = '#2E3440'; cursorColor = '#D8DEE9'; selectionBackground = '#434C5E'
                black = '#3B4252'; red = '#BF616A'; green = '#A3BE8C'; yellow = '#EBCB8B'
                blue = '#81A1C1'; purple = '#B48EAD'; cyan = '#88C0D0'; white = '#E5E9F0'
                brightBlack = '#4C566A'; brightRed = '#BF616A'; brightGreen = '#A3BE8C'
                brightYellow = '#EBCB8B'; brightBlue = '#81A1C1'; brightPurple = '#B48EAD'
                brightCyan = '#8FBCBB'; brightWhite = '#ECEFF4' }
        Ala = @{ primary = @{ background = '#2E3440'; foreground = '#D8DEE9' }
                 normal = @{ black = '#3B4252'; red = '#BF616A'; green = '#A3BE8C'
                             yellow = '#EBCB8B'; blue = '#81A1C1'; magenta = '#B48EAD'
                             cyan = '#88C0D0'; white = '#E5E9F0' }
                 bright = @{ black = '#4C566A'; red = '#BF616A'; green = '#A3BE8C'
                             yellow = '#EBCB8B'; blue = '#81A1C1'; magenta = '#B48EAD'
                             cyan = '#8FBCBB'; white = '#ECEFF4' } }
    }
    'Tokyo Night' = @{
        Type = 'dark'; Description = 'Deep blue night theme'
        WT = @{ foreground = '#A9B1D6'; background = '#1A1B26'; cursorColor = '#A9B1D6'; selectionBackground = '#283457'
                black = '#1D202F'; red = '#F7768E'; green = '#9ECE6A'; yellow = '#E0AF68'
                blue = '#7AA2F7'; purple = '#BB9AF7'; cyan = '#7DCFFF'; white = '#A9B1D6'
                brightBlack = '#565F89'; brightRed = '#F7768E'; brightGreen = '#9ECE6A'
                brightYellow = '#E0AF68'; brightBlue = '#7AA2F7'; brightPurple = '#BB9AF7'
                brightCyan = '#7DCFFF'; brightWhite = '#C0CAF5' }
        Ala = @{ primary = @{ background = '#1A1B26'; foreground = '#A9B1D6' }
                 normal = @{ black = '#1D202F'; red = '#F7768E'; green = '#9ECE6A'
                             yellow = '#E0AF68'; blue = '#7AA2F7'; magenta = '#BB9AF7'
                             cyan = '#7DCFFF'; white = '#A9B1D6' }
                 bright = @{ black = '#565F89'; red = '#F7768E'; green = '#9ECE6A'
                             yellow = '#E0AF68'; blue = '#7AA2F7'; magenta = '#BB9AF7'
                             cyan = '#7DCFFF'; white = '#C0CAF5' } }
    }
}
function Get-TerminalThemeDataLegacy {
    param([string]$Name)
    return $script:TerminalThemeDataLegacy[$Name]
}
function Get-TerminalThemeListLegacy {
    return $script:TerminalThemeDataLegacy.Keys | ForEach-Object {
        $d = $script:TerminalThemeDataLegacy[$_]
        [PSCustomObject]@{ Name = $_; Type = $d.Type; Description = $d.Description }
    }
}

# ═══════════════════════════════════════════════════════════════
# FUNÇÕES DE LOG
# ═══════════════════════════════════════════════════════════════
function Write-OK    { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Fail  { Write-Host "[FAIL] $args" -ForegroundColor Red }
function Write-Step  { Write-Host "`n[>>>] $args" -ForegroundColor Cyan }
function Write-Info  { Write-Host "[--] $args" -ForegroundColor Gray }

# Variáveis globais para o sumário - evitam StrictMode crash se funções falharem
$targetProfile = $null
$erros = 0

# ═══════════════════════════════════════════════════════════════
# 1. ELEVAÇÃO DE PRIVILÉGIO
# ═══════════════════════════════════════════════════════════════
function Test-IsAdministrator {
    if ($PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux) { return $false }
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Tenta elevar para Admin, mas NÃO bloqueia se falhar
# A maioria das operações (fontes, configs, profile) funciona sem admin
if (-not (Test-IsAdministrator)) {
    Write-Step "Tentando elevação para Administrador..."
    try {
        $tempScript = Join-Path $env:TEMP "config-pwsh7-install.ps1"
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $ScriptUrl -OutFile $tempScript -ErrorAction Stop

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""
        $psi.Verb = 'RunAs'
        $psi.UseShellExecute = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($proc) { exit 0 }
        throw "Processo não iniciado."
    } catch {
        Write-Warn "Elevação falhou: $($_.Exception.Message)"
        Write-Info "Continuando sem admin - algumas instalações podem requerer permissão manual."
    }
}

Write-OK "Executando como Administrador."

# ═══════════════════════════════════════════════════════════════
# 2. UTILITÁRIOS
# ═══════════════════════════════════════════════════════════════
function Install-Winget {
    try {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
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
    param([string]$Id, [string]$Nome, [string]$CommandName)

    $existe = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($existe) {
        $ver = & $CommandName --version 2>$null
        $verStr = if ($ver) { " [$($ver.Trim())]" } else { '' }
        Write-OK "$Nome já instalado: $($existe.Source)$verStr"
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
        Write-Warn "Falha ao instalar ${Nome}: $($_.Exception.Message)"
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
    } catch { throw "Falha ao baixar repositório - verifique sua internet. $($_.Exception.Message)" }

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
    } catch { throw "Falha ao baixar fonte - verifique sua internet. $($_.Exception.Message)" }

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
            try { $fonts.CopyHere($f.FullName, 0x14); $count++ } catch { Write-Warn "Falha ao instalar $($f.Name): $($_.Exception.Message)" }
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
    param([string]$ThemeName = 'atomic')

    if ([string]::IsNullOrWhiteSpace($ThemeName)) { return $false }

    $ompCmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if (-not $ompCmd) {
        Write-Warn "Oh My Posh não encontrado no PATH. Pulando download do tema."
        return $false
    }

    $themePath = Join-Path $OmpThemeDir "$ThemeName.omp.json"

    if (Test-Path $themePath) {
        try {
            $raw = Get-Content $themePath -Raw -ErrorAction SilentlyContinue
            if ($raw -and $raw.Length -gt 100) { Write-OK "Tema OMP '$ThemeName' já existe."; return $true }
        } catch { Write-Warn "Erro ao verificar tema OMP: $($_.Exception.Message)" }
    }

    if (-not (Test-Path $OmpThemeDir)) { New-Item -ItemType Directory -Path $OmpThemeDir -Force | Out-Null }

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$ThemeName.omp.json"
        Invoke-WebRequest -Uri $themeUrl -OutFile $themePath -ErrorAction Stop
        $fileItem = Get-Item $themePath -ErrorAction SilentlyContinue
        if (-not $fileItem -or $fileItem.Length -lt 100) {
            Write-Warn "Download do tema parece corrompido."
            Remove-Item $themePath -Force -ErrorAction SilentlyContinue
            return $false
        }
        Write-OK "Tema OMP baixado: $themePath"
        return $true
    } catch {
        Write-Warn "Não foi possível baixar o tema OMP '$ThemeName': $($_.Exception.Message)"
        if (Test-Path $themePath) { Remove-Item $themePath -Force -ErrorAction SilentlyContinue }
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

function Install-TerminalWTColorScheme {
    param([string]$ThemeName)
    $data = Get-TerminalThemeDataLegacy -Name $ThemeName
    if (-not $data) { Write-Warn "Tema '$ThemeName' não encontrado."; return $false }

    $settingsPath = $WinTermPaths | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
    if (-not $settingsPath) { Write-Info "WT settings.json não encontrado."; return $false }

    try {
        $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $wt = $data.WT

        $scheme = [PSCustomObject]@{ name = $ThemeName; cursorColor = $wt.cursorColor
            foreground = $wt.foreground; background = $wt.background; selectionBackground = $wt.selectionBackground
            black = $wt.black; red = $wt.red; green = $wt.green; yellow = $wt.yellow
            blue = $wt.blue; purple = $wt.purple; cyan = $wt.cyan; white = $wt.white
            brightBlack = $wt.brightBlack; brightRed = $wt.brightRed; brightGreen = $wt.brightGreen
            brightYellow = $wt.brightYellow; brightBlue = $wt.brightBlue; brightPurple = $wt.brightPurple
            brightCyan = $wt.brightCyan; brightWhite = $wt.brightWhite }

        if (-not $settings.schemes) {
            $settings | Add-Member -Name 'schemes' -Value @($scheme) -MemberType NoteProperty -Force
        } else {
            $existing = $settings.schemes | Where-Object { $_.name -eq $ThemeName }
            if ($existing) {
                $idx = [array]::IndexOf($settings.schemes, $existing)
                $settings.schemes[$idx] = $scheme
            } else { $settings.schemes += $scheme }
        }
        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -Name 'defaults' -Value @{} -MemberType NoteProperty -Force
        }
        $settings.profiles.defaults | Add-Member -Name 'colorScheme' -Value $ThemeName -MemberType NoteProperty -Force
        $settings | ConvertTo-Json -Depth 15 | Set-Content $settingsPath -Encoding UTF8 -Force
        Write-OK "WT color scheme: $ThemeName"
        return $true
    } catch { Write-Warn "Falha ao configurar WT colorScheme: $($_.Exception.Message)"; return $false }
}

function Install-TerminalAlacrittyColorScheme {
    param([string]$ThemeName)
    $data = Get-TerminalThemeDataLegacy -Name $ThemeName
    if (-not $data) { Write-Warn "Tema '$ThemeName' não encontrado."; return $false }
    $colors = $data.Ala
    $colorLines = @(
        "[colors.primary]",
        "background = `"$($colors.primary.background)`"",
        "foreground = `"$($colors.primary.foreground)`"",
        "",
        "[colors.normal]",
        "black   = `"$($colors.normal.black)`"",
        "red     = `"$($colors.normal.red)`"",
        "green   = `"$($colors.normal.green)`"",
        "yellow  = `"$($colors.normal.yellow)`"",
        "blue    = `"$($colors.normal.blue)`"",
        "magenta = `"$($colors.normal.magenta)`"",
        "cyan    = `"$($colors.normal.cyan)`"",
        "white   = `"$($colors.normal.white)`"",
        "",
        "[colors.bright]",
        "black   = `"$($colors.bright.black)`"",
        "red     = `"$($colors.bright.red)`"",
        "green   = `"$($colors.bright.green)`"",
        "yellow  = `"$($colors.bright.yellow)`"",
        "blue    = `"$($colors.bright.blue)`"",
        "magenta = `"$($colors.bright.magenta)`"",
        "cyan    = `"$($colors.bright.cyan)`"",
        "white   = `"$($colors.bright.white)`""
    )
    $configPath = Join-Path $AlacrittyDir 'alacritty.toml'
    try {
        if (Test-Path $configPath) {
            $existing = Get-Content $configPath -Raw -Encoding UTF8
            $cs = $existing.IndexOf('[colors.primary]')
            if ($cs -ge 0) {
                $ce = $existing.IndexOf('[[', $cs + 1)
                if ($ce -lt 0) { $ce = $existing.IndexOf('[', $existing.IndexOf('[', 1) + 1) }
                if ($ce -lt 0) { $ce = $existing.Length }
                $newContent = $existing.Substring(0, $cs) + ($colorLines -join "`r`n") + "`r`n`r`n" + $existing.Substring($ce).TrimStart()
                Set-Content -Path $configPath -Value $newContent -Encoding UTF8 -Force
            } else {
                Add-Content -Path $configPath -Value ("`r`n`r`n" + ($colorLines -join "`r`n")) -Encoding UTF8
            }
        } else {
            if (-not (Test-Path $AlacrittyDir)) { New-Item -ItemType Directory -Force -Path $AlacrittyDir | Out-Null }
            Set-Content -Path $configPath -Value (($colorLines -join "`r`n") + "`r`n") -Encoding UTF8 -Force
        }
        Write-OK "Alacritty color scheme: $ThemeName"
        return $true
    } catch { Write-Warn "Alacritty colors falhou: $($_.Exception.Message)"; return $false }
}

function Install-TerminalThemeLegacy {
    param([string]$ThemeName)
    $any = $false
    if (Install-TerminalWTColorScheme -ThemeName $ThemeName) { $any = $true }
    if (Install-TerminalAlacrittyColorScheme -ThemeName $ThemeName) { $any = $true }
    return $any
}

function Install-LinkProfile {
    param([string]$ThemeName = '')

    $profilePath = if ($PROFILE -is [string] -and $PROFILE) { $PROFILE } else { $PROFILE.CurrentUserCurrentHost }
    $script:targetProfile = $profilePath
    $targetDir  = Split-Path $profilePath -Parent
    $source     = Join-Path $PermanentDir 'Microsoft.PowerShell_profile.ps1'

    if (-not (Test-Path $source)) { throw "Profile não encontrado no repositório: $source" }

    if (Test-Path $profilePath) {
        $c = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($c -match '\. "[^"]*Microsoft\.PowerShell_profile\.ps1"') {
            Write-OK "Profile já linkado corretamente."
            return $true
        }
        $bak = "$profilePath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path $bak) { $bak = "$profilePath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random)" }
        Copy-Item $profilePath $bak -Force
        Write-Info "Backup do profile: $bak"
        Remove-Item $profilePath -Force
    }

    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }

    try {
        $poshThemeLine = if ($ThemeName) { "`n`$env:POSH_THEME = `"$ThemeName`"" } else { '' }
        Set-Content -Path $profilePath -Value "# Generated by config-powershell7 installer`n`$env:__PROFILE_REPO_ROOT = `"$PermanentDir`"$poshThemeLine`n. `"$source`"" -Encoding UTF8 -Force
        Write-OK "Profile linkado: $profilePath"
        return $true
    } catch { throw "Falha ao linkar profile. $($_.Exception.Message)" }
}

# ═══════════════════════════════════════════════════════════════
# 3. ORQUESTRAÇÃO
# ═══════════════════════════════════════════════════════════════
Write-Host @"

  ╔══════════════════════════════════════════════╗
  ║   config-powershell7 - Instalador Universal  ║
  ╚══════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Força TLS 1.2 para PS 5.1
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

# Theme selection (non-interactive mode only, interactive does it earlier via irm | iex)
if (-not $NonInteractive -and -not $ThemeName) {
    $ompCheck = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if ($ompCheck) {
        Write-Host ""
        Write-Host "Selecione um tema Oh My Posh:" -ForegroundColor Cyan
        Write-Host "  1. jandedobbeleer (recomendado)" -ForegroundColor White
        Write-Host "  2. powerlevel10k_lean" -ForegroundColor White
        Write-Host "  3. powerlevel10k_modern" -ForegroundColor White
        Write-Host "  4. powerlevel10k_rainbow" -ForegroundColor White
        Write-Host "  5. atomic" -ForegroundColor White
        Write-Host "  6. Pulark (sem download de tema)" -ForegroundColor Gray
        Write-Host ""
        $themeChoice = Read-Host "Selecione um tema [1]"
        if ([string]::IsNullOrWhiteSpace($themeChoice)) { $themeChoice = '1' }
        $ThemeName = switch ($themeChoice) {
            '1' { 'jandedobbeleer' }
            '2' { 'powerlevel10k_lean' }
            '3' { 'powerlevel10k_modern' }
            '4' { 'powerlevel10k_rainbow' }
            '5' { 'atomic' }
            default { '' }
        }
        if ($ThemeName) {
            Write-Host "Tema selecionado: $ThemeName" -ForegroundColor Green
        } else {
            Write-Host "Pulando download de tema." -ForegroundColor Gray
        }
    }
}

# Alacritty prompt (only in interactive mode and when not explicitly set)
if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('InstallAlacritty')) {
    Write-Host ""
    $alacrittyChoice = Read-Host "Instalar Alacritty terminal? (s/N)"
    $script:OptInstallAlacritty = ($alacrittyChoice -eq 's' -or $alacrittyChoice -eq 'S')
} else {
    $script:OptInstallAlacritty = $InstallAlacritty.IsPresent
}

# Terminal color theme prompt (optional, interactive only)
if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('TerminalThemeName')) {
    Write-Host ""
    Write-Host "Terminal Color Theme (optional)" -ForegroundColor Cyan
    Write-Host "-------------------------------" -ForegroundColor Cyan
    $termChoice = Read-Host "Apply a terminal color theme to Windows Terminal + Alacritty? (y/n) [y]"
    if ([string]::IsNullOrWhiteSpace($termChoice) -or $termChoice -eq 'y') {
        $termThemes = Get-TerminalThemeListLegacy
        $idx = 0
        foreach ($tt in $termThemes) {
            $idx++
            Write-Host "  $idx. $($tt.Name) ($($tt.Type))" -ForegroundColor White
        }
        Write-Host "  $($idx+1). Skip" -ForegroundColor Gray
        Write-Host ""
        $themeChoice = Read-Host "Select terminal theme [1]"
        if ([string]::IsNullOrWhiteSpace($themeChoice)) { $themeChoice = '1' }
        if ([int]::TryParse($themeChoice, [ref]$null)) {
            $i = [int]$themeChoice - 1
            if ($i -ge 0 -and $i -lt $termThemes.Count) {
                $script:OptTerminalThemeName = $termThemes[$i].Name
                Write-Host "Selected terminal theme: $($script:OptTerminalThemeName)" -ForegroundColor Green
            }
        }
    }
}

$results = @()

function Add-LegacyResult {
    param([string]$Name, [bool]$Success, [string]$Detail, [string]$Status = '')
    if ($Status) {
        $finalStatus = $Status
    } elseif ($Success) {
        $finalStatus = 'ok'
    } else {
        $finalStatus = 'fail'
    }
    $script:results += @{
        Name   = $Name
        Status = $finalStatus
        Detail = $Detail
    }
}

# Passo 0: WinGet
$wingetPath = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetPath) {
    Write-Step "[0/9] Instalando WinGet..."
    try {
        $wingetPath = Install-Winget
        Add-LegacyResult -Name 'WinGet' -Success $true -Detail $wingetPath
    } catch {
        Add-LegacyResult -Name 'WinGet' -Success $false -Detail $_.Exception.Message
    }
} else {
    Write-OK "WinGet disponível: $($wingetPath.Source)"
    Add-LegacyResult -Name 'WinGet' -Success $true -Detail $wingetPath.Source
}

# Passo 1: PowerShell 7
$r = Install-WingetPackage -Id 'Microsoft.PowerShell' -Nome 'PowerShell 7' -CommandName 'pwsh'
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
$detail = if ($pwshCmd) { $pwshCmd.Source } else { 'not found' }
Add-LegacyResult -Name 'PowerShell 7' -Success $r -Detail $detail

# Passo 2: Git
$r = Install-WingetPackage -Id 'Git.Git' -Nome 'Git' -CommandName 'git'
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
$detail = if ($gitCmd) { $gitCmd.Source } else { 'not found' }
Add-LegacyResult -Name 'Git' -Success $r -Detail $detail

# Passo 3: Oh My Posh
$r = Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Nome 'Oh My Posh' -CommandName 'oh-my-posh'
$ompCmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
$detail = if ($ompCmd) { $ompCmd.Source } else { 'not found' }
Add-LegacyResult -Name 'Oh My Posh' -Success $r -Detail $detail

# Passo 4: Zoxide
$r = Install-WingetPackage -Id 'ajeetdsouza.zoxide' -Nome 'Zoxide' -CommandName 'zoxide'
$zoxCmd = Get-Command zoxide -ErrorAction SilentlyContinue
$detail = if ($zoxCmd) { $zoxCmd.Source } else { 'not found' }
Add-LegacyResult -Name 'Zoxide' -Success $r -Detail $detail

# Passo 5: Alacritty (opcional)
if ($script:OptInstallAlacritty) {
    $r = Install-WingetPackage -Id 'Alacritty.Alacritty' -Nome 'Alacritty' -CommandName 'alacritty'
    $alaCmd = Get-Command alacritty -ErrorAction SilentlyContinue
    $detail = if ($alaCmd) { $alaCmd.Source } else { 'not found' }
    Add-LegacyResult -Name 'Alacritty' -Success $r -Detail $detail
} else {
    Add-LegacyResult -Name 'Alacritty' -Success $true -Detail 'not selected' -Status 'skip'
}

$passosBase = @(
    @{ Nome = 'Baixar repositório';     Script = { Download-ComRepositorio } }
    @{ Nome = 'Instalar FiraCode Font'; Script = { Install-FonteNerd } }
    @{ Nome = 'Configurar WT';          Script = { Install-ConfigWindowsTerminal } }
    @{ Nome = 'Baixar tema OMP';        Script = { Install-TemaOhMyPosh -ThemeName $ThemeName } }
    @{ Nome = 'Linkar profile';         Script = { Install-LinkProfile -ThemeName $ThemeName } }
)

if ($script:OptTerminalThemeName) {
    $passosBase += @{ Nome = "Terminal color ($($script:OptTerminalThemeName))"; Script = { Install-TerminalThemeLegacy -ThemeName $script:OptTerminalThemeName } }
}

$passos = if ($script:OptInstallAlacritty) {
    $passosBase | ForEach-Object { $_ }
    @{ Nome = 'Configurar Alacritty';   Script = { Install-ConfigAlacritty } }
} else {
    $passosBase
}

for ($i = 0; $i -lt $passos.Count; $i++) {
    Write-Step "[$($i+7)/$($passos.Count+7)] $($passos[$i].Nome)"
    try {
        $r = & $passos[$i].Script
        $success = $null -ne $r -and $r -ne $false
        $detail = if ($r -is [string]) { $r } elseif ($success) { 'done' } else { 'failed' }
        Add-LegacyResult -Name $passos[$i].Nome -Success $success -Detail $detail
    } catch {
        Write-Fail "$($passos[$i].Nome) falhou: $($_.Exception.Message)"
        $erros++
        Add-LegacyResult -Name $passos[$i].Nome -Success $false -Detail $_.Exception.Message
    }
}

# ═══════════════════════════════════════════════════════════════
# 4. SUMÁRIO
# ═══════════════════════════════════════════════════════════════

$col1Width = 30
$col2Width = 8
$col3Width = 40

foreach ($r in $results) {
    $nLen = $r.Name.Length
    $dLen = $r.Detail.Length
    if ($nLen -gt $col1Width) { $col1Width = $nLen }
    if ($dLen -gt $col3Width) { $col3Width = $dLen }
}

$border = '┌' + ('─' * ($col1Width + 2)) + '┬' + ('─' * ($col2Width + 2)) + '┬' + ('─' * ($col3Width + 2)) + '┐'
$sep    = '├' + ('─' * ($col1Width + 2)) + '┼' + ('─' * ($col2Width + 2)) + '┼' + ('─' * ($col3Width + 2)) + '┤'
$footer = '└' + ('─' * ($col1Width + 2)) + '┴' + ('─' * ($col2Width + 2)) + '┴' + ('─' * ($col3Width + 2)) + '┘'
$rowFmt = '| {0,-' + $col1Width + '} | {1,' + $col2Width + '} | {2,-' + $col3Width + '} |'

Write-Host ''
if ($erros -eq 0) {
    Write-Host '  Installation completed successfully!' -ForegroundColor Green
} else {
    Write-Host "  Completed with $erros error(s)." -ForegroundColor Yellow
}
Write-Host ''
Write-Host $border -ForegroundColor Cyan
Write-Host ($rowFmt -f 'Component', 'Status', 'Detail') -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan

foreach ($r in $results) {
    $statusIcon = switch ($r.Status) {
        'ok'   { '[OK]' }
        'fail' { '[FAIL]' }
        'skip' { '[SKIP]' }
        default { '[???]' }
    }
    $color = switch ($r.Status) {
        'ok'   { 'Green' }
        'fail' { 'Red' }
        'skip' { 'Yellow' }
        default { 'Gray' }
    }
    $row = $rowFmt -f $r.Name, $statusIcon, $r.Detail
    Write-Host "  $row" -ForegroundColor $color
}

Write-Host $footer -ForegroundColor Cyan
Write-Host ''
Write-Host "  Repository: $PermanentDir" -ForegroundColor Cyan
Write-Host "  Profile:    $targetProfile" -ForegroundColor Cyan
Write-Host ''

$tools = @(
    @{ Name = 'PowerShell 7'; Cmd = 'pwsh' }
    @{ Name = 'Git'; Cmd = 'git' }
    @{ Name = 'Oh My Posh'; Cmd = 'oh-my-posh' }
    @{ Name = 'Zoxide'; Cmd = 'zoxide' }
)

$versions = @()
foreach ($t in $tools) {
    $cmd = Get-Command $t.Cmd -ErrorAction SilentlyContinue
    if ($cmd) {
        $ver = & $t.Cmd --version 2>$null
        $verStr = if ($ver) { " $($ver.Trim())" } else { '' }
        $versions += "$($t.Name)$verStr"
    }
}
if ($versions.Count -gt 0) {
    Write-Host "  $($versions -join ' | ')" -ForegroundColor Cyan
    Write-Host ''
}

Write-Host @"
  Restart your terminal to apply all changes.
"@ -ForegroundColor Cyan
