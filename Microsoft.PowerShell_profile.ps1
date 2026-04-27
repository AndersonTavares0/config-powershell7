#Requires -Version 5.1
# ============================================================
# POWERSHELL PROFILE 
# PS 5.1+ / PS Core 7+  |  Revisão: 2026-04
# ============================================================

# ── 1. ESTADO GLOBAL ─────────────────────────────────────────
# $script: torna o escopo explícito e evita colisão com variáveis do usuário
$script:BootTimer      = [System.Diagnostics.Stopwatch]::StartNew()
$script:StartupModules = [System.Collections.Generic.List[string]]::new()
$script:CachedPublicIP = $null   # cache de sessão para pubip (evita nova requisição de rede)

$PSMajor = $PSVersionTable.PSVersion.Major   # cache; PSVersionTable é um objeto pesado de acessar N vezes
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ── HELPER PRIVADO ────────────────────────────────────────────
# Abstrai o padrão `... | Out-String | Invoke-Expression` com error handling e registro de módulo.
# GetNewClosure() é chamado pelo CALLER para capturar variáveis do escopo externo no scriptblock.
function _InitPlugin([string]$Label, [scriptblock]$Init) {
    try {
        (& $Init) | Out-String | Invoke-Expression
        $script:StartupModules.Add($Label)
    } catch {
        Write-Warning "Plugin '$Label': falha na inicialização — $_"
    }
}

# ── 2. PLUGINS ────────────────────────────────────────────────
$script:CachePath = "$HOME\.cache_pwsh_plugins.ps1"

function icons { Import-Module Terminal-Icons -ErrorAction SilentlyContinue; Write-Host "Terminal-Icons carregado" -ForegroundColor Green }
function Limpar-Cache { Remove-Item $script:CachePath -ErrorAction SilentlyContinue; Write-Host "Cache limpo. Reinicie o terminal." -ForegroundColor Green }
Set-Alias Clear-Cache Limpar-Cache

if (-not (Test-Path $script:CachePath)) {
    Write-Host "Criando cache de plugins pela primeira vez..." -ForegroundColor DarkGray
    & {
        $buf = [System.Text.StringBuilder]::new()
        
        if (Get-Command zoxide -ErrorAction SilentlyContinue) {
            [void]$buf.AppendLine((zoxide init powershell | Out-String))
            [void]$buf.AppendLine("`$script:StartupModules.Add('Zoxide')")
        }
        
        if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
            $thm = "$HOME\.poshthemes\atomic.omp.json"
            $lbl = if (Test-Path $thm) { 'OMP:atomic' } else { 'OMP:default' }
            
            if (Test-Path $thm) { [void]$buf.AppendLine((oh-my-posh init pwsh --config $thm | Out-String)) }
            else                { [void]$buf.AppendLine((oh-my-posh init pwsh | Out-String)) }
            
            [void]$buf.AppendLine("`$script:StartupModules.Add('$lbl')")
        }
        
        try   { Set-Content -Path $script:CachePath -Value $buf.ToString() -Encoding UTF8 -ErrorAction Stop }
        catch { Write-Warning "Falha ao salvar cache: $_" }
    }
}

if (Test-Path $script:CachePath) { . $script:CachePath }

