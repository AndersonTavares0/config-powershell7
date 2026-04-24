#Requires -Version 5.1
# ============================================
# POWERSHELL PROFILE 
# ============================================
# Compatível: PowerShell 5.1+ e PowerShell Core 7+
# Última vez que mexi: 2026-03
# ============================================

# ============================================
# ESTADO GLOBAL E PERMISSÕES
# ============================================

$script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

# ============================================
# INICIALIZAÇÃO - TERMINAL ICONS
# ============================================

$script:IconsLoaded = $false
function Enable-TerminalIcons {
    if (-not $script:IconsLoaded) {
        if (Get-Module -ListAvailable -Name Terminal-Icons) {
            Import-Module Terminal-Icons -ErrorAction Stop
            $script:IconsLoaded = $true
            Write-Host "Terminal-Icons loaded" -ForegroundColor Green
        } else {
            Write-Warning "Terminal-Icons module not installed"
        }
    }
}
Set-Alias -Name icons -Value Enable-TerminalIcons

# ============================================
# INICIALIZAÇÃO - OH MY POSH E ZOXIDE
# ============================================

function Initialize-OhMyPosh {
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) { return $false }

    # Refatoração: Uso de array seguro filtrado e validação imediata.
    $themePaths = @(
        if ($env:POSH_THEMES_PATH) { Join-Path $env:POSH_THEMES_PATH "atomic.omp.json" }
        if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\themes\atomic.omp.json" }
        Join-Path $HOME ".poshthemes\atomic.omp.json"
    ) | Where-Object { $null -ne $_ -and [System.IO.File]::Exists($_) }
    
    $selectedTheme = if ($themePaths.Count -gt 0) { $themePaths[0] } else { $null }
    
    try {
        if ($selectedTheme) {
            Invoke-Expression (& oh-my-posh init pwsh --config "$selectedTheme" | Out-String)
        } else {
            Invoke-Expression (& oh-my-posh init pwsh | Out-String)
        }
        return $true
    } catch {
        Write-Error "Failed to initialize Oh My Posh: $_"
        return $false
    }
}

function Initialize-Zoxide {
    if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) { return $false }
    try {
        Invoke-Expression (& zoxide init powershell | Out-String)
        return $true
    } catch {
        Write-Error "Zoxide initialization failed: $_"
        return $false
    }
}

$script:OmpInitialized = Initialize-OhMyPosh
$script:ZoxideInitialized = Initialize-Zoxide

# ============================================
# PSREADLINE
# ============================================

if (Get-Module -ListAvailable -Name PSReadLine) {
    $PSReadLineParams = @{
        EditMode                      = 'Windows'
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        BellStyle                     = 'None'
        MaximumHistoryCount           = 5000
    }
    
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $PSReadLineParams['PredictionSource'] = 'History'
        $PSReadLineParams['PredictionViewStyle'] = 'ListView'
    }
    
    Set-PSReadLineOption @PSReadLineParams

    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
}

# ============================================
# NAVEGAÇÃO
# ============================================

$script:PathDocs = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
if ([string]::IsNullOrWhiteSpace($script:PathDocs)) { 
    $script:PathDocs = Join-Path $HOME "Documents" 
}

$script:PathDesktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
if ([string]::IsNullOrWhiteSpace($script:PathDesktop)) { 
    $script:PathDesktop = Join-Path $HOME "Desktop" 
}

function docs  { Set-Location -Path $script:PathDocs }
function dtop  { Set-Location -Path $script:PathDesktop }
function la    { Get-ChildItem | Format-Table -AutoSize }
function ll    { Get-ChildItem -Force | Format-Table -AutoSize }
function cdup  { Set-Location -Path .. }
function cdup2 { Set-Location -Path ..\.. }
function cdhome { Set-Location -Path $HOME }

Set-Alias -Name '..' -Value cdup
Set-Alias -Name '...' -Value cdup2
Set-Alias -Name '~' -Value cdhome

function mkcd {
    param([Parameter(Mandatory, Position = 0)][string]$Path)
    $null = New-Item -ItemType Directory -Force -Path $Path -ErrorAction Stop
    Set-Location -Path $Path
}

function nf {
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    $null = New-Item -ItemType File -Path $Name -Force
}

# ============================================
# ARQUIVOS E MANIPULAÇÃO DE TEXTO
# ============================================

function unzip {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$File,
        [Parameter(Position = 1)]
        [string]$Destination = "."
    )
    $resolvedPath = (Resolve-Path $File).Path
    Expand-Archive -Path $resolvedPath -DestinationPath $Destination -Force
}

