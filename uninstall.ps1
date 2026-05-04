<#
.SYNOPSIS
    Uninstalls the PowerShell Profile by removing the symbolic link.
#>

Write-Host "--- PowerShell Profile Uninstaller ---" -ForegroundColor Cyan

if (Test-Path $PROFILE) {
    Write-Host "Removing profile at $PROFILE..."
    Remove-Item $PROFILE -Force
    
    # Check for backup
    if (Test-Path "$PROFILE.bak") {
        $restore = Read-Host "A backup was found ($PROFILE.bak). Restore it? [y/N]"
        if ($restore -eq 'y') {
            Move-Item "$PROFILE.bak" $PROFILE -Force
            Write-Host "Backup restored." -ForegroundColor Green
        }
    }
    
    Write-Host "Uninstallation complete." -ForegroundColor Green
} else {
    Write-Warning "No profile found at $PROFILE."
}

$cacheFile = "$HOME/.cache_pwsh_plugins.ps1"
if (Test-Path $cacheFile) {
    $remCache = Read-Host "Remove plugin cache file? ($cacheFile) [y/N]"
    if ($remCache -eq 'y') {
        Remove-Item $cacheFile -Force
        Write-Host "Cache removed."
    }
}
