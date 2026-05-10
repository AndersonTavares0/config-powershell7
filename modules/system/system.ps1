using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 6. SISTEMA ────────────────────────────────────────────────
# Todas as funções consomem $script:Config (módulo centralizado).
# Detecção de plataforma NÃO é duplicada aqui.

# Cross-platform pkill: usa Get-Process (Windows) ou comando nativo (Linux/macOS)
function pkill {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Name)
    try {
        if ($script:Config.IsLinux -or $script:Config.IsMacOS) {
            # Fallback para comando nativo em Unix-like
            $nativePkill = Get-Command '/usr/bin/pkill' -ErrorAction SilentlyContinue
            if ($nativePkill) {
                if ($PSCmdlet.ShouldProcess($Name, 'Kill process (native pkill)')) {
                    & '/usr/bin/pkill' -f $Name 2>&1 | Out-Null
                }
                return
            }
        }
        # Windows/PowerShell native
        $procs = Get-Process -Name $Name -ErrorAction SilentlyContinue
        if ($procs -and $PSCmdlet.ShouldProcess($Name, 'Stop-Process -Force')) {
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    } catch {
        $er = [ErrorRecord]::new(
            $_.Exception, 'PkillFailed', [ErrorCategory]::InvalidOperation, $Name
        )
        $PSCmdlet.WriteError($er)
    }
}
Set-Alias k9 pkill

# Cross-platform pgrep
function pgrep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    try {
        if ($script:Config.IsLinux -or $script:Config.IsMacOS) {
            $nativePgrep = Get-Command '/usr/bin/pgrep' -ErrorAction SilentlyContinue
            if ($nativePgrep) {
                $ids = & '/usr/bin/pgrep' -f $Name 2>&1
                if ($ids) {
                    foreach ($id in $ids) {
                        $processName = (Get-Process -Id $id.Trim() -ErrorAction SilentlyContinue).ProcessName
                        [PSCustomObject]@{
                            Id          = $id.Trim()
                            ProcessName = if ($processName) { $processName } else { 'unknown' }
                        }
                    }
                }
                return
            }
        }
        # Windows: Usa Where-Object para filtro correto (wildcard não funciona em -Name do Get-Process)
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -like "*$Name*" } |
            Format-Table Id, ProcessName, CPU,
                @{ L='Mem(MB)'; E={ [math]::Round($_.WorkingSet64/1MB, 1) } } -AutoSize
    } catch {
        $er = [ErrorRecord]::new(
            $_.Exception, 'PgrepFailed', [ErrorCategory]::ObjectNotFound, $Name
        )
        $PSCmdlet.WriteError($er)
    }
}

# Cross-platform flushdns: suporta Windows, Linux (systemd-resolve/nscd) e macOS
function flushdns {
    [CmdletBinding()]
    param()
    try {
        if ($script:Config.IsWindows) {
            if ($script:Config.IsAdmin) {
                Clear-DnsClientCache -ErrorAction Stop
                Write-Verbose "Cache DNS limpo (Windows)."
            } else {
                Write-Warning "flushdns requer privilégios de Administrador no Windows."
            }
        } elseif ($script:Config.IsLinux) {
            # Tenta systemd-resolve primeiro, depois nscd
            if (Get-Command systemd-resolve -ErrorAction SilentlyContinue) {
                systemd-resolve --flush-caches 2>&1 | Out-Null
                Write-Verbose "Cache DNS limpo (systemd-resolve)."
            } elseif (Get-Command nscd -ErrorAction SilentlyContinue) {
                nscd -i hosts 2>&1 | Out-Null
                Write-Verbose "Cache DNS limpo (nscd)."
            } else {
                Write-Warning "flushdns: nenhum serviço de cache DNS detectado no Linux."
            }
        } elseif ($script:Config.IsMacOS) {
            # macOS: diferentes comandos por versão
            if (Get-Command dscacheutil -ErrorAction SilentlyContinue) {
                dscacheutil -flushcache 2>&1 | Out-Null
                killall -HUP mDNSResponder 2>&1 | Out-Null
                Write-Verbose "Cache DNS limpo (macOS)."
            }
        }
    } catch {
        $er = [ErrorRecord]::new(
            $_.Exception, 'FlushDnsFailed', [ErrorCategory]::ResourceUnavailable, $null
        )
        $PSCmdlet.WriteError($er)
    }
}

