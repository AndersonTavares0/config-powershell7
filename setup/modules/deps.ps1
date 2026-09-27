#Requires -Version 5.1
# Dependency installers: WinGet, PowerShell, Git, Oh My Posh, Zoxide, Fastfetch, fonts, modules, Scoop, coding CLIs

function Get-WingetPackageArguments {
    param(
        [Parameter(Mandatory)][string]$Id,
        [ValidateSet('user', 'machine')][string]$Scope = 'user'
    )

    return @(
        'install', '--id', $Id, '--exact', '--scope', $Scope,
        '--silent', '--accept-package-agreements', '--accept-source-agreements'
    )
}

function Update-ProcessPathFromUser {
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    if ([string]::IsNullOrWhiteSpace($userPath) -and [string]::IsNullOrWhiteSpace($machinePath)) { return }

    $entries = @($env:PATH -split ';') + @($machinePath -split ';') + @($userPath -split ';')
    $seen = @{}
    $uniqueEntries = foreach ($entry in $entries) {
        $normalized = $entry.Trim()
        if ($normalized -and -not $seen.ContainsKey($normalized)) {
            $seen[$normalized] = $true
            $entry.Trim()
        }
    }
    $env:PATH = $uniqueEntries -join ';'
}

function Get-ScoopPackageName {
    param([Parameter(Mandatory)][string]$Id)

    switch ($Id) {
        'Microsoft.PowerShell' { return 'pwsh' }
        'Git.Git' { return 'git' }
        'JanDeDobbeleer.OhMyPosh' { return 'oh-my-posh' }
        'ajeetdsouza.zoxide' { return 'zoxide' }
        'Fastfetch-cli.Fastfetch' { return 'fastfetch' }
        'topgrade-rs.topgrade' { return 'topgrade' }
        default { return $null }
    }
}

function Install-ScoopFallbackPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$DisplayName
    )

    $packageName = Get-ScoopPackageName -Id $Id
    if (-not $packageName) {
        Write-GuiLog "No Scoop fallback is configured for $DisplayName ($Id)." -Type Warn
        return $false
    }

    $extraPackages = @('fastfetch', 'topgrade')
    $buckets = if ($packageName -in $extraPackages) { @('extras') } else { @() }
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    if (-not $scoop) {
        $interactiveConsole = $Host.Name -eq 'ConsoleHost' -and -not $env:CI
        if (-not $interactiveConsole) {
            Write-GuiLog "WinGet is unavailable. Install Scoop manually to install $DisplayName without WinGet." -Type Warn
            return $false
        }
        $installScoop = Read-Host "WinGet is unavailable. Install Scoop for $DisplayName? (y/n) [n]"
        if ($installScoop -notmatch '^(?i)y(es)?$') { return $false }
        if (-not (Install-Scoop -Buckets $buckets)) { return $false }
    } elseif ($buckets.Count -gt 0) {
        if (-not (Install-Scoop -Buckets $buckets)) { return $false }
    }

    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    if (-not $scoop) {
        Write-GuiLog 'Scoop finished installing, but its command is unavailable in this session.' -Type Warn
        return $false
    }

    try {
        Write-GuiLog "Installing $DisplayName with Scoop package '$packageName'." -Type Step
        & $scoop.Source install $packageName
        Update-ProcessPathFromUser
        if (Get-Command $packageName -ErrorAction SilentlyContinue) {
            Write-GuiLog "$DisplayName installed with Scoop." -Type Ok
            return $true
        }
        Write-GuiLog "Scoop did not expose '$packageName' after installation." -Type Warn
        return $false
    } catch {
        Write-GuiLog "Scoop could not install $($DisplayName): $($_.Exception.Message)" -Type Warn
        return $false
    }
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$DisplayName
    )
    Write-GuiLog "Installing $DisplayName..." -Type Step
    try {
        $winget = Get-WingetPath
        if (-not $winget) {
            Write-GuiLog 'WinGet not found. Trying the approved per-user Scoop fallback.' -Type Warn
            return Install-ScoopFallbackPackage -Id $Id -DisplayName $DisplayName
        }
        $arguments = Get-WingetPackageArguments -Id $Id -Scope user
        $proc = Start-Process -FilePath $winget -ArgumentList $arguments `
            -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($proc.ExitCode -eq 0) {
            Update-ProcessPathFromUser
            Write-GuiLog "$DisplayName installed." -Type Ok
            return $true
        }

        $interactiveConsole = $Host.Name -eq 'ConsoleHost' -and -not $env:CI
        if ($interactiveConsole) {
            $retryElevated = Read-Host "$DisplayName failed in user scope (exit $($proc.ExitCode)). Retry with administrator rights? (y/n) [n]"
            if ($retryElevated -match '^(?i)y(es)?$') {
                $elevatedArguments = Get-WingetPackageArguments -Id $Id -Scope machine
                $elevatedProcess = Start-Process -FilePath $winget -ArgumentList $elevatedArguments `
                    -Verb RunAs -Wait -PassThru -ErrorAction Stop
                if ($elevatedProcess.ExitCode -eq 0) {
                    Update-ProcessPathFromUser
                    Write-GuiLog "$DisplayName installed with administrator approval." -Type Ok
                    return $true
                }
                Write-GuiLog "$DisplayName - elevated WinGet exited with code $($elevatedProcess.ExitCode)." -Type Warn
                return $false
            }
        }

        Write-GuiLog "$DisplayName - WinGet exited with code $($proc.ExitCode); no administrator retry was started." -Type Warn
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
    param([string]$RepoPath)

    $apiUrl = 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes'
    $themeNames = New-Object System.Collections.Generic.List[string]
    foreach ($themeName in (Get-LocalOmpThemeList -RepoPath $RepoPath)) { $themeNames.Add($themeName) }

    try {
        Enable-Tls12
        $items = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 8 -ErrorAction Stop
        foreach ($item in ($items | Where-Object { $_.name -like '*.omp.json' })) {
            $themeName = $item.name -replace '\.omp\.json$', ''
            if ((Test-OmpThemeName -Name $themeName) -and $themeName -notin $themeNames) { $themeNames.Add($themeName) }
        }
    } catch {
        Write-GuiLog "Could not fetch online OMP themes; using bundled and user themes: $($_.Exception.Message)" -Type Warn
    }
    return @($themeNames | Sort-Object -Unique)
}

