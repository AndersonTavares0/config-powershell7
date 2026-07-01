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
        return
    }

    try {
        $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        if (-not $settings.profiles) {
            Write-GuiLog "Windows Terminal settings has no profiles section." -Type Warn
            return
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
    } catch {
        Write-GuiLog "Could not configure Windows Terminal font: $($_.Exception.Message)" -Type Warn
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
    } else {
        Write-GuiLog "Alacritty not found after install attempt." -Type Warn
    }
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
        $chocoInstall = Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing -ErrorAction Stop
        Invoke-Expression $chocoInstall.Content

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
            $scoopInstall = Invoke-RestMethod -Uri 'https://get.scoop.sh' -ErrorAction Stop
            Invoke-Expression $scoopInstall

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
