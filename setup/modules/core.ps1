#Requires -Version 5.1
# Core: platform detection, constants, logging, repo download

if (-not (Get-Variable -Name 'IsWin' -Scope Script -ErrorAction SilentlyContinue)) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $script:IsWin = $IsWindows
        $script:IsLnx = $IsLinux
        $script:IsMac = $IsMacOS
    } else {
        $script:IsWin = $true
        $script:IsLnx = $false
        $script:IsMac = $false
    }
}

$script:RepoOwner  = 'AndersonTavares0'
$script:RepoName   = 'config-powershell7'
$script:RepoBranch = 'main'
$script:RepoZipUrl = "https://github.com/$script:RepoOwner/$script:RepoName/archive/refs/heads/$script:RepoBranch.zip"

function Write-GuiLog {
    param(
        [string]$Message,
        [string]$Type = 'Info'
    )
    if ($script:SyncHash) {
        $script:SyncHash.LogMessages.Add(@{ Message = $Message; Type = $Type; Time = Get-Date })
    }
    $prefix = switch ($Type) {
        'Ok'   { '[OK]' }
        'Warn' { '[WARN]' }
        'Fail' { '[FAIL]' }
        'Step' { '[>>]' }
        default { '[--]' }
    }
    Write-Host "$prefix $Message"
}

function Get-WingetPath {
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    $winApps = Join-Path $localAppData 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path $winApps -ErrorAction SilentlyContinue) { return $winApps }

    $programFiles = Join-Path $env:ProgramFiles 'WindowsApps'
    if (Test-Path $programFiles -ErrorAction SilentlyContinue) {
        $wingetAlt = Get-ChildItem $programFiles -Filter 'winget.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wingetAlt) { return $wingetAlt.FullName }
    }
    return $null
}

function Get-FileFromUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )
    Write-GuiLog "Downloading from $Url..." -Type Step
    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -ErrorAction Stop
        if (Test-Path $OutFile -ErrorAction SilentlyContinue) {
            $fileItem = Get-Item $OutFile -ErrorAction SilentlyContinue
            if ($fileItem) {
                $size = $fileItem.Length
                Write-GuiLog "Downloaded $([Math]::Round($size / 1KB, 1)) KB" -Type Ok
                return $true
            }
        }
        Write-GuiLog "Downloaded file not found: $OutFile" -Type Fail
        return $false
    } catch {
        Write-GuiLog "Download failed: $($_.Exception.Message)" -Type Fail
        return $false
    }
}

function Download-Repo {
    param([string]$TargetDir)

    $zipPath = Join-Path $env:TEMP "$($script:RepoName)-archive.zip"
    $extractDir = Join-Path $env:TEMP "$($script:RepoName)-extract"

    $ok = Get-FileFromUrl -Url $script:RepoZipUrl -OutFile $zipPath
    if (-not $ok) {
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        return $false
    }

    try {
        Write-GuiLog "Extracting to $TargetDir..." -Type Step

        if (Test-Path $extractDir -ErrorAction SilentlyContinue) {
            Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $TargetDir -ErrorAction SilentlyContinue) {
            Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

        $innerDir = Get-ChildItem $extractDir -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $innerDir) {
            Write-GuiLog "Extraction failed: no directory found in archive" -Type Fail
            return $false
        }
        Move-Item $innerDir.FullName $TargetDir -Force

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

        # Unblock downloaded files to avoid ExecutionPolicy errors
        Write-GuiLog "Unblocking script files..." -Type Step
        Get-ChildItem -Path $TargetDir -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
        Write-GuiLog "Files unblocked." -Type Ok

        if (Test-Path (Join-Path $TargetDir 'Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue) {
            Write-GuiLog "Repository ready at: $TargetDir" -Type Ok
            return $true
        }
        Write-GuiLog "Extraction succeeded but profile not found at: $TargetDir" -Type Fail
        return $false
    } catch {
        Write-GuiLog "Extraction failed: $($_.Exception.Message)" -Type Fail
        return $false
    }
}
