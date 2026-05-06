# ── 5. ARQUIVOS E TEXTO ───────────────────────────────────────
function touch {
    param([Parameter(Mandatory, ValueFromPipeline)][string]$File)
    process {
        if (Test-Path $File) { (Get-Item $File).LastWriteTime = Get-Date }
        else                 { New-Item -ItemType File -Path $File -Force | Out-Null }
    }
}

function which {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Cmd)
    $result = (Get-Command $Cmd -ErrorAction SilentlyContinue).Source
    if ($result) { $result }
    else         { Write-Warning "'$Cmd' não encontrado no PATH." }
}

function unzip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$File,
        [string]$Dest = '.'
    )
    try   { Expand-Archive -Path $File -DestinationPath $Dest -Force -ErrorAction Stop }
    catch {
        $er = [System.Management.Automation.ErrorRecord]::new(
            $_.Exception, 'UnzipFailed', [System.Management.Automation.ErrorCategory]::ReadError, $File
        )
        $PSCmdlet.WriteError($er)
    }
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
# Validação de tamanho: rejeita arquivos maiores que $script:Config.MaxFileSizeMB (proteção DoS).
function sed {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position=0)][string]$File,
        [Parameter(Mandatory, Position=1)][string]$Find,
        [Parameter(Mandatory, Position=2)][string]$Replace,
        [switch]$Backup
    )

    if (-not (Test-Path $File)) {
        $er = [System.Management.Automation.ErrorRecord]::new(
            [System.IO.FileNotFoundException]::new("Arquivo '$File' não encontrado."),
            'SedFileNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $File
        )
        $PSCmdlet.WriteError($er)
        return
    }

    $tmp = $null
    try {
        $resolved = (Resolve-Path $File -ErrorAction Stop).Path

        # Validação de tamanho para proteção contra DoS
        $fileSize = (Get-Item $resolved -ErrorAction Stop).Length
        $maxBytes = ($script:Config.MaxFileSizeMB ?? 50) * 1MB
        if ($fileSize -gt $maxBytes) {
            $er = [System.Management.Automation.ErrorRecord]::new(
                [System.IO.IOException]::new("Arquivo excede o limite de $($script:Config.MaxFileSizeMB ?? 50)MB."),
                'SedFileTooLarge', [System.Management.Automation.ErrorCategory]::LimitsExceeded, $resolved
            )
            $PSCmdlet.WriteError($er)
            return
        }

        # UTF8 com BOM para compatibilidade total com PowerShell 5.1 e ferramentas Windows
        $enc        = New-Object System.Text.UTF8Encoding $true
        $newContent = ([System.IO.File]::ReadAllText($resolved, $enc)).Replace($Find, $Replace)

        $tmp = [System.IO.Path]::Combine(
            [System.IO.Path]::GetDirectoryName($resolved),
            [System.IO.Path]::GetRandomFileName()
        )

        if ($PSCmdlet.ShouldProcess($resolved, "Substituir '$Find' por '$Replace'")) {
            [System.IO.File]::WriteAllText($tmp, $newContent, $enc)

            if ($Backup) { Copy-Item $resolved "$resolved.bak" -Force }
            Move-Item $tmp $resolved -Force
            Write-Verbose "Modificado: $resolved$(if ($Backup) { " (backup: $resolved.bak)" })"
        }
    } catch {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -ErrorAction SilentlyContinue }
        $er = [System.Management.Automation.ErrorRecord]::new(
            $_.Exception, 'SedOperationFailed', [System.Management.Automation.ErrorCategory]::WriteError, $File
        )
        $PSCmdlet.WriteError($er)
    }
}
