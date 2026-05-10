# ── PROFILE PATH RESOLUTION (SHARED) ─────────────────────────
# Resolve o caminho do profile do usuário de forma cross-platform.
# Requer: $script:IsLnx (de lib/platform.ps1)

$ErrorActionPreference = 'Stop'

function script:Get-TargetProfilePath {
    if ($PROFILE -and $PROFILE.CurrentUserCurrentHost) {
        return $PROFILE.CurrentUserCurrentHost
    }
    if ($script:IsLnx) {
        $linuxPath = Join-Path $HOME '.config/powershell/Microsoft.PowerShell_profile.ps1'
        return $linuxPath
    }
    return $PROFILE
}


