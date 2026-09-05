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
            $terminalTheme = ''
            $termThemeWT = $false
            $termThemeAla = $false

            . (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'deps.ps1')

            $ompExists = Get-Command oh-my-posh -ErrorAction SilentlyContinue
            if ($ompExists) {
                Write-Host ""
                Write-Host "Oh My Posh Theme" -ForegroundColor Cyan
                Write-Host "----------------" -ForegroundColor Cyan
                Write-Host ""
                $themes = Get-OmpThemeList
                if ($themes) {
                    Write-Host "Available themes (${$themes.Count}):" -ForegroundColor White
                    $pages = [Math]::Ceiling($themes.Count / 15)
                    $page = 1
                    while ($page -le $pages) {
                        $start = ($page - 1) * 15
                        $end = [Math]::Min($start + 14, $themes.Count - 1)
                        for ($i = $start; $i -le $end; $i++) {
                            $marker = if ($themes[$i] -eq 'jandedobbeleer') { ' (recommended)' } else { '' }
                            Write-Host ("  {0,3}. {1}{2}" -f ($i + 1), $themes[$i], $marker) -ForegroundColor White
                        }
                        if ($page -lt $pages) {
                            Write-Host "  --- Page $page of $pages (enter 'n' for next) ---" -ForegroundColor Gray
                            $nav = Read-Host "Select theme number, 'n' for next, or enter to skip"
                            if ($nav -eq 'n') { $page++; continue }
                            if ([string]::IsNullOrWhiteSpace($nav)) { $themeName = ''; break }
                            if ([int]::TryParse($nav, [ref]$null)) {
                                $idx = [int]$nav - 1
                                if ($idx -ge 0 -and $idx -lt $themes.Count) { $themeName = $themes[$idx]; break }
                            }
                            Write-Host "Invalid input." -ForegroundColor Red
                        } else {
                            $choice = Read-Host "Select theme number [1], or enter to skip"
                            if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
                            if ([int]::TryParse($choice, [ref]$null)) {
                                $idx = [int]$choice - 1
                                if ($idx -ge 0 -and $idx -lt $themes.Count) { $themeName = $themes[$idx] }
                            }
                            break
                        }
                    }
                } else {
                    Write-Host "Could not fetch themes. Type a theme name or enter to skip:" -ForegroundColor Yellow
                    $themeName = Read-Host "Theme name"
                }
                if ($themeName) {
                    Write-Host "Selected OMP theme: $themeName" -ForegroundColor Green
                } else {
                    Write-Host "Skipping OMP theme download." -ForegroundColor Gray
                }
            }

            Write-Host ""
            Write-Host "Terminal Color Theme (optional)" -ForegroundColor Cyan
            Write-Host "-------------------------------" -ForegroundColor Cyan
            Write-Host ""
            $useTermTheme = Read-Host "Apply a terminal color theme? (y/n) [y]"
            if ([string]::IsNullOrWhiteSpace($useTermTheme) -or $useTermTheme -eq 'y') {
                $termThemes = Get-TerminalThemeList
                if ($termThemes) {
                    $idx = 0
                    foreach ($tt in $termThemes) {
                        $idx++
                        Write-Host "  $idx. $($tt.Name) ($($tt.Type))" -ForegroundColor White
                    }
                    Write-Host "  $($idx+1). Skip" -ForegroundColor Gray
                    Write-Host ""
                    $choice = Read-Host "Select terminal theme [1]"
                    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
                    if ([int]::TryParse($choice, [ref]$null)) {
                        $i = [int]$choice - 1
                        if ($i -ge 0 -and $i -lt $termThemes.Count) {
                            $terminalTheme = $termThemes[$i].Name
                            Write-Host "Selected terminal theme: $terminalTheme" -ForegroundColor Green

                            $wtChoice = Read-Host "Apply to Windows Terminal? (y/n) [y]"
                            if ([string]::IsNullOrWhiteSpace($wtChoice) -or $wtChoice -eq 'y') { $termThemeWT = $true }

                            $alaChoice = Read-Host "Apply to Alacritty? (y/n) [y]"
                            if ([string]::IsNullOrWhiteSpace($alaChoice) -or $alaChoice -eq 'y') { $termThemeAla = $true }
                        } else {
                            Write-Host "Skipping terminal theme." -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "Skipping terminal theme." -ForegroundColor Gray
                    }
                } else {
                    Write-Host "No terminal themes available." -ForegroundColor Yellow
                }
            } else {
                Write-Host "Skipping terminal theme." -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "Starting installation... This may take several minutes." -ForegroundColor Yellow
            Write-Host ""
            $installResult = Start-ProfileInstall -RepoPath $RepoPath -ThemeName $themeName `
                -InstallAlacritty $true `
                -TerminalThemeName $terminalTheme `
                -TerminalThemeWT $termThemeWT `
                -TerminalThemeAla $termThemeAla
            Write-Host ""
            if ($installResult) {
                Write-Host "Done! Restart your terminal to apply all changes." -ForegroundColor Green
            } else {
                Write-Host "Installation finished with failures. Review the summary above." -ForegroundColor Red
            }
        }
        '2' {
            Write-Host ""
            Write-Host "Starting uninstall..." -ForegroundColor Yellow
            $uninstallResult = Start-ProfileUninstall -RepoPath $RepoPath
            Write-Host ""
            if ($uninstallResult) { Write-Host "Done!" -ForegroundColor Green }
            else { Write-Host "Uninstall finished with failures." -ForegroundColor Red }
        }
        '3' {
            Write-Host "Exiting." -ForegroundColor Gray
        }
        default {
            Write-Host "Invalid option." -ForegroundColor Red
        }
    }
}