function touch {
    param([Parameter(Mandatory, Position = 0)][string]$File)
    if (Test-Path $File) { (Get-Item $File).LastWriteTime = Get-Date } 
    else { $null = New-Item -ItemType File -Path $File -Force }
}

function which {
    param([Parameter(Mandatory, Position = 0)][string]$Command)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) { Write-Output $cmd.Source } 
    else { Write-Warning "Command '$Command' not found" }
}

function grep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Pattern,
        
        [Parameter(Position = 1, ValueFromPipeline)]
        [object[]]$InputObject
    )
    begin { $collectedInput = [System.Collections.Generic.List[object]]::new() }
    process {
        if ($InputObject) {
            foreach ($item in $InputObject) { $collectedInput.Add($item) }
        }
    }
    end {
        if ($collectedInput.Count -eq 0) {
            Write-Warning "No input provided"
            return
        }
        foreach ($item in $collectedInput) {
            $itemStr = $item.ToString()
            # Refatoração de segurança e escopo
            if (Test-Path $itemStr -PathType Leaf -ErrorAction SilentlyContinue) {
                Select-String -Path $itemStr -Pattern $Pattern
            } elseif (Test-Path $itemStr -PathType Container -ErrorAction SilentlyContinue) {
                Get-ChildItem $itemStr -File -Recurse | Select-String -Pattern $Pattern
            } else {
                $itemStr | Select-String -Pattern $Pattern
            }
        }
    }
}

