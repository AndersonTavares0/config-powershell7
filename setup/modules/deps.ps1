#Requires -Version 5.1
# Dependency installers: winget, PS7, Git, OMP, Zoxide, NerdFont, PSModules, Alacritty, Chocolatey, Scoop

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$DisplayName
    )
    Write-GuiLog "Installing $DisplayName..." -Type Step
    try {
        $winget = Get-WingetPath
        if (-not $winget) {
            Write-GuiLog "winget not found. Install manually or use Windows 10 1709+." -Type Warn
            return $false
        }
        $proc = Start-Process -FilePath $winget -ArgumentList 'install','--id',$Id,'--exact',
            '--silent','--accept-package-agreements','--accept-source-agreements' `
            -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($proc.ExitCode -eq 0) {
            Write-GuiLog "$DisplayName installed." -Type Ok
            return $true
        }
        Write-GuiLog "$DisplayName - winget exited with code $($proc.ExitCode)" -Type Warn
        return $false
    } catch {
        Write-GuiLog "$DisplayName failed: $($_.Exception.Message)" -Type Warn
        return $false
    }
}

function Install-PowerShell7 {
    $existing = Get-Executable -Name 'pwsh'
    if ($existing) {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "PowerShell 7 already installed: $($existing.Path)$verStr" -Type Ok
        return $true
    }
    return Install-WingetPackage -Id 'Microsoft.PowerShell' -DisplayName 'PowerShell 7'
}

function Install-Git {
    $existing = Get-Executable -Name 'git'
    if ($existing) {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "Git already installed: $($existing.Path)$verStr" -Type Ok
        return $true
    }
    return Install-WingetPackage -Id 'Git.Git' -DisplayName 'Git'
}

function Install-OhMyPosh {
    $existing = Get-Executable -Name 'oh-my-posh'
    if ($existing) {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "Oh My Posh already installed: $($existing.Path)$verStr" -Type Ok
        return $true
    }
    return Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -DisplayName 'Oh My Posh'
}

function Install-Zoxide {
    $existing = Get-Executable -Name 'zoxide'
    if ($existing) {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "Zoxide already installed: $($existing.Path)$verStr" -Type Ok
        return $true
    }
    return Install-WingetPackage -Id 'ajeetdsouza.zoxide' -DisplayName 'Zoxide'
}

function Get-OmpThemeList {
    $apiUrl = 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes'
    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        $items = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        $themes = $items | Where-Object { $_.name -like '*.omp.json' } |
            ForEach-Object { $_.name -replace '\.omp\.json$', '' } |
            Sort-Object
        return @($themes)
    } catch {
        Write-GuiLog "Failed to fetch theme list: $($_.Exception.Message)" -Type Warn
        return $null
    }
}

#region Terminal theme definitions
$script:TerminalThemeData = $null
function Initialize-TerminalThemes {
    if ($script:TerminalThemeData) { return }
    $script:TerminalThemeData = [ordered]@{
        'Catppuccin Mocha' = @{
            Type = 'dark'; Description = 'Dark purple theme from Catppuccin project'
            WT = @{ foreground = '#CDD6F4'; background = '#1E1E2E'; cursorColor = '#F5E0DC'; selectionBackground = '#45475A'
                    black = '#45475A'; red = '#F38BA8'; green = '#A6E3A1'; yellow = '#F9E2AF'
                    blue = '#89B4FA'; purple = '#F5C2E7'; cyan = '#94E2D5'; white = '#BAC2DE'
                    brightBlack = '#585B70'; brightRed = '#F38BA8'; brightGreen = '#A6E3A1'
                    brightYellow = '#F9E2AF'; brightBlue = '#89B4FA'; brightPurple = '#F5C2E7'
                    brightCyan = '#94E2D5'; brightWhite = '#A6ADC8' }
            Ala = @{ primary = @{ background = '#1E1E2E'; foreground = '#CDD6F4' }
                     normal = @{ black = '#45475A'; red = '#F38BA8'; green = '#A6E3A1'
                                 yellow = '#F9E2AF'; blue = '#89B4FA'; magenta = '#F5C2E7'
                                 cyan = '#94E2D5'; white = '#BAC2DE' }
                     bright = @{ black = '#585B70'; red = '#F38BA8'; green = '#A6E3A1'
                                 yellow = '#F9E2AF'; blue = '#89B4FA'; magenta = '#F5C2E7'
                                 cyan = '#94E2D5'; white = '#A6ADC8' } }
        }
        'Catppuccin Latte' = @{
            Type = 'light'; Description = 'Light theme from Catppuccin project'
            WT = @{ foreground = '#4C4F69'; background = '#EFF1F5'; cursorColor = '#DC8A78'; selectionBackground = '#ACB0BE'
                    black = '#5C5F77'; red = '#D20F39'; green = '#40A02B'; yellow = '#DF8E1D'
                    blue = '#1E66F5'; purple = '#EA76CB'; cyan = '#179299'; white = '#ACB0BE'
                    brightBlack = '#6C6F85'; brightRed = '#D20F39'; brightGreen = '#40A02B'
                    brightYellow = '#DF8E1D'; brightBlue = '#1E66F5'; brightPurple = '#EA76CB'
                    brightCyan = '#179299'; brightWhite = '#BCC0CC' }
            Ala = @{ primary = @{ background = '#EFF1F5'; foreground = '#4C4F69' }
                     normal = @{ black = '#5C5F77'; red = '#D20F39'; green = '#40A02B'
                                 yellow = '#DF8E1D'; blue = '#1E66F5'; magenta = '#EA76CB'
                                 cyan = '#179299'; white = '#ACB0BE' }
                     bright = @{ black = '#6C6F85'; red = '#D20F39'; green = '#40A02B'
                                 yellow = '#DF8E1D'; blue = '#1E66F5'; magenta = '#EA76CB'
                                 cyan = '#179299'; white = '#BCC0CC' } }
        }
        'Dracula' = @{
            Type = 'dark'; Description = 'Popular dark theme with purple accents'
            WT = @{ foreground = '#F8F8F2'; background = '#282A36'; cursorColor = '#F8F8F2'; selectionBackground = '#44475A'
                    black = '#21222C'; red = '#FF5555'; green = '#50FA7B'; yellow = '#F1FA8C'
                    blue = '#BD93F9'; purple = '#FF79C6'; cyan = '#8BE9FD'; white = '#F8F8F2'
                    brightBlack = '#6272A4'; brightRed = '#FF6E6E'; brightGreen = '#69FF94'
                    brightYellow = '#FFFFA5'; brightBlue = '#D6ACFF'; brightPurple = '#FF92DF'
                    brightCyan = '#A4FFFF'; brightWhite = '#FFFFFF' }
            Ala = @{ primary = @{ background = '#282A36'; foreground = '#F8F8F2' }
                     normal = @{ black = '#21222C'; red = '#FF5555'; green = '#50FA7B'
                                 yellow = '#F1FA8C'; blue = '#BD93F9'; magenta = '#FF79C6'
                                 cyan = '#8BE9FD'; white = '#F8F8F2' }
                     bright = @{ black = '#6272A4'; red = '#FF6E6E'; green = '#69FF94'
                                 yellow = '#FFFFA5'; blue = '#D6ACFF'; magenta = '#FF92DF'
                                 cyan = '#A4FFFF'; white = '#FFFFFF' } }
        }
        'Nord' = @{
            Type = 'dark'; Description = 'Arctic bluish dark theme'
            WT = @{ foreground = '#D8DEE9'; background = '#2E3440'; cursorColor = '#D8DEE9'; selectionBackground = '#434C5E'
                    black = '#3B4252'; red = '#BF616A'; green = '#A3BE8C'; yellow = '#EBCB8B'
                    blue = '#81A1C1'; purple = '#B48EAD'; cyan = '#88C0D0'; white = '#E5E9F0'
                    brightBlack = '#4C566A'; brightRed = '#BF616A'; brightGreen = '#A3BE8C'
                    brightYellow = '#EBCB8B'; brightBlue = '#81A1C1'; brightPurple = '#B48EAD'
                    brightCyan = '#8FBCBB'; brightWhite = '#ECEFF4' }
            Ala = @{ primary = @{ background = '#2E3440'; foreground = '#D8DEE9' }
                     normal = @{ black = '#3B4252'; red = '#BF616A'; green = '#A3BE8C'
                                 yellow = '#EBCB8B'; blue = '#81A1C1'; magenta = '#B48EAD'
                                 cyan = '#88C0D0'; white = '#E5E9F0' }
                     bright = @{ black = '#4C566A'; red = '#BF616A'; green = '#A3BE8C'
                                 yellow = '#EBCB8B'; blue = '#81A1C1'; magenta = '#B48EAD'
                                 cyan = '#8FBCBB'; white = '#ECEFF4' } }
        }
        'Tokyo Night' = @{
            Type = 'dark'; Description = 'Deep blue night theme'
            WT = @{ foreground = '#A9B1D6'; background = '#1A1B26'; cursorColor = '#A9B1D6'; selectionBackground = '#283457'
                    black = '#1D202F'; red = '#F7768E'; green = '#9ECE6A'; yellow = '#E0AF68'
                    blue = '#7AA2F7'; purple = '#BB9AF7'; cyan = '#7DCFFF'; white = '#A9B1D6'
                    brightBlack = '#565F89'; brightRed = '#F7768E'; brightGreen = '#9ECE6A'
                    brightYellow = '#E0AF68'; brightBlue = '#7AA2F7'; brightPurple = '#BB9AF7'
                    brightCyan = '#7DCFFF'; brightWhite = '#C0CAF5' }
            Ala = @{ primary = @{ background = '#1A1B26'; foreground = '#A9B1D6' }
                     normal = @{ black = '#1D202F'; red = '#F7768E'; green = '#9ECE6A'
                                 yellow = '#E0AF68'; blue = '#7AA2F7'; magenta = '#BB9AF7'
                                 cyan = '#7DCFFF'; white = '#A9B1D6' }
                     bright = @{ black = '#565F89'; red = '#F7768E'; green = '#9ECE6A'
                                 yellow = '#E0AF68'; blue = '#7AA2F7'; magenta = '#BB9AF7'
                                 cyan = '#7DCFFF'; white = '#C0CAF5' } }
        }
        'One Half Dark' = @{
            Type = 'dark'; Description = 'Popular dark theme with warm accents'
            WT = @{ foreground = '#DCDFE4'; background = '#282C34'; cursorColor = '#DCDFE4'; selectionBackground = '#3E4451'
                    black = '#383C42'; red = '#E06C75'; green = '#98C379'; yellow = '#D19A66'
                    blue = '#61AFEF'; purple = '#C678DD'; cyan = '#56B6C2'; white = '#ABB2BF'
                    brightBlack = '#5C6370'; brightRed = '#E06C75'; brightGreen = '#98C379'
                    brightYellow = '#D19A66'; brightBlue = '#61AFEF'; brightPurple = '#C678DD'
                    brightCyan = '#56B6C2'; brightWhite = '#DCDFE4' }
            Ala = @{ primary = @{ background = '#282C34'; foreground = '#DCDFE4' }
                     normal = @{ black = '#383C42'; red = '#E06C75'; green = '#98C379'
                                 yellow = '#D19A66'; blue = '#61AFEF'; magenta = '#C678DD'
                                 cyan = '#56B6C2'; white = '#ABB2BF' }
                     bright = @{ black = '#5C6370'; red = '#E06C75'; green = '#98C379'
                                 yellow = '#D19A66'; blue = '#61AFEF'; magenta = '#C678DD'
                                 cyan = '#56B6C2'; white = '#DCDFE4' } }
        }
    }
}

function Get-TerminalThemeList {
    Initialize-TerminalThemes
    return $script:TerminalThemeData.Keys | ForEach-Object {
        $d = $script:TerminalThemeData[$_]
        [PSCustomObject]@{ Name = $_; Type = $d.Type; Description = $d.Description }
    } | Sort-Object Name
}

function Get-TerminalThemeData {
    param([string]$Name)
    Initialize-TerminalThemes
    return $script:TerminalThemeData[$Name]
}

function Set-WindowsTerminalColorScheme {
    param([string]$ThemeName, [string]$SettingsPath)
    $theme = Get-TerminalThemeData -Name $ThemeName
    if (-not $theme) { Write-GuiLog "Terminal theme '$ThemeName' not found." -Type Warn; return $false }

    if (-not $SettingsPath) {
        $knownPaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        )
        $SettingsPath = $knownPaths | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
    }
    if (-not $SettingsPath) { Write-GuiLog "Windows Terminal settings.json not found." -Type Info; return $false }

    try {
        $settings = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $wtColors = $theme.WT

        $scheme = [PSCustomObject]@{
            name = $ThemeName
            foreground = $wtColors.foreground
            background = $wtColors.background
            cursorColor = $wtColors.cursorColor
            selectionBackground = $wtColors.selectionBackground
            black = $wtColors.black; red = $wtColors.red; green = $wtColors.green
            yellow = $wtColors.yellow; blue = $wtColors.blue; purple = $wtColors.purple
            cyan = $wtColors.cyan; white = $wtColors.white
            brightBlack = $wtColors.brightBlack; brightRed = $wtColors.brightRed
            brightGreen = $wtColors.brightGreen; brightYellow = $wtColors.brightYellow
            brightBlue = $wtColors.brightBlue; brightPurple = $wtColors.brightPurple
            brightCyan = $wtColors.brightCyan; brightWhite = $wtColors.brightWhite
        }

        if (-not $settings.schemes) {
            $settings | Add-Member -Name 'schemes' -Value @($scheme) -MemberType NoteProperty -Force
        } else {
            $existing = $settings.schemes | Where-Object { $_.name -eq $ThemeName }
            if ($existing) {
                $idx = [array]::IndexOf($settings.schemes, $existing)
                $settings.schemes[$idx] = $scheme
            } else {
                $settings.schemes += $scheme
            }
        }

        if (-not $settings.profiles) {
            Write-GuiLog "Windows Terminal settings has no profiles section." -Type Warn; return $false
        }
        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -Name 'defaults' -Value @{} -MemberType NoteProperty -Force
        }
        $settings.profiles.defaults | Add-Member -Name 'colorScheme' -Value $ThemeName -MemberType NoteProperty -Force

        $settings | ConvertTo-Json -Depth 15 | Set-Content $SettingsPath -Encoding UTF8 -Force
        Write-GuiLog "Windows Terminal color scheme set to '$ThemeName'." -Type Ok
        return $true
    } catch {
        Write-GuiLog "Failed to set Windows Terminal color scheme: $($_.Exception.Message)" -Type Warn
        return $false
    }
}

function Set-AlacrittyColorScheme {
    param([string]$ThemeName)
    $theme = Get-TerminalThemeData -Name $ThemeName
    if (-not $theme) { Write-GuiLog "Terminal theme '$ThemeName' not found." -Type Warn; return $false }

    $configDir = Join-Path $env:APPDATA 'alacritty'
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $configPath = Join-Path $configDir 'alacritty.toml'

    if (Test-Path $configPath) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item $configPath "$configPath.bak-$timestamp" -Force
    }

    $colors = $theme.Ala
    $colorLines = @(
        "[colors.primary]",
        "background = `"$($colors.primary.background)`"",
        "foreground = `"$($colors.primary.foreground)`"",
        "",
        "[colors.normal]",
        "black   = `"$($colors.normal.black)`"",
        "red     = `"$($colors.normal.red)`"",
        "green   = `"$($colors.normal.green)`"",
        "yellow  = `"$($colors.normal.yellow)`"",
        "blue    = `"$($colors.normal.blue)`"",
        "magenta = `"$($colors.normal.magenta)`"",
        "cyan    = `"$($colors.normal.cyan)`"",
        "white   = `"$($colors.normal.white)`"",
        "",
        "[colors.bright]",
        "black   = `"$($colors.bright.black)`"",
        "red     = `"$($colors.bright.red)`"",
        "green   = `"$($colors.bright.green)`"",
        "yellow  = `"$($colors.bright.yellow)`"",
        "blue    = `"$($colors.bright.blue)`"",
        "magenta = `"$($colors.bright.magenta)`"",
        "cyan    = `"$($colors.bright.cyan)`"",
        "white   = `"$($colors.bright.white)`""
    )

    try {
        if (Test-Path $configPath) {
            $existing = Get-Content $configPath -Raw -Encoding UTF8
            $colorSectionStart = $existing.IndexOf('[colors.primary]')
            if ($colorSectionStart -ge 0) {
                $colorSectionEnd = $existing.IndexOf('[[', $colorSectionStart + 1)
                if ($colorSectionEnd -lt 0) { $colorSectionEnd = $existing.IndexOf('[', $existing.IndexOf('[', 1) + 1) }
                if ($colorSectionEnd -lt 0) { $colorSectionEnd = $existing.Length }
                # Replace colors, keep other sections
                $newContent = $existing.Substring(0, $colorSectionStart) + ($colorLines -join "`r`n") + "`r`n`r`n" + $existing.Substring($colorSectionEnd).TrimStart()
            } else {
                # No colors section — append before first [[ or end
                $lastSection = $existing.LastIndexOf('[', $existing.LastIndexOf('[') - 1)
                if ($lastSection -le 0) { $lastSection = $existing.Length }
                $newContent = $existing.Substring(0, $lastSection).TrimEnd() + "`r`n`r`n" + ($colorLines -join "`r`n") + "`r`n`r`n" + $existing.Substring($lastSection).TrimStart()
            }
            Set-Content -Path $configPath -Value $newContent -Encoding UTF8 -Force
        } else {
            Set-Content -Path $configPath -Value (($colorLines -join "`r`n") + "`r`n") -Encoding UTF8 -Force
        }
        Write-GuiLog "Alacritty theme set to '$ThemeName'." -Type Ok
        return $true
    } catch {
        Write-GuiLog "Failed to set Alacritty color scheme: $($_.Exception.Message)" -Type Warn
        return $false
    }
}

function Install-CompleteConfig {
    param([string]$ThemeName)
    Set-WindowsTerminalColorScheme -ThemeName $ThemeName
    Set-AlacrittyColorScheme -ThemeName $ThemeName
}
#endregion

function Install-OmpTheme {
    param([string]$ThemeName)

    if ([string]::IsNullOrWhiteSpace($ThemeName)) {
        Write-GuiLog "No theme selected - skipping theme download." -Type Info
        return $false
    }

    $omp = Get-Executable -Name 'oh-my-posh'
    if (-not $omp) {
        Write-GuiLog "Oh My Posh not found in PATH. Cannot download theme." -Type Warn
        return $false
    }

    $themeDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.poshthemes'
    if (-not (Test-Path $themeDir)) {
        New-Item -ItemType Directory -Force -Path $themeDir | Out-Null
    }

    $themeFile = Join-Path $themeDir "$ThemeName.omp.json"

    if (Test-Path $themeFile) {
        try {
            $raw = Get-Content $themeFile -Raw -ErrorAction SilentlyContinue
            if ($raw -and $raw.Length -gt 100) {
                Write-GuiLog "Theme '$ThemeName' already exists." -Type Ok
                return $true
            }
        } catch {
            # Corrupted file - re-download
        }
    }

    $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$ThemeName.omp.json"
    Write-GuiLog "Downloading theme '$ThemeName'..." -Type Step

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $themeUrl -OutFile $themeFile -ErrorAction Stop

        $fileItem = Get-Item $themeFile -ErrorAction SilentlyContinue
        if (-not $fileItem -or $fileItem.Length -lt 100) {
            Write-GuiLog "Theme download appears corrupted (size: $($fileItem.Length) bytes)" -Type Fail
            Remove-Item $themeFile -Force -ErrorAction SilentlyContinue
            return $false
        }

        Write-GuiLog "Theme '$ThemeName' downloaded successfully." -Type Ok
        return $true
    } catch {
        Write-GuiLog "Failed to download theme '$ThemeName': $($_.Exception.Message)" -Type Warn
        if (Test-Path $themeFile) {
            Remove-Item $themeFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

function Install-NerdFont {
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $existingFamilies = [System.Drawing.FontFamily]::Families | Where-Object { $_.Name -match 'FiraCode Nerd' }
    if ($existingFamilies) {
        Write-GuiLog "FiraCode Nerd Font already installed ($($existingFamilies.Count) variant(s))." -Type Ok
        return $true
    }

    Write-GuiLog "Installing FiraCode Nerd Font..." -Type Step
    try {
        $fontZipUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip'
        $fontZip = Join-Path $env:TEMP 'FiraCode-NerdFont.zip'
        $fontDir = Join-Path $env:TEMP 'FiraCode-NerdFont'

        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $fontZipUrl -OutFile $fontZip -ErrorAction Stop

        if (Test-Path $fontDir) { Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $fontDir -Force | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($fontZip, $fontDir)

        Add-Type -AssemblyName System.Windows.Forms
        $shell = New-Object -ComObject Shell.Application
        $fontsFolder = $shell.Namespace(0x14)

        $installedCount = 0
        foreach ($fontFile in (Get-ChildItem $fontDir -Filter '*.ttf' -Recurse)) {
            try {
                $fontsFolder.CopyHere($fontFile.FullName, 0x14)
                $installedCount++
            } catch {
                Write-GuiLog "Could not install font $($fontFile.Name): $($_.Exception.Message)" -Type Warn
            }
        }

        Remove-Item $fontZip -Force -ErrorAction SilentlyContinue
        Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue

        if ($installedCount -gt 0) {
            Write-GuiLog "FiraCode Nerd Font installed ($installedCount variants)." -Type Ok
            return $true
        } else {
            Write-GuiLog "No font files were installed." -Type Warn
            return $false
        }
    } catch {
        Write-GuiLog "Failed to install Nerd Font: $($_.Exception.Message)" -Type Warn
        return $false
    }
}

function Install-Topgrade {
    $existing = Get-Executable -Name 'topgrade'
    if ($existing) {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "Topgrade already installed: $($existing.Path)$verStr" -Type Ok
        return $true
    }
    return Install-WingetPackage -Id 'topgrade.topgrade' -DisplayName 'Topgrade'
}

function Install-PSModules {
    $nuGet = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
    if (-not $nuGet) {
        Write-GuiLog "Installing NuGet package provider..." -Type Step
        try {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            }
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction Stop
            Write-GuiLog "NuGet installed." -Type Ok
        } catch {
            Write-GuiLog "NuGet install failed: $($_.Exception.Message)" -Type Warn
            return $false
        }
    }

    $galleryTrusted = $false
    try {
        $gallery = Get-PSRepository -Name PSGallery -ErrorAction Stop
        if ($gallery.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            $galleryTrusted = $true
        }
    } catch {
        Write-GuiLog "PSGallery unavailable: $($_.Exception.Message)" -Type Warn
        return $false
    }

    foreach ($mod in @(@{ Name = 'PSReadLine'; MinVersion = '2.3.0' }, @{ Name = 'Terminal-Icons'; MinVersion = '0.11.0' })) {
        $existing = Get-Module -ListAvailable -Name $mod.Name -ErrorAction SilentlyContinue |
            Where-Object { $_.Version -ge [version]$mod.MinVersion }
        if ($existing) {
            Write-GuiLog "$($mod.Name) $($existing[0].Version) already installed." -Type Ok
            continue
        }
        Write-GuiLog "Installing $($mod.Name)..." -Type Step
        try {
            Install-Module -Name $mod.Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-GuiLog "$($mod.Name) installed." -Type Ok
        } catch {
            Write-GuiLog "$($mod.Name) install failed: $($_.Exception.Message)" -Type Warn
        }
    }

    if ($galleryTrusted) {
        try {
            Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted -ErrorAction SilentlyContinue
        } catch { }
    }

    return $true
}

function Set-WindowsTerminalFont {
    param([string]$SettingsPath)

    $fontName = 'FiraCode Nerd Font'

    if (-not $SettingsPath) {
        $knownPaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        )
        $SettingsPath = $knownPaths | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
    }

    if (-not $settingsPath) {
        Write-GuiLog "Windows Terminal settings.json not found." -Type Info
        return $false
    }

    try {
        $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        if (-not $settings.profiles) {
            Write-GuiLog "Windows Terminal settings has no profiles section." -Type Warn
            return $false
        }

        $changed = $false

        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -Name 'defaults' -Value @{} -MemberType NoteProperty -Force
        }
        $defaultsFontProp = $settings.profiles.defaults.PSObject.Properties['font']
        $defaultsFont = if ($defaultsFontProp) { $defaultsFontProp.Value } else { $null }
        if (-not $defaultsFont) {
            $defaultsFont = [PSCustomObject]@{}
            $settings.profiles.defaults | Add-Member -Name 'font' -Value $defaultsFont -MemberType NoteProperty -Force
        }
        $defaultsFaceProp = $defaultsFont.PSObject.Properties['face']
        if (-not $defaultsFaceProp -or $defaultsFaceProp.Value -ne $fontName) {
            $defaultsFont | Add-Member -Name 'face' -Value $fontName -MemberType NoteProperty -Force
            $changed = $true
        }

        $profileList = $settings.profiles.PSObject.Properties['list']
        if ($profileList -and $profileList.Value) {
            foreach ($wtProfile in $profileList.Value) {
                $pfFontProp = $wtProfile.PSObject.Properties['font']
                $pfFont = if ($pfFontProp) { $pfFontProp.Value } else { $null }
                if (-not $pfFont) {
                    $pfFont = [PSCustomObject]@{}
                    $wtProfile | Add-Member -Name 'font' -Value $pfFont -MemberType NoteProperty -Force
                }
                $pfFaceProp = $pfFont.PSObject.Properties['face']
                if (-not $pfFaceProp -or $pfFaceProp.Value -ne $fontName) {
                    $pfFont | Add-Member -Name 'face' -Value $fontName -MemberType NoteProperty -Force
                    $changed = $true
                }
            }
        }

        if ($changed) {
            $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8 -Force
            Write-GuiLog "Windows Terminal font set to $fontName." -Type Ok
        } else {
            Write-GuiLog "Windows Terminal already using $fontName." -Type Ok
        }
        return $true
    } catch {
        Write-GuiLog "Could not configure Windows Terminal font: $($_.Exception.Message)" -Type Warn
        return $false
    }
}

function Install-AlacrittyConfig {
    $configDir = Join-Path $env:APPDATA 'alacritty'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $configPath = Join-Path $configDir 'alacritty.toml'

    if (Test-Path $configPath) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item $configPath "$configPath.bak-$timestamp" -Force
        Write-GuiLog "Existing Alacritty config backed up." -Type Info
    }

    Set-Content -Path $configPath -Value @'
[window]
decorations = "Full"
opacity = 0.95
dynamic_padding = true

[window.padding]
x = 4
y = 2

[window.dimensions]
columns = 120
lines = 35

[font]
size = 12

[font.normal]
family = "FiraCode Nerd Font"
style = "Regular"

[font.bold]
family = "FiraCode Nerd Font"
style = "Bold"

[font.italic]
family = "FiraCode Nerd Font"
style = "Italic"

[font.bold_italic]
family = "FiraCode Nerd Font"
style = "Bold Italic"

[colors.primary]
background = "#1E1E2E"
foreground = "#CDD6F4"

[colors.normal]
black   = "#45475A"
red     = "#F38BA8"
green   = "#A6E3A1"
yellow  = "#F9E2AF"
blue    = "#89B4FA"
magenta = "#F5C2E7"
cyan    = "#94E2D5"
white   = "#BAC2DE"

[colors.bright]
black   = "#585B70"
red     = "#F38BA8"
green   = "#A6E3A1"
yellow  = "#F9E2AF"
blue    = "#89B4FA"
magenta = "#F5C2E7"
cyan    = "#94E2D5"
white   = "#A6ADC8"

[[keyboard.bindings]]
action = "Paste"
key = "V"
mods = "Control|Shift"

[terminal.shell]
program = "pwsh"
args = ["-NoLogo"]
'@ -Encoding UTF8 -Force

    Write-GuiLog "Alacritty configured at: $configPath" -Type Ok
    $true
}

function Install-Alacritty {
    $existing = Get-Executable -Name 'alacritty'
    if (-not $existing) {
        $null = Install-WingetPackage -Id 'Alacritty.Alacritty' -DisplayName 'Alacritty'
    } else {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "Alacritty already installed: $($existing.Path)$verStr" -Type Ok
    }

    if (Get-Command alacritty -ErrorAction SilentlyContinue) {
        Write-GuiLog "Configuring Alacritty..." -Type Step
        Install-AlacrittyConfig
        return $true
    }
    Write-GuiLog "Alacritty not found after install attempt." -Type Warn
    return $false
}

function Install-Chocolatey {
    param([string[]]$Sources = @())

    $existing = Get-Command choco -ErrorAction SilentlyContinue
    if ($existing) {
        Write-GuiLog "Chocolatey already installed: $($existing.Source)" -Type Ok
        return $true
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-GuiLog "Chocolatey requires administrator privileges to install to the default path." -Type Warn
        Write-GuiLog "Install manually as Administrator or run this installer as Admin." -Type Info
        return $false
    }

    Write-GuiLog "Installing Chocolatey..." -Type Step
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        $chocolateyInstallUrl = 'https://community.chocolatey.org/install.ps1'
        $chocolateyInstallPath = Join-Path $env:TEMP "config-pwsh7-install-chocolatey-$([guid]::NewGuid().ToString('N')).ps1"
        Write-GuiLog "Remote installer notice: Chocolatey setup executes the official script from $chocolateyInstallUrl." -Type Warn
        Write-GuiLog "Downloading Chocolatey installer to: $chocolateyInstallPath" -Type Info
        Invoke-WebRequest -Uri $chocolateyInstallUrl -OutFile $chocolateyInstallPath -UseBasicParsing -ErrorAction Stop
        Unblock-File -Path $chocolateyInstallPath -ErrorAction SilentlyContinue
        & $chocolateyInstallPath

        $chocoBin = 'C:\ProgramData\chocolatey\bin'
        if (Test-Path $chocoBin) {
            $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'Process')
            if ($currentPath -notmatch [regex]::Escape($chocoBin)) {
                [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$chocoBin", 'Process')
                $env:PATH = "$env:PATH;$chocoBin"
            }
        }

        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-GuiLog "Chocolatey installed." -Type Ok
        } else {
            Write-GuiLog "Chocolatey installed but not in PATH. Restart terminal." -Type Warn
            return $false
        }
    } catch {
        Write-GuiLog "Chocolatey install failed: $($_.Exception.Message)" -Type Warn
        return $false
    }

    foreach ($source in $Sources) {
        $trimmed = $source.Trim()
        if (-not $trimmed) { continue }
        $sourceName = ($trimmed -replace 'https?://', '' -replace '[^a-zA-Z0-9]', '-').Trim('-')
        if (-not $sourceName) { $sourceName = "custom-$(Get-Random -Maximum 9999)" }
        Write-GuiLog "Adding Chocolatey source: $trimmed" -Type Info
        try {
            choco source add -n $sourceName -s $trimmed --priority=1 2>&1 | Out-Null
            Write-GuiLog "Source added: $sourceName" -Type Ok
        } catch {
            Write-GuiLog "Failed to add source: $($_.Exception.Message)" -Type Warn
        }
    }

    return $true
}

function Install-Scoop {
    param([string[]]$Buckets = @())

    $existing = Get-Executable -Name 'scoop'
    if (-not $existing) {
        Write-GuiLog "Installing Scoop..." -Type Step
        try {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            }
            $scoopInstallUrl = 'https://get.scoop.sh'
            $scoopInstallPath = Join-Path $env:TEMP "config-pwsh7-install-scoop-$([guid]::NewGuid().ToString('N')).ps1"
            Write-GuiLog "Remote installer notice: Scoop setup executes the official script from $scoopInstallUrl." -Type Warn
            Write-GuiLog "Downloading Scoop installer to: $scoopInstallPath" -Type Info
            Invoke-WebRequest -Uri $scoopInstallUrl -OutFile $scoopInstallPath -UseBasicParsing -ErrorAction Stop
            Unblock-File -Path $scoopInstallPath -ErrorAction SilentlyContinue
            & $scoopInstallPath

            $scoopBin = Join-Path $HOME 'scoop\bin'
            if (Test-Path $scoopBin) {
                $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'Process')
                if ($currentPath -notmatch [regex]::Escape($scoopBin)) {
                    [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$scoopBin", 'Process')
                    $env:PATH = "$env:PATH;$scoopBin"
                }
            }

            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                Write-GuiLog "Scoop installed." -Type Ok
            } else {
                Write-GuiLog "Scoop installed but not in PATH. Restart terminal." -Type Warn
                return $false
            }
        } catch {
            Write-GuiLog "Scoop install failed: $($_.Exception.Message)" -Type Warn
            return $false
        }
    } else {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "Scoop already installed: $($existing.Path)$verStr" -Type Ok
    }

    foreach ($bucket in $Buckets) {
        $trimmed = $bucket.Trim()
        if (-not $trimmed) { continue }
        Write-GuiLog "Adding Scoop bucket: $trimmed" -Type Step
        try {
            $currentBuckets = & scoop bucket list 2>&1 | Out-String
            if ($currentBuckets -match [regex]::Escape($trimmed)) {
                Write-GuiLog "Bucket '$trimmed' already added." -Type Ok
            } else {
                & scoop bucket add $trimmed 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-GuiLog "Bucket '$trimmed' added." -Type Ok
                } else {
                    Write-GuiLog "Bucket '$trimmed' add returned exit code $LASTEXITCODE." -Type Warn
                }
            }
        } catch {
            Write-GuiLog "Failed to add bucket '$trimmed': $($_.Exception.Message)" -Type Warn
        }
    }

    return $true
}
