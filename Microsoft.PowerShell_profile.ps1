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

# ── 2. PLUGINS & CACHE ───────────────────────────────────────
$script:CachePath  = "$HOME\.cache_pwsh_plugins.ps1"
$script:ThemePath  = "$HOME\.poshthemes\atomic.omp.json"

# Nomes em inglês + alias, convenção unificada
function Clear-PluginCache {
    Remove-Item $script:CachePath -ErrorAction SilentlyContinue
    Write-Host "Cache removido. Reinicie o terminal." -ForegroundColor Green
}
Set-Alias Clear-Cache Clear-PluginCache

# Verifica se já carregado antes de chamar Import-Module
function Import-TerminalIcons {
    if (Get-Module Terminal-Icons) {
        Write-Host "Terminal-Icons já está carregado." -ForegroundColor Yellow
        return
    }
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    if (Get-Module Terminal-Icons) { Write-Host "Terminal-Icons carregado." -ForegroundColor Green }
    else { Write-Warning "Terminal-Icons não encontrado. Execute: Install-Module Terminal-Icons" }
}
Set-Alias icons Import-TerminalIcons

# MD5 encapsulado em try/finally: garante Dispose() mesmo em falha.
# $script:ThemePath centralizado — um único ponto de referência para o tema.
function script:Get-PluginFingerprint {
    $parts = @(
        (Get-Command zoxide     -ErrorAction SilentlyContinue)?.Source
        (Get-Command oh-my-posh -ErrorAction SilentlyContinue)?.Source
        $script:ThemePath
        [int](Test-Path $script:ThemePath)
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($parts -join '|')
    $md5   = [System.Security.Cryptography.MD5]::Create()
    try    { [System.BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '' }
    finally{ $md5.Dispose() }
}

# Lógica de rebuild extraída: testável, nomeada, sem bloco `& {}` anônimo
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

# ── 3. PSREADLINE ─────────────────────────────────────────────
if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
    Set-PSReadLineOption -EditMode Windows `
        -HistoryNoDuplicates `
        -HistorySearchCursorMovesToEnd `
        -BellStyle None `
        -MaximumHistoryCount 5000

    if ($script:PSMajor -ge 7) {
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
    }

    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d'          -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w'          -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
}

# ── 4. NAVEGAÇÃO ──────────────────────────────────────────────
# Nomes descritivos sem underscore (convenção PS, não Python)
$script:DocsPath    = [Environment]::GetFolderPath('MyDocuments')
$script:DesktopPath = [Environment]::GetFolderPath('Desktop')

function docs { Set-Location $script:DocsPath    }
function dtop { Set-Location $script:DesktopPath }
function home { Set-Location $HOME               }
function up   { Set-Location ..                  }
function up2  { Set-Location ..\..               }
function la   { Get-ChildItem        | Format-Table -AutoSize }
function ll   { Get-ChildItem -Force | Format-Table -AutoSize }

# Parâmetro via param() formal — permite tab completion e -WhatIf futuro
function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    try {
        New-Item -ItemType Directory -Force -Path $Path -ErrorAction Stop | Out-Null
        Set-Location $Path
    } catch {
        Write-Error "mkcd: não foi possível criar '$Path' — $($_.Exception.Message)"
    }
}

function nf {
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Name)
    process { New-Item -ItemType File -Path $Name -Force | Out-Null }
}

# ── 5. ARQUIVOS E TEXTO ───────────────────────────────────────
function touch {
    param([Parameter(Mandatory, ValueFromPipeline)][string]$File)
    process {
        if (Test-Path $File) { (Get-Item $File).LastWriteTime = Get-Date }
        else                 { New-Item -ItemType File -Path $File -Force | Out-Null }
    }
}

function which {
    param([Parameter(Mandatory)][string]$Cmd)
    $result = (Get-Command $Cmd -ErrorAction SilentlyContinue).Source
    if ($result) { $result }
    else         { Write-Warning "'$Cmd' não encontrado no PATH." }
}

function unzip {
    param(
        [Parameter(Mandatory)][string]$File,
        [string]$Dest = '.'
    )
    try   { Expand-Archive -Path $File -DestinationPath $Dest -Force -ErrorAction Stop }
    catch { Write-Error "unzip: falha ao extrair '$File' — $($_.Exception.Message)" }
}

function head {
    param([Parameter(Mandatory)][string]$Path, [int]$Lines = 10)
    Get-Content $Path -TotalCount $Lines
}

function tail {
    param([Parameter(Mandatory)][string]$Path, [int]$Lines = 10)
    Get-Content $Path -Tail $Lines
}

filter grep {
    param([Parameter(Mandatory)][string]$Pattern)
    $_ | Select-String -Pattern $Pattern
}