function Get-LocalOmpThemeList {
    param([string]$RepoPath)

    $themeNames = New-Object System.Collections.Generic.List[string]
    $themeDirs = @()
    if ($RepoPath) { $themeDirs += Join-Path $RepoPath 'themes' }
    $themeDirs += Get-OmpThemeDirectory

    foreach ($themeDir in ($themeDirs | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $themeDir -PathType Container)) { continue }
        foreach ($themeFile in (Get-ChildItem -LiteralPath $themeDir -Filter '*.omp.json' -File -ErrorAction SilentlyContinue)) {
            $themeName = $themeFile.Name -replace '\.omp\.json$', ''
            if ((Test-OmpThemeName -Name $themeName) -and
                (Test-OmpThemeFile -Path $themeFile.FullName) -and
                $themeName -notin $themeNames) {
                $themeNames.Add($themeName)
            }
        }
    }
    return @($themeNames | Sort-Object -Unique)
}

function Test-OmpThemeName {
    param([AllowEmptyString()][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -in @('.', '..')) { return $false }
    return $Name -match '^[\p{L}\p{Nd}][\p{L}\p{Nd} ._-]{0,63}$' -and $Name -notmatch '[ .]$'
}

function Test-OmpThemeFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        $theme = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($theme.version -notin @(2, 3, 4) -or @($theme.blocks).Count -eq 0) { return $false }
        foreach ($block in $theme.blocks) {
            if (-not $block.type -or @($block.segments).Count -eq 0) { return $false }
            foreach ($segment in $block.segments) {
                if (-not $segment.type) { return $false }
            }
        }
        return $true
    } catch {
        return $false
    }
}

