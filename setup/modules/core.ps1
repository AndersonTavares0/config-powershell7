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
        [string]$OutFile,
        [long]$MinBytes = 1,
        [string]$Description = 'file'
    )
    Write-GuiLog "Downloading from $Url..." -Type Step
    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -ErrorAction Stop

        $fileItem = Get-Item $OutFile -ErrorAction SilentlyContinue
        if ($fileItem -and $fileItem.Length -ge $MinBytes) {
            $size = $fileItem.Length
            Write-GuiLog "Downloaded $([Math]::Round($size / 1KB, 1)) KB" -Type Ok
            return $true
        }

        $sizeText = if ($fileItem) { "$($fileItem.Length) bytes" } else { 'missing' }
        Write-GuiLog "Downloaded $Description appears invalid (size: $sizeText)." -Type Fail
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        return $false
    } catch {
        Write-GuiLog "Download failed: $($_.Exception.Message)" -Type Fail
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
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

function Test-DocumentsRedirected {
    $actualDocs = [Environment]::GetFolderPath('MyDocuments')
    $expectedDocs = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Documents'
    return $actualDocs -ne $expectedDocs
}

function Write-InstallSummary {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Results
    )

    if (-not $Results -or $Results.Count -eq 0) {
        Write-GuiLog 'No installation results to summarize.' -Type Warn
        return
    }

    $col1Width = 30
    $col2Width = 8
    $col3Width = 20

    foreach ($r in $Results) {
        $nameLen = $r.Name.Length
        $detailLen = $r.Detail.Length
        if ($nameLen -gt $col1Width) { $col1Width = $nameLen }
        if ($detailLen -gt $col3Width) { $col3Width = $detailLen }
    }

    $border = '+' + ('-' * ($col1Width + 2)) + '+' + ('-' * ($col2Width + 2)) + '+' + ('-' * ($col3Width + 2)) + '+'
    $sep    = '+' + ('-' * ($col1Width + 2)) + '+' + ('-' * ($col2Width + 2)) + '+' + ('-' * ($col3Width + 2)) + '+'
    $footer = '+' + ('-' * ($col1Width + 2)) + '+' + ('-' * ($col2Width + 2)) + '+' + ('-' * ($col3Width + 2)) + '+'

    $rowFmt = '| {0,-' + $col1Width + '} | {1,' + $col2Width + '} | {2,-' + $col3Width + '} |'

    Write-GuiLog '' -Type Info
    Write-GuiLog 'INSTALLATION SUMMARY' -Type Step
    Write-GuiLog $border -Type Info

    $header = $rowFmt -f 'Component', 'Status', 'Detail'
    Write-GuiLog $header -Type Info
    Write-GuiLog $sep -Type Info

    foreach ($r in $Results) {
        $statusIcon = switch ($r.Status) {
            'ok'   { '[OK]' }
            'fail' { '[FAIL]' }
            'skip' { '[SKIP]' }
            default { '[???]' }
        }
        $logType = switch ($r.Status) {
            'ok'   { 'Ok' }
            'fail' { 'Fail' }
            'skip' { 'Warn' }
            default { 'Info' }
        }
        $row = $rowFmt -f $r.Name, $statusIcon, $r.Detail
        Write-GuiLog $row -Type $logType
    }

    Write-GuiLog $footer -Type Info
    Write-GuiLog '' -Type Info
}
