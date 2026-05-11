#Requires -Version 5.1
# Terminal menu fallback when WPF GUI is unavailable

function Start-CliMenu {
    param([string]$RepoPath)

    Write-Host ""
    Write-Host "PowerShell 7 Profile Setup - Terminal Mode" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [1] Install all dependencies and link profile" -ForegroundColor White
    Write-Host " [2] Uninstall profile and clean up cache files" -ForegroundColor White
    Write-Host " [3] Exit" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Select an option"

    switch ($choice) {
        '1' {
            Write-Host ""
            Write-Host "Starting installation... This may take several minutes." -ForegroundColor Yellow
            Write-Host ""
            Start-ProfileInstall -RepoPath $RepoPath
            Write-Host ""
            Write-Host "Done! Restart your terminal to apply all changes." -ForegroundColor Green
        }
        '2' {
            Write-Host ""
            Write-Host "Starting uninstall..." -ForegroundColor Yellow
            Start-ProfileUninstall -RepoPath $RepoPath
            Write-Host ""
            Write-Host "Done!" -ForegroundColor Green
        }
        '3' {
            Write-Host "Exiting." -ForegroundColor Gray
        }
        default {
            Write-Host "Invalid option." -ForegroundColor Red
        }
    }
}