#region Terminal theme definitions
# Canonical terminal theme data for the primary setup installer.
# Legacy install.ps1 keeps a standalone copy to avoid coupling the legacy path
# to setup module load order.
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
        }
        'Catppuccin Latte' = @{
            Type = 'light'; Description = 'Light theme from Catppuccin project'
            WT = @{ foreground = '#4C4F69'; background = '#EFF1F5'; cursorColor = '#DC8A78'; selectionBackground = '#ACB0BE'
                    black = '#5C5F77'; red = '#D20F39'; green = '#40A02B'; yellow = '#DF8E1D'
                    blue = '#1E66F5'; purple = '#EA76CB'; cyan = '#179299'; white = '#ACB0BE'
                    brightBlack = '#6C6F85'; brightRed = '#D20F39'; brightGreen = '#40A02B'
                    brightYellow = '#DF8E1D'; brightBlue = '#1E66F5'; brightPurple = '#EA76CB'
                    brightCyan = '#179299'; brightWhite = '#BCC0CC' }
        }
        'Dracula' = @{
            Type = 'dark'; Description = 'Popular dark theme with purple accents'
            WT = @{ foreground = '#F8F8F2'; background = '#282A36'; cursorColor = '#F8F8F2'; selectionBackground = '#44475A'
                    black = '#21222C'; red = '#FF5555'; green = '#50FA7B'; yellow = '#F1FA8C'
                    blue = '#BD93F9'; purple = '#FF79C6'; cyan = '#8BE9FD'; white = '#F8F8F2'
                    brightBlack = '#6272A4'; brightRed = '#FF6E6E'; brightGreen = '#69FF94'
                    brightYellow = '#FFFFA5'; brightBlue = '#D6ACFF'; brightPurple = '#FF92DF'
                    brightCyan = '#A4FFFF'; brightWhite = '#FFFFFF' }
        }
        'Nord' = @{
            Type = 'dark'; Description = 'Arctic bluish dark theme'
            WT = @{ foreground = '#D8DEE9'; background = '#2E3440'; cursorColor = '#D8DEE9'; selectionBackground = '#434C5E'
                    black = '#3B4252'; red = '#BF616A'; green = '#A3BE8C'; yellow = '#EBCB8B'
                    blue = '#81A1C1'; purple = '#B48EAD'; cyan = '#88C0D0'; white = '#E5E9F0'
                    brightBlack = '#4C566A'; brightRed = '#BF616A'; brightGreen = '#A3BE8C'
                    brightYellow = '#EBCB8B'; brightBlue = '#81A1C1'; brightPurple = '#B48EAD'
                    brightCyan = '#8FBCBB'; brightWhite = '#ECEFF4' }
        }
        'Tokyo Night' = @{
            Type = 'dark'; Description = 'Deep blue night theme'
            WT = @{ foreground = '#A9B1D6'; background = '#1A1B26'; cursorColor = '#A9B1D6'; selectionBackground = '#283457'
                    black = '#1D202F'; red = '#F7768E'; green = '#9ECE6A'; yellow = '#E0AF68'
                    blue = '#7AA2F7'; purple = '#BB9AF7'; cyan = '#7DCFFF'; white = '#A9B1D6'
                    brightBlack = '#565F89'; brightRed = '#F7768E'; brightGreen = '#9ECE6A'
                    brightYellow = '#E0AF68'; brightBlue = '#7AA2F7'; brightPurple = '#BB9AF7'
                    brightCyan = '#7DCFFF'; brightWhite = '#C0CAF5' }
        }
        'One Half Dark' = @{
            Type = 'dark'; Description = 'Popular dark theme with warm accents'
            WT = @{ foreground = '#DCDFE4'; background = '#282C34'; cursorColor = '#DCDFE4'; selectionBackground = '#3E4451'
                    black = '#383C42'; red = '#E06C75'; green = '#98C379'; yellow = '#D19A66'
                    blue = '#61AFEF'; purple = '#C678DD'; cyan = '#56B6C2'; white = '#ABB2BF'
                    brightBlack = '#5C6370'; brightRed = '#E06C75'; brightGreen = '#98C379'
                    brightYellow = '#D19A66'; brightBlue = '#61AFEF'; brightPurple = '#C678DD'
                    brightCyan = '#56B6C2'; brightWhite = '#DCDFE4' }
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

function Get-WindowsTerminalSettingsPath {
    $knownPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    return $knownPaths | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
}

function Backup-WindowsTerminalSettings {
    param([string]$SettingsPath)
    # Rewriting settings.json through ConvertTo-Json drops the JSON comments Windows
    # Terminal ships by default, so keep one recoverable copy of the original.
    $backupPath = "$SettingsPath.config-powershell7.bak"
    if (Test-Path $backupPath -PathType Leaf) { return }
    Copy-Item -LiteralPath $SettingsPath -Destination $backupPath -Force
    Write-GuiLog "Windows Terminal settings backed up: $backupPath" -Type Info
}

function Set-WindowsTerminalColorScheme {
    param([string]$ThemeName, [string]$SettingsPath)
    $theme = Get-TerminalThemeData -Name $ThemeName
    if (-not $theme) { Write-GuiLog "Terminal theme '$ThemeName' not found." -Type Warn; return $false }

    if (-not $SettingsPath) { $SettingsPath = Get-WindowsTerminalSettingsPath }
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
            $existing = @($settings.schemes | Where-Object { $_.name -eq $ThemeName })[0]
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

        Backup-WindowsTerminalSettings -SettingsPath $SettingsPath
        [System.IO.File]::WriteAllText($SettingsPath, ($settings | ConvertTo-Json -Depth 15), (New-Object System.Text.UTF8Encoding($false)))
        Write-GuiLog "Windows Terminal color scheme set to '$ThemeName'." -Type Ok
        return $true
    } catch {
        Write-GuiLog "Failed to set Windows Terminal color scheme: $($_.Exception.Message)" -Type Warn
        return $false
    }
}