# ── 3. PSREADLINE ─────────────────────────────────────────────
# Get-Command: verifica apenas o PATH resolvido (~100ms mais rápido que Get-Module -ListAvailable)
if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
    Set-PSReadLineOption -EditMode Windows -HistoryNoDuplicates -HistorySearchCursorMovesToEnd `
                         -BellStyle None -MaximumHistoryCount 5000
    if ($PSMajor -ge 7) {
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
    }
    Set-PSReadLineKeyHandler -Key UpArrow             -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow           -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab                 -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d'          -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w'          -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
}

# ── 4. NAVEGAÇÃO ──────────────────────────────────────────────
$_docs    = [Environment]::GetFolderPath('MyDocuments')
$_desktop = [Environment]::GetFolderPath('Desktop')

function docs  { Set-Location $_docs }
function dtop  { Set-Location $_desktop }
function home  { Set-Location $HOME }   # `~` foi renomeado: shadoweava operador nativo do PS
function up    { Set-Location .. }      # `..` foi renomeado: shadoweava separador de caminho
function up2   { Set-Location ..\.. }
function la    { Get-ChildItem | Format-Table -AutoSize }
function ll    { Get-ChildItem -Force | Format-Table -AutoSize }

function mkcd([string]$Path) {
    try {
        New-Item -ItemType Directory -Force -Path $Path -ErrorAction Stop | Out-Null
        Set-Location $Path
    } catch {
        Write-Host "mkcd: não foi possível criar '$Path' — $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ValueFromPipeline: permite `"dir1","dir2" | nf` além do uso normal
function nf {
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Name)
    process { New-Item -ItemType File -Path $Name -Force | Out-Null }
}

# ── 5. ARQUIVOS E TEXTO ───────────────────────────────────────
# ValueFromPipeline: permite `"a.txt","b.txt" | touch`
function touch {
    param([Parameter(Mandatory, ValueFromPipeline)][string]$File)
    process {
        if (Test-Path $File) { (Get-Item $File).LastWriteTime = Get-Date }
        else                 { New-Item -ItemType File -Path $File -Force | Out-Null }
    }
}

function which([string]$Cmd) {
    $r = (Get-Command $Cmd -ErrorAction SilentlyContinue).Source
    if ($r) { $r } else { Write-Host "$Cmd : not found" -ForegroundColor Yellow }
}

function unzip([string]$File, [string]$Dest = '.') {
    try {
        Expand-Archive -Path $File -DestinationPath $Dest -Force -ErrorAction Stop
    } catch {
        Write-Host "unzip: falha ao extrair '$File' — $($_.Exception.Message)" -ForegroundColor Red
    }
}

function head([string]$Path, [int]$Lines = 10) { Get-Content $Path -TotalCount $Lines }
function tail([string]$Path, [int]$Lines = 10) { Get-Content $Path -Tail $Lines }

# filter: streaming real — processa cada objeto imediatamente sem alocar coleção em memória
filter grep([string]$Pattern) { $_ | Select-String -Pattern $Pattern }

# clip: begin/process/end acumula o pipeline inteiro e chama Set-Clipboard UMA vez.
# (filter chamaria Set-Clipboard por item, sobrescrevendo o anterior a cada linha)
# Write-Verbose: silencioso por padrão — use `... | clip -Verbose` para ver o feedback
function clip {
    [CmdletBinding()]
    param()
    begin   { $buf = [System.Text.StringBuilder]::new() }
    process { [void]$buf.AppendLine($_) }
    end     {
        $text = $buf.ToString().TrimEnd()
        $text | Set-Clipboard
        Write-Verbose "Copiado ($($text.Length) chars)"
    }
}
Set-Alias cpy clip
function pst { Get-Clipboard }

# sed: escrita atômica via arquivo temporário.
# Fluxo: lê → processa → grava no .tmp → Move-Item substitui o original atomicamente.
# Se qualquer etapa falhar, o .tmp é removido e o original fica intacto.
# Parâmetro -Backup: cria cópia .bak antes da substituição (opcional, off por padrão).
function sed {
    param(
        [Parameter(Mandatory, Position=0)][string]$File,
        [Parameter(Mandatory, Position=1)][string]$Find,
        [Parameter(Mandatory, Position=2)][string]$Replace,
        [switch]$Backup
    )
    # Validar se o arquivo existe
    if (-not (Test-Path $File)) {
        Write-Host "sed: arquivo '$File' não encontrado" -ForegroundColor Red
        return
    }
    $tmp = $null
    try {
        $resolved   = (Resolve-Path $File -ErrorAction Stop).Path
        $newContent = (Get-Content $resolved -Raw -Encoding UTF8).Replace($Find, $Replace)

        $tmp = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tmp, $newContent, [System.Text.Encoding]::UTF8)

        if ($Backup) { Copy-Item $resolved "$resolved.bak" -Force }
        Move-Item $tmp $resolved -Force   # substituição atômica no mesmo volume

        Write-Verbose "Modificado: $resolved$(if ($Backup) { " (backup: $resolved.bak)" })"
    } catch {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -ErrorAction SilentlyContinue }
        Write-Host "sed: falha em '$File' — $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ── 6. SISTEMA ────────────────────────────────────────────────
function pkill([string]$Name) {
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}
Set-Alias k9 pkill

function pgrep([string]$Name) {
    Get-Process -Name "*$Name*" -ErrorAction SilentlyContinue |
        Format-Table Id, ProcessName, CPU,
            @{ L='Mem(MB)'; E={ [math]::Round($_.WorkingSet64/1MB,1) } } -AutoSize
}

function flushdns {
    if ($IsAdmin) { Clear-DnsClientCache; Write-Host "DNS Limpo" -ForegroundColor Green }
    else          { Write-Warning "Requer privilégios de Administrador" }
}

function df {
    Get-Volume | Where-Object { $_.DriveLetter -and $_.Size -gt 0 } | Sort-Object DriveLetter |
        Format-Table DriveLetter, FileSystemLabel, FileSystem,
            @{ L='Size(GB)'; E={ [math]::Round($_.Size/1GB,1) } },
            @{ L='Free(GB)'; E={ [math]::Round($_.SizeRemaining/1GB,1) } },
            @{ L='Free%';    E={ [math]::Round(($_.SizeRemaining/$_.Size)*100,0) } } -AutoSize
}

# Cache de sessão: após a primeira chamada bem-sucedida, retorna o valor armazenado
# sem nova requisição de rede. `pubip -Force` ignora o cache e busca novamente.
function pubip {
    param([switch]$Force)
    if ($script:CachedPublicIP -and -not $Force) {
        Write-Verbose "IP (cache de sessão): $script:CachedPublicIP"
        return $script:CachedPublicIP
    }
    
    $services = @('https://api.ipify.org', 'https://icanhazip.com', 'https://ifconfig.me/ip')
    foreach ($url in $services) {
        try {
            $r = Invoke-RestMethod $url -TimeoutSec 5 -ErrorAction Stop
            if ($r) {
                $script:CachedPublicIP = $r.Trim()
                return $script:CachedPublicIP
            }
        } catch {
            Write-Verbose "Falha ao obter IP de $url : $_"
        }
    }
    Write-Warning "Não foi possível obter o IP público (todos os serviços falharam)"
}

function sysinfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        [PSCustomObject]@{
            Computer = $cs.Name
            User     = $env:USERNAME
            OS       = $os.Caption
            PS       = $PSVersionTable.PSVersion.ToString()
            Uptime   = (Get-Date) - $os.LastBootUpTime
            RAM_GB   = [math]::Round($cs.TotalPhysicalMemory/1GB, 1)
        }
    } catch {
        # Fallback simplificado para ambientes com CIM bloqueado
        [PSCustomObject]@{
            Computer = $env:COMPUTERNAME
            User     = $env:USERNAME
            OS       = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName
            PS       = $PSVersionTable.PSVersion.ToString()
            Uptime   = "N/A (CIM indisponível)"
            RAM_GB   = [math]::Round([Environment]::WorkingSet/1GB, 1)
        }
    }
}

# ── 7. GIT ────────────────────────────────────────────────────
# Verifica se o Git está instalado antes de carregar as funções
if (Get-Command git -ErrorAction SilentlyContinue) {
    function gst              { git status -sb }
    function ga               { git add . }
    function gco([string]$m)  { git commit -m $m }
    function gpush            { git push }
    function gpull            { git pull }
    function glog             { git log --oneline --graph -15 }
    function gundo            { git reset --soft HEAD~1 }
    function gdiff            { git diff }
    function gcl([string]$URL){ git clone $URL }
    function gcom([string]$m) { git add .; git commit -m $m }

    # lazyg: o mais destrutivo (stage + commit + push em cadeia) — pede confirmação por padrão.
    # Use -Force para bypass em contextos não-interativos ou quando já visualizou o status.
    function lazyg {
        param([Parameter(Mandatory)][string]$m, [switch]$Force)
        git status --short
        
        # Detecta se está em ambiente interativo
        $isInteractive = [Environment]::UserInteractive -and -not $env:CI
        if (-not $Force -and $isInteractive) {
            Write-Host "Stage all, commit e push? [s/N]: " -NoNewline -ForegroundColor Yellow
            $key = [Console]::ReadKey($true)
            Write-Host $key.KeyChar
            if ($key.KeyChar -notmatch '^[sS]$') { Write-Host "Abortado." -ForegroundColor Red; return }
        }
        git add .; git commit -m $m; git push
    }
    Set-Alias gs gst
} else {
    Write-Verbose "Git não encontrado — aliases Git não carregados"
}

# ── 8. SUDO ───────────────────────────────────────────────────
function sudo {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Command)
    
    # Suporte a `sudo !!` (último comando do histórico)
    if ($Command -eq '!!') {
        $last = (Get-History -Count 1).CommandLine
        if ($last) {
            $Command = @($last)
        } else {
            Write-Host "Nenhum comando no histórico" -ForegroundColor Yellow
            return
        }
    }
    
    $exe = if ($PSMajor -ge 7) { 'pwsh' } else { 'powershell' }
    if ($Command) { Start-Process $exe -Verb RunAs -ArgumentList '-NoExit','-Command',($Command -join ' ') }
    else          { Start-Process $exe -Verb RunAs }
}

# ── 9. BOOT SUMMARY ───────────────────────────────────────────
$script:BootTimer.Stop()
$Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$(if ($IsAdmin) { ' [ADMIN]' })"

$_ms      = [math]::Round($script:BootTimer.Elapsed.TotalMilliseconds, 0)
$_color   = if ($_ms -lt 200) { 'Green' } elseif ($_ms -lt 400) { 'Yellow' } else { 'Red' }
$_plugins = if ($script:StartupModules.Count) { " · $($script:StartupModules -join ', ')" } else { '' }
$_admin   = if ($IsAdmin) { ' · ADMIN' } else { '' }
$_icns    = if (Get-Module Terminal-Icons -ErrorAction SilentlyContinue) { ' · Ícones: ON' } else { ' · Ícones: OFF (use `icons`)' }

Write-Host "PS $($PSVersionTable.PSVersion)$_plugins$_admin" -ForegroundColor Cyan -NoNewline
Write-Host "  [${_ms}ms]" -ForegroundColor $_color
