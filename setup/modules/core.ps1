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

if ($script:IsWin) {
    $script:IsAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} else {
    $script:IsAdmin = ((id -u 2>$null) -eq '0')
}

$script:RepoOwner  = 'AndersonTavares0'
$script:RepoName   = 'config-powershell7'
$script:RepoZipUrl = "https://api.github.com/repos/$script:RepoOwner/$script:RepoName/releases/latest"

if (-not (Get-Variable -Name InstallerNonInteractive -Scope Script -ErrorAction SilentlyContinue)) {
    $script:InstallerNonInteractive = $false
}

function Test-InstallerInteractive {
    return $Host.Name -eq 'ConsoleHost' -and -not $script:InstallerNonInteractive -and
        -not $env:CI -and -not [Console]::IsInputRedirected
}

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
    if (Test-Path $winApps -PathType Leaf) { return $winApps }

    # Targeted, not recursive: WindowsApps holds thousands of files and denies
    # enumeration to non-elevated users, so a -Recurse scan there stalls and finds nothing.
    if ($env:ProgramFiles) {
        $packageGlob = Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe'
        $wingetAlt = Get-Item -Path $packageGlob -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($wingetAlt) { return $wingetAlt.FullName }
    }
    return $null
}

function Get-InstallerEnvironment {
    $architecture = if ($env:PROCESSOR_ARCHITEW6432) {
        $env:PROCESSOR_ARCHITEW6432
    } else {
        $env:PROCESSOR_ARCHITECTURE
    }
    $wingetPath = Get-WingetPath
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    $node = Get-Command node -ErrorAction SilentlyContinue
    $npm = Get-Command npm -ErrorAction SilentlyContinue

    return [PSCustomObject]@{
        OSVersion        = [Environment]::OSVersion.Version
        Architecture     = $architecture
        Is64Bit          = [Environment]::Is64BitOperatingSystem
        PowerShellVersion = $PSVersionTable.PSVersion
        IsAdministrator  = $script:IsAdmin
        HasWinGet        = [bool]$wingetPath
        HasScoop         = [bool]$scoop
        HasNode          = [bool]$node
        HasNpm           = [bool]$npm
    }
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
    # Progress rendering makes Invoke-WebRequest an order of magnitude slower on PS 5.1.
    $previousProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Enable-Tls12
        # -UseBasicParsing: PS 5.1 otherwise needs the Internet Explorer engine, which
        # is absent or blocked by its first-run prompt on clean Windows installs.
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop

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
    } finally {
        $ProgressPreference = $previousProgress
    }
}

function Test-RepositoryLayout {
    param([string]$Path)
    foreach ($requiredFile in @('Microsoft.PowerShell_profile.ps1', 'modules/config/config.ps1', 'setup/setup.ps1', 'lib/executable.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Path $requiredFile) -PathType Leaf)) { return $false }
    }
    return $true
}

function Download-Repo {
    param([string]$TargetDir)

    $zipPath = Join-Path ([IO.Path]::GetTempPath()) "$($script:RepoName)-$([guid]::NewGuid().ToString('N')).zip"
    $extractDir = $null
    $previousDir = $null
    $movedPrevious = $false

    try {
        $TargetDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetDir)
        if ((Test-Path -LiteralPath $TargetDir) -and -not (Test-RepositoryLayout $TargetDir)) {
            throw 'Refusing to replace an unrelated directory. Select a new installation directory.'
        }
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
        if (-not $innerDir -or -not (Test-RepositoryLayout $innerDir.FullName)) {
            throw 'Downloaded release does not contain a valid profile repository.'
        }
        Set-Content -Path (Join-Path $innerDir.FullName '.config-powershell7-version') -Value $release.tag_name -Encoding ASCII
        if (Test-Path -LiteralPath $TargetDir) {
            Move-Item -LiteralPath $TargetDir -Destination $previousDir -Force -ErrorAction Stop
            $movedPrevious = $true
        }
        Move-Item -LiteralPath $innerDir.FullName -Destination $TargetDir -Force -ErrorAction Stop

        # Unblock downloaded files to avoid ExecutionPolicy errors
        Write-GuiLog "Unblocking script files..." -Type Step
        Get-ChildItem -LiteralPath $TargetDir -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
        Write-GuiLog "Files unblocked." -Type Ok

        if (Test-RepositoryLayout $TargetDir) {
            if ($movedPrevious) { Write-GuiLog "Previous repository retained for recovery: $previousDir" -Type Warn }
            $movedPrevious = $false
            Write-GuiLog "Repository ready at: $TargetDir" -Type Ok
            return $true
        }
        throw "Activated repository failed validation: $TargetDir"
    } catch {
        Write-GuiLog "Extraction failed: $($_.Exception.Message)" -Type Fail
        if ($movedPrevious -and (Test-Path -LiteralPath $previousDir)) {
            if (Test-Path -LiteralPath $TargetDir) { Remove-Item -LiteralPath $TargetDir -Recurse -Force -ErrorAction Stop }
            Move-Item -LiteralPath $previousDir -Destination $TargetDir -Force -ErrorAction Stop
            $movedPrevious = $false
        }
        return $false
    } finally {
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        if ($extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
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