#endregion

function Install-OmpTheme {
    param([string]$ThemeName, [string]$RepoPath)

    if ([string]::IsNullOrWhiteSpace($ThemeName)) {
        Write-GuiLog "No theme selected - skipping theme download." -Type Info
        return $false
    }
    if (-not (Test-OmpThemeName -Name $ThemeName)) {
        Write-GuiLog "Invalid OMP theme name '$ThemeName'. Use letters, numbers, dot, dash, or underscore." -Type Warn
        return $false
    }

    $omp = Get-Executable -Name 'oh-my-posh'
    if (-not $omp) {
        Write-GuiLog "Oh My Posh not found in PATH. Cannot download theme." -Type Warn
        return $false
    }

    $themeDir = Get-OmpThemeDirectory
    if (-not (Test-Path $themeDir)) {
        New-Item -ItemType Directory -Force -Path $themeDir | Out-Null
    }

    $themeFile = Join-Path $themeDir "$ThemeName.omp.json"

    if (Test-Path $themeFile) {
        if (Test-OmpThemeFile -Path $themeFile) {
            Write-GuiLog "Theme '$ThemeName' already exists." -Type Ok
            return $true
        }
        Write-GuiLog "Theme file already exists but is invalid: $themeFile. It was not overwritten." -Type Warn
        return $false
    }

    $bundledTheme = if ($RepoPath) { Join-Path (Join-Path $RepoPath 'themes') "$ThemeName.omp.json" } else { $null }
    if ($bundledTheme -and (Test-OmpThemeFile -Path $bundledTheme)) {
        Copy-Item -LiteralPath $bundledTheme -Destination $themeFile -Force
        Write-GuiLog "Bundled theme '$ThemeName' installed from the project." -Type Ok
        return $true
    }

    $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$ThemeName.omp.json"
    Write-GuiLog "Downloading theme '$ThemeName'..." -Type Step

    $downloaded = Get-FileFromUrl -Url $themeUrl -OutFile $themeFile -MinBytes 100 -Description "theme '$ThemeName'"
    if ($downloaded -and (Test-OmpThemeFile -Path $themeFile)) {
        Write-GuiLog "Theme '$ThemeName' downloaded successfully." -Type Ok
        return $true
    }

    Remove-Item -LiteralPath $themeFile -Force -ErrorAction SilentlyContinue
    Write-GuiLog "Downloaded theme '$ThemeName' is invalid." -Type Warn

    return $false
}

function Get-OmpThemeDirectory {
    $userProfile = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrWhiteSpace($userProfile)) { $userProfile = $HOME }
    return Join-Path $userProfile '.poshthemes'
}

function Add-FontResource {
    param([Parameter(Mandatory = $true)][string]$Path)
    # Registry alone only takes effect at next logon; AddFontResourceW publishes the
    # font to the running session so a terminal restart is enough.
    if (-not ('ConfigPowerShell7.NativeFonts' -as [type])) {
        Add-Type -Namespace 'ConfigPowerShell7' -Name 'NativeFonts' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("gdi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int AddFontResourceW(string lpszFilename);
'@
    }
    return [ConfigPowerShell7.NativeFonts]::AddFontResourceW($Path)
}

function Test-NerdFontPresent {
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        return @([System.Drawing.FontFamily]::Families | Where-Object { $_.Name -match 'FiraCode Nerd' }).Count -gt 0
    } catch {
        Write-GuiLog "Could not enumerate installed fonts: $($_.Exception.Message)" -Type Warn
        return $false
    }
}

