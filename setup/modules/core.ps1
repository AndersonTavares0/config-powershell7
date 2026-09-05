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
$script:RepoZipUrl = "https://api.github.com/repos/$script:RepoOwner/$script:RepoName/releases/latest"

function Write-GuiLog {
    param(
        [string]$Message,
        [string]$Type = 'Info'
    )
    $syncHash = Get-Variable -Name SyncHash -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if ($syncHash) {
        $syncHash.LogMessages.Add(@{ Message = $Message; Type = $Type; Time = Get-Date })
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

function Enable-Tls12 {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $current = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = $current -bor [System.Net.SecurityProtocolType]::Tls12
    }
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
        Enable-Tls12
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
    $extractDir = $null
    $previousDir = $null
    $movedPrevious = $false

    try {
        $TargetDir = [System.IO.Path]::GetFullPath($TargetDir)
        $parentDir = Split-Path $TargetDir -Parent
        $id = [guid]::NewGuid().ToString('N')
        $extractDir = Join-Path $parentDir ".$($script:RepoName)-stage-$id"
        $previousDir = Join-Path $parentDir ".$($script:RepoName)-previous-$id"
        Enable-Tls12
        $release = Invoke-RestMethod -Uri $script:RepoZipUrl -ErrorAction Stop
        if (-not $release.tag_name -or -not $release.zipball_url) {
            throw 'Latest GitHub release metadata is incomplete.'
        }
        $ok = Get-FileFromUrl -Url $release.zipball_url -OutFile $zipPath
        if (-not $ok) { return $false }

        Write-GuiLog "Extracting to $TargetDir..." -Type Step
        if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Force -Path $parentDir | Out-Null }
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

        $innerDir = Get-ChildItem $extractDir -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $innerDir -or -not (Test-Path (Join-Path $innerDir.FullName 'Microsoft.PowerShell_profile.ps1'))) {
            throw 'Downloaded release does not contain a valid profile repository.'
        }
        Set-Content -Path (Join-Path $innerDir.FullName '.config-powershell7-version') -Value $release.tag_name -Encoding ASCII
        if (Test-Path $TargetDir) {
            Move-Item $TargetDir $previousDir -Force
            $movedPrevious = $true
        }
        Move-Item $innerDir.FullName $TargetDir -Force

        # Unblock downloaded files to avoid ExecutionPolicy errors
        Write-GuiLog "Unblocking script files..." -Type Step
        Get-ChildItem -Path $TargetDir -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
        Write-GuiLog "Files unblocked." -Type Ok

        if (Test-Path (Join-Path $TargetDir 'Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue) {
            if ($movedPrevious -and (Test-Path $previousDir)) {
                Remove-Item $previousDir -Recurse -Force
                $movedPrevious = $false
            }
            Write-GuiLog "Repository ready at: $TargetDir" -Type Ok
            return $true
        }
        Write-GuiLog "Extraction succeeded but profile not found at: $TargetDir" -Type Fail
        return $false
    } catch {
        Write-GuiLog "Extraction failed: $($_.Exception.Message)" -Type Fail
        if ($movedPrevious -and (Test-Path $previousDir)) {
            if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue }
            Move-Item $previousDir $TargetDir -Force -ErrorAction SilentlyContinue
            $movedPrevious = $false
        }
        return $false
    } finally {
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        if ($extractDir) { Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
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