# Cross-platform df: Get-Volume (Windows) ou df command (Linux/macOS)
function df {
    [CmdletBinding()]
    param()
    try {
        if ($script:Config.IsWindows) {
            Get-Volume -ErrorAction SilentlyContinue |
                Where-Object { $_.DriveLetter -and $_.Size -gt 0 } |
                Sort-Object DriveLetter |
                Format-Table DriveLetter, FileSystemLabel, FileSystem,
                    @{ L='Size(GB)'; E={ [math]::Round($_.Size/1GB, 1) } },
                    @{ L='Free(GB)'; E={ [math]::Round($_.SizeRemaining/1GB, 1) } },
                    @{ L='Free%';    E={ [math]::Round(($_.SizeRemaining/$_.Size)*100, 0) } } -AutoSize
        } elseif ($script:Config.IsLinux -or $script:Config.IsMacOS) {
            $nativeDf = Get-Command '/usr/bin/df' -ErrorAction SilentlyContinue
            if ($nativeDf) {
                & '/usr/bin/df' -h 2>&1 | ForEach-Object { $_ }
            }
        }
    } catch {
        $er = [ErrorRecord]::new(
            $_.Exception, 'DfFailed', [ErrorCategory]::ReadError, $null
        )
        $PSCmdlet.WriteError($er)
    }
}