function Install-NerdFont {
    if (Test-NerdFontPresent) {
        Write-GuiLog 'FiraCode Nerd Font already installed.' -Type Ok
        return $true
    }

    Write-GuiLog "Installing FiraCode Nerd Font..." -Type Step
    $fontZip = Join-Path $env:TEMP 'FiraCode-NerdFont.zip'
    $fontDir = Join-Path $env:TEMP 'FiraCode-NerdFont'
    try {
        $fontZipUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip'

        if (-not (Get-FileFromUrl -Url $fontZipUrl -OutFile $fontZip -MinBytes 100 -Description 'FiraCode Nerd Font archive')) {
            return $false
        }

        if (Test-Path $fontDir) { Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $fontDir -Force | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($fontZip, $fontDir)

        # Per-user install (Windows 10 1809+). The Shell.Application route targets the
        # machine-wide Fonts folder, needs elevation, and reports no error when it is denied.
        $userFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $userFontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        New-Item -ItemType Directory -Force -Path $userFontDir | Out-Null
        if (-not (Test-Path $userFontKey)) { New-Item -Path $userFontKey -Force | Out-Null }

        $installedCount = 0
        foreach ($fontFile in (Get-ChildItem $fontDir -Filter '*.ttf' -Recurse)) {
            try {
                $destination = Join-Path $userFontDir $fontFile.Name
                Copy-Item -LiteralPath $fontFile.FullName -Destination $destination -Force
                Set-ItemProperty -Path $userFontKey -Name "$($fontFile.BaseName) (TrueType)" -Value $destination -Force
                $null = Add-FontResource -Path $destination
                $installedCount++
            } catch {
                Write-GuiLog "Could not install font $($fontFile.Name): $($_.Exception.Message)" -Type Warn
            }
        }

        if ($installedCount -gt 0) {
            Write-GuiLog "FiraCode Nerd Font installed ($installedCount variants). Restart the terminal to use it." -Type Ok
            return $true
        }
        Write-GuiLog "No font files were installed." -Type Warn
        return $false
    } catch {
        Write-GuiLog "Failed to install Nerd Font: $($_.Exception.Message)" -Type Warn
        return $false
    } finally {
        Remove-Item $fontZip -Force -ErrorAction SilentlyContinue
        Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Topgrade {
    $existing = Get-Executable -Name 'topgrade'
    if ($existing) {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "Topgrade already installed: $($existing.Path)$verStr" -Type Ok
        return $true
    }
    return Install-WingetPackage -Id 'topgrade-rs.topgrade' -DisplayName 'Topgrade'
}

function Install-Fastfetch {
    $existing = Get-Executable -Name 'fastfetch'
    if ($existing) {
        $verStr = if ($existing.Version) { " $($existing.Version)" } else { '' }
        Write-GuiLog "Fastfetch already installed: $($existing.Path)$verStr" -Type Ok
        return $true
    }
    return Install-WingetPackage -Id 'Fastfetch-cli.Fastfetch' -DisplayName 'Fastfetch'
}

function Install-PSModules {
    $nuGet = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
    if (-not $nuGet) {
        Write-GuiLog "Installing NuGet package provider..." -Type Step
        try {
            Enable-Tls12
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

    if (-not $SettingsPath) { $SettingsPath = Get-WindowsTerminalSettingsPath }

    if (-not $SettingsPath) {
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
            Backup-WindowsTerminalSettings -SettingsPath $SettingsPath
            [System.IO.File]::WriteAllText($SettingsPath, ($settings | ConvertTo-Json -Depth 15), (New-Object System.Text.UTF8Encoding($false)))
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

function Install-Scoop {
    param([string[]]$Buckets = @())

    $existing = Get-Executable -Name 'scoop'
    if (-not $existing) {
        Write-GuiLog "Installing Scoop..." -Type Step
        try {
            Enable-Tls12
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