function sed {
    param(
        [Parameter(Mandatory, Position = 0)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$File,
        [Parameter(Mandatory, Position = 1)][string]$Find,
        [Parameter(Mandatory, Position = 2)][string]$Replace
    )
    $content = Get-Content $File -Raw -ErrorAction Stop
    $newContent = $content.Replace($Find, $Replace)
    $newContent | Set-Content $File -NoNewline
}

function head {
    param(
        [Parameter(Mandatory, Position = 0)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$Path,
        [Parameter(Position = 1)][int]$Lines = 10
    )
    Get-Content $Path -TotalCount $Lines -ErrorAction Stop
}

function tail {
    param(
        [Parameter(Mandatory, Position = 0)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$Path,
        [Parameter(Position = 1)][int]$Lines = 10,
        [Alias("f")][switch]$Follow
    )
    Get-Content $Path -Tail $Lines -Wait:$Follow -ErrorAction Stop
}

# ============================================
# SISTEMA
# ============================================

function pkill {
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    $procs = Get-Process -Name $Name -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force
        Write-Host "Killed $($procs.Count) process(es)" -ForegroundColor Green
    } else { Write-Warning "No process found with name '$Name'" }
}
Set-Alias -Name k9 -Value pkill

function pgrep {
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    Get-Process -Name "*$Name*" -ErrorAction SilentlyContinue | 
        Format-Table Id, ProcessName, CPU, @{L='Mem(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize
}

function clip {
    [CmdletBinding()]
    param([Parameter(Position = 0, ValueFromPipeline)][object[]]$InputObject)
    begin { $collected = [System.Collections.Generic.List[object]]::new() }
    process { 
        if ($InputObject) { 
            foreach ($item in $InputObject) { $collected.Add($item) }
        }
    }
    end {
        if ($collected.Count -gt 0) {
            $collected | Set-Clipboard
            Write-Host "Copied $($collected.Count) item(s) to clipboard" -ForegroundColor Green
        } else { Write-Warning "Nothing to copy" }
    }
}
Set-Alias -Name cpy -Value clip
function pst { Get-Clipboard }

function flushdns {
    if (-not $script:IsAdmin) {
        Write-Warning "Administrator privileges required."
        return
    }
    Clear-DnsClientCache -ErrorAction Stop
    Write-Host "DNS cache cleared" -ForegroundColor Green
}

function df {
    Get-Volume | 
        Where-Object { $_.DriveLetter -and $_.Size -gt 0 } |
        Sort-Object DriveLetter |
        Format-Table DriveLetter, FileSystemLabel, FileSystem,
                     @{L='Size(GB)';E={[math]::Round($_.Size/1GB,1)}}, 
                     @{L='Free(GB)';E={[math]::Round($_.SizeRemaining/1GB,1)}},
                     @{L='Free%';E={[math]::Round(($_.SizeRemaining/$_.Size)*100,0)}} -AutoSize
}

function pubip {
    # Refatoração Sênior: Fallback de APIs para evitar Single Point of Failure
    $endpoints = @(
        "https://api.ipify.org",
        "https://icanhazip.com",
        "https://ifconfig.me/ip"
    )
    
    foreach ($uri in $endpoints) {
        try {
            $ip = (Invoke-RestMethod -Uri $uri -TimeoutSec 3 -ErrorAction Stop).Trim()
            if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
                Write-Output $ip
                return
            }
        } catch {
            continue # Tenta o próximo endpoint em caso de falha de DNS ou timeout
        }
    }
    Write-Error "Failed to retrieve public IP from all endpoints."
}

function sysinfo {
    [CmdletBinding()]
    param([switch]$Full)
    
    if ($Full) { Get-ComputerInfo; return }
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        
        return [PSCustomObject]@{
            ComputerName = $cs.Name
            UserName     = $env:USERNAME
            OS           = $os.Caption
            PSVersion    = $PSVersionTable.PSVersion.ToString()
            Uptime       = (Get-Date) - $os.LastBootUpTime
            TotalRAM_GB  = [math]::Round($cs.TotalPhysicalMemory/1GB, 1)
        }
    } catch { Write-Error "Failed to retrieve system info: $_" }
}

# ============================================
# GIT
# ============================================

$script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

function Test-GitRepo {
    if (-not $script:GitAvailable) {
        Write-Warning "git is not installed or not in PATH"
        return $false
    }
    $isInside = git rev-parse --is-inside-work-tree 2>$null
    if ($isInside -ne "true") {
        Write-Warning "Not inside a git repository"
        return $false
    }
    return $true
}

function gst   { if (Test-GitRepo) { git status -sb } }
function ga    { if (Test-GitRepo) { git add . } }
function gco   { param($m) if (Test-GitRepo) { git commit -m "$m" } }
function gpush { if (Test-GitRepo) { git push } }
function gpull { if (Test-GitRepo) { git pull } }
function glog  { if (Test-GitRepo) { git log --oneline --graph -15 } }
function gundo { if (Test-GitRepo) { git reset --soft HEAD~1 } }
function gdiff { if (Test-GitRepo) { git diff } }

function gcl {
    param([Parameter(Mandatory, Position = 0)][string]$Repo)
    if ($script:GitAvailable) { git clone $Repo } else { Write-Warning "git is not installed" }
}

function gcom {
    param([Parameter(Mandatory, Position = 0)][string]$Message)
    if (Test-GitRepo) { git add .; git commit -m "$Message" }
}

function lazyg {
    param([Parameter(Mandatory, Position = 0)][string]$Message)
    if (Test-GitRepo) { git add .; git commit -m "$Message"; git push }
}
Set-Alias -Name gs -Value gst

# ============================================
# ADMIN
# ============================================

function Invoke-Admin {
    param([Parameter(Position = 0, ValueFromRemainingArguments)][string[]]$Command)
    
    $isCore = $null -ne (Get-Command pwsh -ErrorAction SilentlyContinue)
    $exe = if ($isCore) { 'pwsh' } else { 'powershell' }
    
    if ($Command -and $Command.Count -gt 0) {
        $cmdString = $Command -join ' '
        Start-Process $exe -Verb RunAs -ArgumentList "-NoExit -Command $cmdString"
    } else {
        Start-Process $exe -Verb RunAs
    }
}
Set-Alias -Name sudo -Value Invoke-Admin
Set-Alias -Name admin -Value Invoke-Admin

# ============================================
# TÍTULO E FEEDBACK
# ============================================

$script:AdminSuffix = if ($script:IsAdmin) { ' [ADMIN]' } else { '' }
$Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$script:AdminSuffix"

# Refatoração Sênior: Uso de genéricos para inicialização limpa e alta performance
$initStatus = [System.Collections.Generic.List[string]]::new()
if ($script:OmpInitialized)    { $initStatus.Add("OMP") }
if ($script:ZoxideInitialized) { $initStatus.Add("Zoxide") }

Write-Host "Profile loaded" -ForegroundColor DarkGray -NoNewline
Write-Host " | " -ForegroundColor DarkGray -NoNewline
Write-Host "PS $($PSVersionTable.PSVersion)" -ForegroundColor Cyan -NoNewline

if ($initStatus.Count -gt 0) {
    Write-Host " | " -ForegroundColor DarkGray -NoNewline
    Write-Host ($initStatus -join ", ") -ForegroundColor DarkGreen -NoNewline
}

if ($script:IsAdmin) {
    Write-Host " | " -ForegroundColor DarkGray -NoNewline
    Write-Host "ADMIN" -ForegroundColor Red
} else {
    Write-Host ""
}