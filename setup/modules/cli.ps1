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
            $themeName = ''
            $skipTheme = $false
            $ompExists = Get-Command oh-my-posh -ErrorAction SilentlyContinue
            if ($ompExists) {
                Write-Host ""
                Write-Host "Oh My Posh Theme" -ForegroundColor Cyan
                Write-Host "----------------" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Available themes:" -ForegroundColor White
                Write-Host "  1. jandedobbeleer (recommended)" -ForegroundColor White
                Write-Host "  2. powerlevel10k_lean" -ForegroundColor White
                Write-Host "  3. powerlevel10k_modern" -ForegroundColor White
                Write-Host "  4. powerlevel10k_rainbow" -ForegroundColor White
                Write-Host "  5. atomic" -ForegroundColor White
                Write-Host "  6. Skip (no theme downloaded)" -ForegroundColor Gray
                Write-Host ""
                $themeChoice = Read-Host "Select a theme [1]"
                if ([string]::IsNullOrWhiteSpace($themeChoice)) { $themeChoice = '1' }
                $themeName = switch ($themeChoice) {
                    '1' { 'jandedobbeleer' }
                    '2' { 'powerlevel10k_lean' }
                    '3' { 'powerlevel10k_modern' }
                    '4' { 'powerlevel10k_rainbow' }
                    '5' { 'atomic' }
                    default { '' }
                }
                if ($themeName) {
                    Write-Host "Selected theme: $themeName" -ForegroundColor Green
                } else {
                    Write-Host "Skipping theme download." -ForegroundColor Gray
                }
            }

            Write-Host ""
            Write-Host "Starting installation... This may take several minutes." -ForegroundColor Yellow
            Write-Host ""
            Start-ProfileInstall -RepoPath $RepoPath -ThemeName $themeName
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