# $InputObject declarado explicitamente: elimina dependência implícita de $_ fora de pipeline.
# Sem isso, chamar Copy-ToClipboard sem pipeline acumula $null silenciosamente.
function Copy-ToClipboard {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][string]$InputObject)
    begin   { $buf = [System.Text.StringBuilder]::new() }
    process { if ($null -ne $InputObject) { [void]$buf.AppendLine($InputObject) } }
    end {
        $text = $buf.ToString().TrimEnd()
        $text | Set-Clipboard
        Write-Verbose "Copiado: $($text.Length) caracteres."
    }
}
Set-Alias cpy Copy-ToClipboard

function pst { Get-Clipboard }

# Leitura e escrita via [System.IO.File]: encoding uniforme entre PS 5.1 e PS 7.
# Get-Content -Encoding UTF8 difere entre versões (BOM no 5.1, sem BOM no 7).
# .tmp no mesmo diretório do alvo → Move-Item = rename de SO = atômico em qualquer volume.
function sed {
    param(
        [Parameter(Mandatory, Position=0)][string]$File,
        [Parameter(Mandatory, Position=1)][string]$Find,
        [Parameter(Mandatory, Position=2)][string]$Replace,
        [switch]$Backup
    )

    if (-not (Test-Path $File)) {
        Write-Error "sed: arquivo '$File' não encontrado."
        return
    }

    $tmp = $null
    try {
        $resolved   = (Resolve-Path $File -ErrorAction Stop).Path
        # UTF8 com BOM para compatibilidade total com PowerShell 5.1 e ferramentas Windows
        $enc        = New-Object System.Text.UTF8Encoding $true
        $newContent = ([System.IO.File]::ReadAllText($resolved, $enc)).Replace($Find, $Replace)

        $tmp = [System.IO.Path]::Combine(
            [System.IO.Path]::GetDirectoryName($resolved),
            [System.IO.Path]::GetRandomFileName()
        )
        [System.IO.File]::WriteAllText($tmp, $newContent, $enc)

        if ($Backup) { Copy-Item $resolved "$resolved.bak" -Force }
        Move-Item $tmp $resolved -Force
        Write-Verbose "Modificado: $resolved$(if ($Backup) { " (backup: $resolved.bak)" })"
    } catch {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -ErrorAction SilentlyContinue }
        Write-Error "sed: falha em '$File' — $($_.Exception.Message)"
    }
}

