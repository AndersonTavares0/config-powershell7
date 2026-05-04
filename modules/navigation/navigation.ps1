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