function pubip {
    [CmdletBinding()]
    param([switch]$Force)

    # Initialize cache variables on first run (StrictMode-safe)
    if (-not (Get-Variable -Name 'CachedPublicIP' -Scope Script -ErrorAction SilentlyContinue)) {
        $script:CachedPublicIP = $null
    }
    if (-not (Get-Variable -Name 'CachedPublicIPTimestamp' -Scope Script -ErrorAction SilentlyContinue)) {
        $script:CachedPublicIPTimestamp = [DateTime]::MinValue
    }

    # Cache válido por 5 minutos — evita chamada de rede a cada execução
    $cacheValid = $script:CachedPublicIP -and $script:CachedPublicIPTimestamp -and
                  ((Get-Date) - $script:CachedPublicIPTimestamp).TotalMinutes -lt 5
    if ($cacheValid -and -not $Force) {
        return $script:CachedPublicIP
    }
    $endpoints = 'https://api.ipify.org', 'https://icanhazip.com', 'https://ifconfig.me/ip'
    foreach ($url in $endpoints) {
        try {
            $response = Invoke-RestMethod -Uri $url -TimeoutSec 3 `
                -ErrorAction Stop -UseBasicParsing
            if ($response) {
                $script:CachedPublicIP = $response.Trim()
                $script:CachedPublicIPTimestamp = Get-Date
                return $script:CachedPublicIP
            }
        } catch [System.Net.WebException] {
            Write-Verbose "pubip: $url indisponível"
        } catch {
            Write-Verbose "pubip: falha em $url"
        }
    }
    $er = [ErrorRecord]::new(
        [System.Net.WebException]::new('Nenhum endpoint de IP público respondeu.'),
        'PubIpAllEndpointsFailed',
        [ErrorCategory]::ConnectionError,
        $endpoints
    )
    $PSCmdlet.WriteError($er)
}

function script:Get-WindowsSystemInfo {
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
}

function script:Get-LinuxSystemInfo {
    $osName = 'Linux'
    if (Test-Path /etc/os-release) {
        $osData = Get-Content /etc/os-release -ErrorAction SilentlyContinue
        $pretty = $osData | Where-Object { $_ -match '^PRETTY_NAME=' }
        if ($pretty) {
            $osName = $pretty.Split('=')[1].Trim('"')
        }
    }
    $memTotal = 0
    if (Test-Path /proc/meminfo) {
        $memLine = Get-Content /proc/meminfo | Where-Object { $_ -match '^MemTotal:' }
        if ($memLine) {
            $memTotal = [int]($memLine -replace '\D', '') / 1MB
        }
    }
    [PSCustomObject]@{
        Computer = if ($env:HOSTNAME) { $env:HOSTNAME } elseif ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { 'unknown' }
        User     = if ($env:USER) { $env:USER } elseif ($env:USERNAME) { $env:USERNAME } else { 'unknown' }
        OS       = $osName
        PS       = $PSVersionTable.PSVersion.ToString()
        RAM_GB   = [math]::Round($memTotal, 1)
    }
}

function script:Get-MacSystemInfo {
    $memGb = 0
    try {
        $memBytes = sysctl -n hw.memsize 2>&1
        if ($memBytes) { $memGb = [math]::Round($memBytes / 1GB, 1) }
    } catch { Write-Warning "Get-MacSystemInfo: sysctl hw.memsize falhou — RAM reportada como 0" }
    $uptime = try {
        $raw = (sysctl -n kern.boottime 2>&1 | Out-String)
        if ($raw -match 'sec\s*=\s*(\d+)') {
            $bootTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$Matches[1])
            (Get-Date) - $bootTime.LocalDateTime
        } else { 'N/A' }
    } catch { 'N/A' }
    [PSCustomObject]@{
        Computer  = if ($env:HOSTNAME) { $env:HOSTNAME } elseif ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { 'unknown' }
        User      = if ($env:USER) { $env:USER } elseif ($env:USERNAME) { $env:USERNAME } else { 'unknown' }
        OS        = 'macOS'
        PS        = $PSVersionTable.PSVersion.ToString()
        Uptime    = $uptime
        RAM_GB    = $memGb
        PS_Mem_MB = [math]::Round([Environment]::WorkingSet/1MB, 1)
    }
}

function sysinfo {
    [CmdletBinding()]
    param()
    try {
        if ($script:Config.IsWindows)     { script:Get-WindowsSystemInfo }
        elseif ($script:Config.IsLinux)   { script:Get-LinuxSystemInfo }
        elseif ($script:Config.IsMacOS)   { script:Get-MacSystemInfo }
    } catch {
        # Fallback genérico — inclui RAM_GB para compatibilidade com testes
        $memGb = try { [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory/1GB, 1) } catch { 0 }
        [PSCustomObject]@{
            Computer  = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } elseif ($env:HOSTNAME) { $env:HOSTNAME } else { 'unknown' }
            User      = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { 'unknown' }
            OS        = 'Unknown'
            PS        = $PSVersionTable.PSVersion.ToString()
            Uptime    = 'N/A'
            RAM_GB    = $memGb
            PS_Mem_MB = [math]::Round([Environment]::WorkingSet/1MB, 1)
        }
    }
}

# ── 8. SUDO ───────────────────────────────────────────────────
# Cross-platform sudo: Windows (elevated PowerShell), Linux/macOS (sudo nativo)
# Hardening: sanitiza null bytes e caracteres de controle no EncodedCommand
function sudo {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Command)

    if ($Command.Count -eq 1 -and $Command[0] -eq '!!') {
        $last = (Get-History -Count 1).CommandLine
        if ($last) { $Command = @($last) }
        else       { Write-Verbose "Nenhum comando no histórico."; return }
    }

    # Linux/macOS: usa sudo nativo se disponível
    if ($script:Config.IsLinux -or $script:Config.IsMacOS) {
        $nativeSudo = Get-Command '/usr/bin/sudo' -ErrorAction SilentlyContinue
        if ($nativeSudo) {
            if ($Command) {
                if ($PSCmdlet.ShouldProcess(($Command -join ' '), 'Executar com sudo')) {
                    & '/usr/bin/sudo' @Command
                }
            } else {
                Write-Warning "sudo: uso: sudo <comando> ou sudo !! para reexecutar último comando"
            }
            return
        }
    }

    # Windows: elevação via Start-Process -Verb RunAs
    $exe = if ($script:Config.PSMajor -ge 7) { 'pwsh' } else { 'powershell' }

    if ($Command) {
        $cmdText = $Command -join ' '
        try {
            # Sanitização: remove null bytes e caracteres de controle (U+0000–U+001F exceto tab/newline)
            $cmdText = $cmdText -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''

            if ([string]::IsNullOrWhiteSpace($cmdText)) {
                $er = [ErrorRecord]::new(
                    [System.ArgumentException]::new('Comando ficou vazio após sanitização.'),
                    'SudoEmptyCommand', [ErrorCategory]::InvalidArgument, $cmdText
                )
                $PSCmdlet.WriteError($er)
                return
            }

            if ($PSCmdlet.ShouldProcess($cmdText, 'Elevar como Administrador')) {
                $encoded = [Convert]::ToBase64String(
                    [System.Text.Encoding]::Unicode.GetBytes($cmdText)
                )
                Start-Process $exe -Verb RunAs -ArgumentList '-NoExit', '-EncodedCommand', $encoded
            }
        } catch {
            $er = [ErrorRecord]::new(
                $_.Exception, 'SudoElevationFailed', [ErrorCategory]::SecurityError, $cmdText
            )
            $PSCmdlet.WriteError($er)
        }
    } else {
        if ($PSCmdlet.ShouldProcess($exe, 'Abrir sessão elevada')) {
            Start-Process $exe -Verb RunAs
        }
    }
}