# ── 6. SISTEMA ────────────────────────────────────────────────
function pkill {
    param([Parameter(Mandatory)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}
Set-Alias k9 pkill

function pgrep {
    param([Parameter(Mandatory)][string]$Name)
    # Usa Where-Object para filtro correto (wildcard não funciona em -Name do Get-Process)
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like "*$Name*" } |
        Format-Table Id, ProcessName, CPU,
            @{ L='Mem(MB)'; E={ [math]::Round($_.WorkingSet64/1MB, 1) } } -AutoSize
}

function flushdns {
    if ($script:IsAdmin) { Clear-DnsClientCache; Write-Host "Cache DNS limpo." -ForegroundColor Green }
    else                 { Write-Warning "flushdns requer privilégios de Administrador." }
}

function df {
    Get-Volume |
        Where-Object { $_.DriveLetter -and $_.Size -gt 0 } |
        Sort-Object DriveLetter |
        Format-Table DriveLetter, FileSystemLabel, FileSystem,
            @{ L='Size(GB)'; E={ [math]::Round($_.Size/1GB, 1) } },
            @{ L='Free(GB)'; E={ [math]::Round($_.SizeRemaining/1GB, 1) } },
            @{ L='Free%';    E={ [math]::Round(($_.SizeRemaining/$_.Size)*100, 0) } } -AutoSize
}

function pubip {
    param([switch]$Force)
    if ($script:CachedPublicIP -and -not $Force) {
        Write-Verbose "IP (cache): $script:CachedPublicIP"
        return $script:CachedPublicIP
    }
    $endpoints = 'https://api.ipify.org', 'https://icanhazip.com', 'https://ifconfig.me/ip'
    foreach ($url in $endpoints) {
        try {
            # Timeout reduzido e tratamento de exceções específicas para melhor resiliência
            $response = Invoke-RestMethod -Uri $url -TimeoutSec 3 `
                -ErrorAction Stop -UseBasicParsing
            if ($response) {
                $script:CachedPublicIP = $response.Trim()
                Write-Verbose "pubip: obtido de $url"
                return $script:CachedPublicIP
            }
        } catch [System.Net.WebException] {
            Write-Verbose "pubip: timeout ou falha de rede em $url"
        } catch {
            Write-Verbose "pubip: falha em $url — $_"
        }
    }
    Write-Warning "pubip: nenhum endpoint respondeu."
}

function sysinfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance Win32_ComputerSystem  -ErrorAction Stop
        [PSCustomObject]@{
            Computer = $cs.Name
            User     = $env:USERNAME
            OS       = $os.Caption
            PS       = $PSVersionTable.PSVersion.ToString()
            Uptime   = (Get-Date) - $os.LastBootUpTime
            RAM_GB   = [math]::Round($cs.TotalPhysicalMemory/1GB, 1)
        }
    } catch {
        # Fallback com try/catch aninhado: acesso ao registry também pode falhar
        $osName = try {
            (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).ProductName
        } catch { 'Windows (versão desconhecida)' }

        [PSCustomObject]@{
            Computer  = $env:COMPUTERNAME
            User      = $env:USERNAME
            OS        = $osName
            PS        = $PSVersionTable.PSVersion.ToString()
            Uptime    = 'N/A (CIM indisponível)'
            PS_Mem_MB = [math]::Round([Environment]::WorkingSet/1MB, 1)
        }
    }
}

# ── 7. GIT ────────────────────────────────────────────────────
if (Get-Command git -ErrorAction SilentlyContinue) {
    function gst { git status -sb }
    function ga  { git add . }

    # gcmt em vez de gcm: `gcm` é alias nativo do PS para Get-Command — colisão crítica
    function gcmt {
        param([Parameter(Mandatory)][string]$Message)
        git commit -m $Message
    }

    # gco com [Parameter(Mandatory)]: git checkout sem branch imprime usage em vez de erro claro
    function gco {
        param([Parameter(Mandatory)][string]$Branch)
        git checkout $Branch
    }

    function gpush { git push }
    function gpull { git pull }
    function glog  { git log --oneline --graph -15 }
    function gundo { git reset --soft HEAD~1 }
    function gdiff { git diff }

    function gcl {
        param([Parameter(Mandatory)][string]$URL)
        git clone $URL
    }

    # gcom verifica $LASTEXITCODE: falha em git add não deve chegar ao commit
    function gcom {
        param([Parameter(Mandatory)][string]$Message)
        git add .
        if ($LASTEXITCODE -ne 0) { Write-Error "gcom: git add falhou."; return }
        git commit -m $Message
    }

    # lazyg verifica cada passo: commit falho não dispara push
    # Compatível com Linux e Windows: usa ReadLine() em vez de ReadKey() para ambientes sem console interativo
    function lazyg {
        param(
            [Parameter(Mandatory)][string]$Message,
            [switch]$Force
        )
        git status --short
        $isInteractive = [Environment]::UserInteractive -and -not $env:CI -and -not $IsLinux -and -not $IsMacOS

        if (-not $Force -and $isInteractive) {
            Write-Host "Stage all, commit e push? [s/N]: " -NoNewline -ForegroundColor Yellow
            try {
                $input = [Console]::ReadLine()
                if ($input -notmatch '^[sS]$') {
                    Write-Host "Abortado." -ForegroundColor Red
                    return
                }
            } catch {
                Write-Verbose "lazyg: erro ao ler entrada do usuário — $_"
                Write-Host "Abortado (erro de leitura)." -ForegroundColor Red
                return
            }
        } elseif (-not $Force -and ($IsLinux -or $IsMacOS)) {
            # Em Linux/Mac, ReadKey pode falhar; pula confirmação interativa
            Write-Verbose "lazyg: modo não-interativo detectado (Linux/Mac ou CI)"
        }

        git add .
        if ($LASTEXITCODE -ne 0) { Write-Error "lazyg: git add falhou.";    return }
        git commit -m $Message
        if ($LASTEXITCODE -ne 0) { Write-Error "lazyg: git commit falhou."; return }
        git push
    }

    # gss em vez de gs: `gs` pode colidir com Get-Service em alguns ambientes PS 5.1
    Set-Alias gss gst
} else {
    Write-Verbose "Git não encontrado — aliases Git não carregados."
}

# ── 8. SUDO ───────────────────────────────────────────────────
function sudo {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Command)

    if ($Command.Count -eq 1 -and $Command[0] -eq '!!') {
        $last = (Get-History -Count 1).CommandLine
        if ($last) { $Command = @($last) }
        else       { Write-Host "Nenhum comando no histórico." -ForegroundColor Yellow; return }
    }

    $exe = if ($script:PSMajor -ge 7) { 'pwsh' } else { 'powershell' }

    if ($Command) {
        # -EncodedCommand preserva aspas e caracteres especiais.
        # -Command com string concatenada perde delimitadores em caminhos com espaços.
        $encoded = [Convert]::ToBase64String(
            [System.Text.Encoding]::Unicode.GetBytes($Command -join ' ')
        )
        Start-Process $exe -Verb RunAs -ArgumentList '-NoExit', '-EncodedCommand', $encoded
    } else {
        Start-Process $exe -Verb RunAs
    }
}

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
