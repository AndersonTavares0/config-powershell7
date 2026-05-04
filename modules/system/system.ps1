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
