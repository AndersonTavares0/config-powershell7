#Requires -Version 5.1
# ============================================================
# POWERSHELL PROFILE — Otimizado para Boot 
# PS 5.1+ / PS Core 7+  |  Revisão: 2026-04
# ============================================================

# ── 1. ESTADO GLOBAL ─────────────────────────────────────────
$_bt     = [System.Diagnostics.Stopwatch]::StartNew()   # boot timer
$PSMajor = $PSVersionTable.PSVersion.Major               # cache; evita N acessos ao objeto
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ── 2. PLUGINS ────────────────────────────────────────────────
# Terminal-Icons custa ~100ms; carrega só quando chamado
function icons { Import-Module Terminal-Icons -ErrorAction SilentlyContinue; Write-Host "Terminal-Icons loaded" -ForegroundColor Green }

$_mods = [System.Collections.Generic.List[string]]::new()

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $theme = "$HOME\.poshthemes\atomic.omp.json"
    # FIX: if/else direto evita Split() frágil com caminhos que têm espaços
    if (Test-Path $theme) { oh-my-posh init pwsh --config $theme | Out-String | Invoke-Expression }
    else                  { oh-my-posh init pwsh                 | Out-String | Invoke-Expression }
    $_mods.Add('OMP')
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    zoxide init powershell | Out-String | Invoke-Expression
    $_mods.Add('Zoxide')
}

# ── 3. PSREADLINE ─────────────────────────────────────────────
# Get-Command verifica apenas o PATH; ~100ms mais rápido que Get-Module -ListAvailable
if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
    Set-PSReadLineOption -EditMode Windows -HistoryNoDuplicates -HistorySearchCursorMovesToEnd `
                         -BellStyle None -MaximumHistoryCount 5000
    # PredictionSource e ListView: exclusivos do PS 7+
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
function ~     { Set-Location $HOME }
function ..    { Set-Location .. }
function ...   { Set-Location ..\.. }
function la    { Get-ChildItem | Format-Table -AutoSize }
function ll    { Get-ChildItem -Force | Format-Table -AutoSize }

function mkcd([string]$Path) { New-Item -ItemType Directory -Force -Path $Path | Out-Null; Set-Location $Path }
function nf([string]$Name)   { New-Item -ItemType File -Path $Name -Force | Out-Null }

# ── 5. ARQUIVOS E TEXTO ───────────────────────────────────────
function touch([string]$File) {
    if (Test-Path $File) { (Get-Item $File).LastWriteTime = Get-Date }
    else                 { New-Item -ItemType File -Path $File -Force | Out-Null }
}
function which([string]$Cmd)  { (Get-Command $Cmd -ErrorAction SilentlyContinue).Source }
function unzip([string]$File, [string]$Dest = '.') { Expand-Archive -Path $File -DestinationPath $Dest -Force }
function head([string]$Path,  [int]$Lines = 10)    { Get-Content $Path -TotalCount $Lines }
function tail([string]$Path,  [int]$Lines = 10)    { Get-Content $Path -Tail $Lines }

# filter: processa cada objeto imediatamente sem acumular memória (correto para grep)
filter grep([string]$Pattern) { $_ | Select-String -Pattern $Pattern }

# FIX: era `filter clip` — chamava Set-Clipboard por item, sobrescrevendo o anterior.
# begin/process/end acumula o pipeline inteiro e grava UMA vez no final.
function clip {
    begin   { $buf = [System.Text.StringBuilder]::new() }
    process { [void]$buf.AppendLine($_) }
    end     {
        $buf.ToString().TrimEnd() | Set-Clipboard
        Write-Host "Copiado ($($buf.Length) chars)" -ForegroundColor Green
    }
}
Set-Alias cpy clip
function pst { Get-Clipboard }

# -Encoding UTF8 explícito: PS 5.1 usa Default (ANSI) e PS 7 usa UTF8-BOM por padrão
function sed([string]$File, [string]$Find, [string]$Replace) {
    (Get-Content $File -Raw -Encoding UTF8).Replace($Find, $Replace) |
        Set-Content $File -NoNewline -Encoding UTF8
}

# ── 6. SISTEMA ────────────────────────────────────────────────
function pkill([string]$Name) { Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force }
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

function pubip {
    # FIX: removido operador ?. (null-conditional) — exclusivo do PS 7+, quebra no 5.1
    $r = Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($r) { $r.Trim() }
}

function sysinfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    [PSCustomObject]@{
        Computer = $cs.Name;  User   = $env:USERNAME;  OS = $os.Caption
        PS       = $PSVersionTable.PSVersion.ToString()
        Uptime   = (Get-Date) - $os.LastBootUpTime
        RAM_GB   = [math]::Round($cs.TotalPhysicalMemory/1GB,1)
    }
}

# ── 7. GIT ────────────────────────────────────────────────────
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
function lazyg([string]$m){ git add .; git commit -m $m; git push }
Set-Alias gs gst

# ── 8. SUDO ───────────────────────────────────────────────────
function sudo {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Command)
    $exe = if ($PSMajor -ge 7) { 'pwsh' } else { 'powershell' }
    if ($Command) { Start-Process $exe -Verb RunAs -ArgumentList '-NoExit','-Command',($Command -join ' ') }
    else          { Start-Process $exe -Verb RunAs }
}

# ── 9. BOOT SUMMARY ───────────────────────────────────────────
$_bt.Stop()
$Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$(if ($IsAdmin){' [ADMIN]'})"

$_line = "PS $($PSVersionTable.PSVersion)"
if ($_mods.Count) { $_line += " | $($_mods -join ', ')" }
if ($IsAdmin)     { $_line += " | ADMIN" }

Write-Host $_line -ForegroundColor Cyan -NoNewline
Write-Host "  [$($_bt.Elapsed.TotalMilliseconds.ToString('0'))ms]" -ForegroundColor DarkGray
