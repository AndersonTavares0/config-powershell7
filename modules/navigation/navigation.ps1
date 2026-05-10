# ── 4. NAVEGAÇÃO ──────────────────────────────────────────────
# Nomes descritivos sem underscore (convencao PS, nao Python)

# Cross-platform path resolution lazy-init: resolved on first use
# instead of at module load to save ~2-6ms per shell startup.
# [Environment]::GetFolderPath hits the registry on Windows.

$script:DocsPath = $null
$script:DesktopPath = $null

function script:Resolve-NavPath {
    param([ValidateSet('Docs', 'Desktop')][string]$Which)
    if ($script:Config.IsWindows) {
        if ($Which -eq 'Docs')    { [Environment]::GetFolderPath('MyDocuments') }
        else                      { [Environment]::GetFolderPath('Desktop') }
    } else {
        $HOME
    }
}

function docs {
    if (-not $script:DocsPath) { $script:DocsPath = script:Resolve-NavPath 'Docs' }
    Set-Location $script:DocsPath
}
function dtop {
    if (-not $script:DesktopPath) { $script:DesktopPath = script:Resolve-NavPath 'Desktop' }
    Set-Location $script:DesktopPath
}
function home { Set-Location $HOME               }
function up   { Set-Location ..                  }
function up2  { Set-Location ../..              }
function la   { Get-ChildItem        | Format-Table -AutoSize }
function ll   { Get-ChildItem -Force | Format-Table -AutoSize }

# Parametro via param() formal - permite tab completion e -WhatIf futuro
function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    try {
        New-Item -ItemType Directory -Force -Path $Path -ErrorAction Stop | Out-Null
        Set-Location $Path
    } catch {
        Write-Error "mkcd: nao foi possivel criar '$Path' - $($_.Exception.Message)"
    }
}

function nf {
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Name)
    process { New-Item -ItemType File -Path $Name -Force | Out-Null }
}
