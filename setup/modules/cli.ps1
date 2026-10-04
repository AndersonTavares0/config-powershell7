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
    Write-Host " [3] Install AI coding CLIs" -ForegroundColor White
    Write-Host " [4] Exit" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Select an option"

    switch ($choice) {
        '1' {
            $themeName = ''
            $terminalTheme = ''
            $termThemeWT = $false

            $ompInstalled = Install-OhMyPosh
            if ($ompInstalled) {
                Write-Host ""
                Write-Host "Oh My Posh Theme" -ForegroundColor Cyan
                Write-Host "----------------" -ForegroundColor Cyan
                Write-Host ""
                $themes = Get-OmpThemeList -RepoPath $RepoPath
                if ($themes) {
                    Write-Host "Available themes ($($themes.Count)):" -ForegroundColor White
                    $pages = [Math]::Ceiling($themes.Count / 15)
                    $page = 1
                    while ($page -le $pages) {
                        $start = ($page - 1) * 15
                        $end = [Math]::Min($start + 14, $themes.Count - 1)
                        for ($i = $start; $i -le $end; $i++) {
                            $marker = if ($themes[$i] -eq 'atomic') { ' (recommended)' } else { '' }
                            Write-Host ("  {0,3}. {1}{2}" -f ($i + 1), $themes[$i], $marker) -ForegroundColor White
                        }
                        if ($page -lt $pages) {
                            Write-Host "  --- Page $page of $pages (enter 'n' for next) ---" -ForegroundColor Gray
                            $nav = Read-Host "Select theme number, 'n' for next, or enter to skip"
                            if ($nav -eq 'n') { $page++; continue }
                            if ($nav -match '^(?i)m$') {
                                $themeName = Read-Host 'Theme name'
                                if (-not (Test-OmpThemeName -Name $themeName)) {
                                    Write-Host 'Invalid theme name.' -ForegroundColor Red
                                    $themeName = ''
                                }
                                break
                            }
                            if ([string]::IsNullOrWhiteSpace($nav)) { $themeName = ''; break }
                            $themeIndex = ConvertFrom-MenuIndex -Value $nav -Count $themes.Count
                            if ($themeIndex.Valid) {
                                $themeName = $themes[$themeIndex.Index]
                                break
                            }
                            Write-Host "Invalid input." -ForegroundColor Red
                        } else {
                            $choice = Read-Host "Select theme number [1], 'm' for manual name, or enter to skip"
                            if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
                            if ($choice -match '^(?i)m$') {
                                $themeName = Read-Host 'Theme name'
                                if (-not (Test-OmpThemeName -Name $themeName)) {
                                    Write-Host 'Invalid theme name.' -ForegroundColor Red
                                    $themeName = ''
                                }
                            } else {
                                $themeIndex = ConvertFrom-MenuIndex -Value $choice -Count $themes.Count
                                if ($themeIndex.Valid) {
                                    $themeName = $themes[$themeIndex.Index]
                                }
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
                    $terminalThemeIndex = ConvertFrom-MenuIndex -Value $choice -Count ($termThemes.Count + 1)
                    if ($terminalThemeIndex.Valid) {
                        if ($terminalThemeIndex.Index -lt $termThemes.Count) {
                            $terminalTheme = $termThemes[$terminalThemeIndex.Index].Name
                            Write-Host "Selected terminal theme: $terminalTheme" -ForegroundColor Green

                            $wtChoice = Read-Host "Apply to Windows Terminal? (y/n) [y]"
                            if ([string]::IsNullOrWhiteSpace($wtChoice) -or $wtChoice -eq 'y') { $termThemeWT = $true }

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
            $fastfetchChoice = Read-Host "Install Fastfetch? (y/n) [n]"
            $installFastfetch = $fastfetchChoice -match '^(y|yes)$'
            $topgradeChoice = Read-Host "Install Topgrade? (y/n) [n]"
            $installTopgrade = $topgradeChoice -match '^(y|yes)$'

            Write-Host ""
            Write-Host "Starting installation... This may take several minutes." -ForegroundColor Yellow
            Write-Host ""
            $installResult = Start-ProfileInstall -RepoPath $RepoPath -ThemeName $themeName `
                -InstallFastfetch $installFastfetch `
                -InstallTopgrade $installTopgrade `
                -TerminalThemeName $terminalTheme `
                -TerminalThemeWT $termThemeWT
            Write-Host ""
            if ($installResult) {
                Write-Host "Done! Restart your terminal to apply all changes." -ForegroundColor Green
            } else {
                Write-Host "Installation finished with failures. Review the summary above." -ForegroundColor Red
            }
            return [bool]$installResult
        }
        '2' {
            Write-Host ""
            Write-Host "Starting uninstall..." -ForegroundColor Yellow
            $uninstallResult = Start-ProfileUninstall -RepoPath $RepoPath
            Write-Host ""
            if ($uninstallResult) { Write-Host "Done!" -ForegroundColor Green }
            else { Write-Host "Uninstall finished with failures." -ForegroundColor Red }
            return [bool]$uninstallResult
        }
        '3' {
            return Start-AgentCliMenu
        }
        '4' {
            Write-Host "Exiting." -ForegroundColor Gray
            return $true
        }
        default {
            Write-Host "Invalid option." -ForegroundColor Red
            return $false
        }
    }
}

function Start-AgentCliMenu {
    $specs = @(Get-AgentCliInstallSpec)
    Write-Host ""
    Write-Host "AI Coding CLIs (optional)" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    for ($index = 0; $index -lt $specs.Count; $index++) {
        Write-Host (" [{0}] {1}" -f ($index + 1), $specs[$index].DisplayName) -ForegroundColor White
    }
    Write-Host " [A] All tools" -ForegroundColor White
    Write-Host " [Enter] Cancel" -ForegroundColor Gray

    $selection = (Read-Host 'Select tool numbers, separated by commas').Trim()
    $selectionResult = Get-AgentCliSelection -Selection $selection -Specs $specs
    if ($selectionResult.Cancelled) { return $true }
    if (-not $selectionResult.Valid) {
        Write-Host 'Invalid selection; no tools installed.' -ForegroundColor Red
        return $false
    }

    $allInstalled = $true
    foreach ($spec in $selectionResult.Selected) {
        if (-not (Install-AgentCli -Name $spec.Name)) { $allInstalled = $false }
    }
    return $allInstalled
}

function Get-AgentCliSelection {
    param(
        [AllowEmptyString()][string]$Selection,
        [object[]]$Specs = @(Get-AgentCliInstallSpec)
    )

    if ([string]::IsNullOrWhiteSpace($Selection)) {
        return [PSCustomObject]@{ Valid = $true; Cancelled = $true; Selected = @() }
    }
    if ($Selection -match '^(?i)a(ll)?$') {
        return [PSCustomObject]@{ Valid = $true; Cancelled = $false; Selected = @($Specs) }
    }

    $selectedSpecs = @()
    foreach ($token in ($Selection -split ',')) {
        $index = 0
        if (-not [int]::TryParse($token.Trim(), [ref]$index) -or $index -lt 1 -or $index -gt $Specs.Count) {
            return [PSCustomObject]@{ Valid = $false; Cancelled = $false; Selected = @() }
        }
        $selectedSpecs += $Specs[$index - 1]
    }
    $selectedSpecs = @($selectedSpecs | Sort-Object Name -Unique)
    return [PSCustomObject]@{ Valid = $true; Cancelled = $false; Selected = $selectedSpecs }
}

function ConvertFrom-MenuIndex {
    param(
        [AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][int]$Count
    )

    $index = 0
    if (-not [int]::TryParse($Value.Trim(), [ref]$index) -or $index -lt 1 -or $index -gt $Count) {
        return [PSCustomObject]@{ Valid = $false; Index = -1 }
    }
    return [PSCustomObject]@{ Valid = $true; Index = $index - 1 }
}
