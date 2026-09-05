# ── PROFILE PATH RESOLUTION (SHARED) ─────────────────────────
# Resolve o caminho do profile do usuário de forma cross-platform.
# Requer: $script:IsLnx (de lib/platform.ps1)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function script:Get-TargetProfilePath {
    if ($PROFILE) {
        $allHosts = $PROFILE.PSObject.Properties['CurrentUserAllHosts']
        if ($allHosts -and $allHosts.Value) {
            return $allHosts.Value
        }
    }
    if ($script:IsLnx) {
        $linuxPath = Join-Path $HOME '.config/powershell/Microsoft.PowerShell_profile.ps1'
        return $linuxPath
    }
    return $PROFILE
}


