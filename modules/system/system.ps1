# ── 6. SISTEMA ────────────────────────────────────────────────

# Detecção cross-platform de sistema operacional para este módulo
# PowerShell 6+ fornece variáveis automáticas SOMENTE LEITURA: $IsWindows, $IsLinux, $IsMacOS
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $script:_IsWindows = $IsWindows
    $script:_IsLinux   = $IsLinux
    $script:_IsMacOS   = $IsMacOS
} else {
    # PS 5.1 só roda no Windows
    $script:_IsWindows = $true
    $script:_IsLinux   = $false
    $script:_IsMacOS   = $false
}

# Cross-platform pkill: usa Get-Process (Windows) ou comando nativo (Linux/macOS)
function pkill {
    param([Parameter(Mandatory)][string]$Name)
    try {
        if ($script:_IsLinux -or $script:_IsMacOS) {
            # Fallback para comando nativo em Unix-like
            if (Get-Command pkill -ErrorAction SilentlyContinue) {
                pkill -f $Name 2>&1 | Out-Null
                return
            }
        }
        # Windows/PowerShell native
        Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Verbose "pkill: falha ao matar processo '$Name' - $_"
    }
}
Set-Alias k9 pkill

# Cross-platform pgrep
function pgrep {
    param([Parameter(Mandatory)][string]$Name)
    try {
        if ($script:_IsLinux -or $script:_IsMacOS) {
            if (Get-Command pgrep -ErrorAction SilentlyContinue) {
                $ids = pgrep -f $Name 2>&1
                if ($ids) {
                    foreach ($id in $ids) {
                        [PSCustomObject]@{
                            Id = $id.Trim()
                            ProcessName = (Get-Process -Id $id.Trim() -ErrorAction SilentlyContinue).ProcessName ?? 'unknown'
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
        Write-Verbose "pgrep: falha na busca por '$Name' - $_"
    }
}

# Cross-platform flushdns: suporta Windows, Linux (systemd-resolve/nscd) e macOS
function flushdns {
    try {
        if ($script:_IsWindows) {
            if ($script:IsAdmin) {
                Clear-DnsClientCache -ErrorAction Stop
                Write-Verbose "Cache DNS limpo (Windows)."
            } else {
                Write-Warning "flushdns requer privilégios de Administrador no Windows."
            }
        } elseif ($script:_IsLinux) {
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
        } elseif ($script:_IsMacOS) {
            # macOS: diferentes comandos por versão
            if (Get-Command dscacheutil -ErrorAction SilentlyContinue) {
                dscacheutil -flushcache 2>&1 | Out-Null
                killall -HUP mDNSResponder 2>&1 | Out-Null
                Write-Verbose "Cache DNS limpo (macOS)."
            }
        }
    } catch {
        Write-Warning "flushdns: falha ao limpar cache DNS - $_"
    }
}

# Cross-platform df: Get-Volume (Windows) ou df command (Linux/macOS)
function df {
    try {
        if ($script:_IsWindows) {
            Get-Volume -ErrorAction SilentlyContinue |
                Where-Object { $_.DriveLetter -and $_.Size -gt 0 } |
                Sort-Object DriveLetter |
                Format-Table DriveLetter, FileSystemLabel, FileSystem,
                    @{ L='Size(GB)'; E={ [math]::Round($_.Size/1GB, 1) } },
                    @{ L='Free(GB)'; E={ [math]::Round($_.SizeRemaining/1GB, 1) } },
                    @{ L='Free%';    E={ [math]::Round(($_.SizeRemaining/$_.Size)*100, 0) } } -AutoSize
        } elseif ($script:_IsLinux -or $script:_IsMacOS) {
            if (Get-Command df -ErrorAction SilentlyContinue) {
                df -h 2>&1 | ForEach-Object { $_ }
            }
        }
    } catch {
        Write-Warning "df: falha ao obter informações de disco - $_"
    }
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
            Write-Verbose "pubip: falha em $url - $_"
        }
    }
    Write-Warning "pubip: nenhum endpoint respondeu."
}

function sysinfo {
    try {
        if ($script:_IsWindows) {
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
        } elseif ($script:_IsLinux) {
            # Linux: lê /etc/os-release e /proc/meminfo
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
                Computer = hostname 2>$null ?? $env:HOSTNAME
                User     = $env:USER ?? $env:USERNAME
                OS       = $osName
                PS       = $PSVersionTable.PSVersion.ToString()
                RAM_GB   = [math]::Round($memTotal, 1)
            }
        } elseif ($script:_IsMacOS) {
            $osName = 'macOS'
            $memGb = 0
            try {
                $memBytes = sysctl -n hw.memsize 2>&1
                if ($memBytes) { $memGb = [math]::Round($memBytes / 1GB, 1) }
            } catch {}
            [PSCustomObject]@{
                Computer = scutil --get ComputerName 2>&1 ?? $env:HOSTNAME
                User     = $env:USER ?? $env:USERNAME
                OS       = $osName
                PS       = $PSVersionTable.PSVersion.ToString()
                RAM_GB   = $memGb
            }
        }
    } catch {
        # Fallback genérico
        [PSCustomObject]@{
            Computer  = $env:COMPUTERNAME ?? $env:HOSTNAME ?? 'unknown'
            User      = $env:USERNAME ?? $env:USER ?? 'unknown'
            OS        = 'Unknown'
            PS        = $PSVersionTable.PSVersion.ToString()
            Uptime    = 'N/A'
            PS_Mem_MB = [math]::Round([Environment]::WorkingSet/1MB, 1)
        }
    }
}

# ── 8. SUDO ───────────────────────────────────────────────────
# Cross-platform sudo: Windows (elevated PowerShell), Linux/macOS (sudo nativo)
function sudo {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Command)

    if ($Command.Count -eq 1 -and $Command[0] -eq '!!') {
        $last = (Get-History -Count 1).CommandLine
        if ($last) { $Command = @($last) }
        else       { Write-Verbose "Nenhum comando no histórico."; return }
    }

    # Linux/macOS: usa sudo nativo se disponível
    if ($script:_IsLinux -or $script:_IsMacOS) {
        if (Get-Command sudo -ErrorAction SilentlyContinue) {
            if ($Command) {
                & sudo $Command
            } else {
                Write-Warning "sudo: uso: sudo <comando> ou sudo !! para reexecutar último comando"
            }
            return
        }
    }

    # Windows: elevação via Start-Process -Verb RunAs
    $exe = if ($script:PSMajor -ge 7) { 'pwsh' } else { 'powershell' }

    if ($Command) {
        # -EncodedCommand preserva aspas e caracteres especiais.
        # Sanitização extra: remove null bytes e garante encoding Unicode válido
        $cmdText = $Command -join ' '
        try {
            $encoded = [Convert]::ToBase64String(
                [System.Text.Encoding]::Unicode.GetBytes($cmdText)
            )
            Start-Process $exe -Verb RunAs -ArgumentList '-NoExit', '-EncodedCommand', $encoded
        } catch {
            Write-Error "sudo: falha ao elevar comando - $_"
        }
    } else {
        Start-Process $exe -Verb RunAs
    }
}