#Requires -Version 5.1
# Install/uninstall orchestrators

function Start-ProfileInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [bool]$InstallPS7 = $true,
        [bool]$InstallGit = $true,
        [bool]$InstallOMP = $true,
        [bool]$InstallZoxide = $true,
        [bool]$InstallFont = $true,
        [bool]$InstallModules = $true,
        [bool]$InstallAlacritty = $false,
        [bool]$InstallChocolatey = $false,
        [string]$ChocolateySources = '',
        [bool]$InstallScoop = $false,
        [string]$ScoopBuckets = ''
    )

    try {
        $results = @()

        $script:results = @()

        function Add-Result {
            param([string]$Name, [bool]$Success, [string]$Detail, [string]$Status = '')
            if ($Status) {
                $finalStatus = $Status
            } elseif ($Success) {
                $finalStatus = 'ok'
            } else {
                $finalStatus = 'fail'
            }
            $script:results += @{
                Name   = $Name
                Status = $finalStatus
                Detail = $Detail
            }
        }

        $repoExists = Test-Path (Join-Path $RepoPath 'Microsoft.PowerShell_profile.ps1')
        Add-Result -Name 'Repository' -Success $repoExists -Detail $(if ($repoExists) { $RepoPath } else { 'not found' })

        $step = 0
        $totalSteps = 1
        if ($InstallPS7)    { $totalSteps++ }
        if ($InstallGit)    { $totalSteps++ }
        if ($InstallOMP)    { $totalSteps++ }
        if ($InstallZoxide) { $totalSteps++ }
        if ($InstallFont)   { $totalSteps += 2 }
        if ($InstallModules) { $totalSteps++ }
        $totalSteps++
        if ($InstallAlacritty)   { $totalSteps++ }
        if ($InstallChocolatey)  { $totalSteps++ }
        if ($InstallScoop)       { $totalSteps++ }

        Write-GuiLog '' -Type Info
        Write-GuiLog 'STARTING INSTALLATION' -Type Step
        Write-GuiLog '' -Type Info

        $step++
        Write-GuiLog "[$step/$totalSteps] Setting ExecutionPolicy..." -Type Step
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
        if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
            Write-GuiLog 'ExecutionPolicy set to RemoteSigned.' -Type Ok
        } else {
            Write-GuiLog "ExecutionPolicy: $currentPolicy (OK)." -Type Ok
        }

        if ($InstallPS7) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking PowerShell 7..." -Type Step
            $r = Install-PowerShell7
            $exe = Get-Executable -Name 'pwsh'
            $detail = if ($exe -and $exe.Version) { $exe.Version } elseif ($r) { 'installed' } else { 'failed' }
            Add-Result -Name 'PowerShell 7' -Success $r -Detail $detail
        } else {
            Add-Result -Name 'PowerShell 7' -Success $false -Detail 'not selected' -Status 'skip'
        }

        if ($InstallGit) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking Git..." -Type Step
            $r = Install-Git
            $exe = Get-Executable -Name 'git'
            $detail = if ($exe -and $exe.Version) { $exe.Version } elseif ($r) { 'installed' } else { 'failed' }
            Add-Result -Name 'Git' -Success $r -Detail $detail
        } else {
            Add-Result -Name 'Git' -Success $false -Detail 'not selected' -Status 'skip'
        }

        if ($InstallOMP) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking Oh My Posh..." -Type Step
            $r = Install-OhMyPosh
            $exe = Get-Executable -Name 'oh-my-posh'
            $detail = if ($exe -and $exe.Version) { $exe.Version } elseif ($r) { 'installed' } else { 'failed' }
            Add-Result -Name 'Oh My Posh' -Success $r -Detail $detail
        } else {
            Add-Result -Name 'Oh My Posh' -Success $false -Detail 'not selected' -Status 'skip'
        }

        if ($InstallZoxide) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking Zoxide..." -Type Step
            $r = Install-Zoxide
            $exe = Get-Executable -Name 'zoxide'
            $detail = if ($exe -and $exe.Version) { $exe.Version } elseif ($r) { 'installed' } else { 'failed' }
            Add-Result -Name 'Zoxide' -Success $r -Detail $detail
        } else {
            Add-Result -Name 'Zoxide' -Success $false -Detail 'not selected' -Status 'skip'
        }

        if ($InstallFont) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking FiraCode Nerd Font..." -Type Step
            $rFont = Install-NerdFont
            Add-Result -Name 'FiraCode Nerd Font' -Success $rFont -Detail $(if ($rFont) { 'installed' } else { 'failed' })
            $step++
            Write-GuiLog "[$step/$totalSteps] Configuring Windows Terminal font..." -Type Step
            $rWt = Set-WindowsTerminalFont
            Add-Result -Name 'Windows Terminal font' -Success $rWt -Detail $(if ($rWt) { 'configured' } else { 'not found' })
        } else {
            Add-Result -Name 'FiraCode Nerd Font' -Success $false -Detail 'not selected' -Status 'skip'
            Add-Result -Name 'Windows Terminal font' -Success $false -Detail 'not selected' -Status 'skip'
        }

        if ($InstallModules) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Installing PowerShell modules..." -Type Step
            $rMods = Install-PSModules
            $modDetails = @()
            foreach ($modName in @('PSReadLine', 'Terminal-Icons')) {
                $m = Get-Module -ListAvailable -Name $modName -ErrorAction SilentlyContinue |
                    Sort-Object Version -Descending | Select-Object -First 1
                if ($m) { $modDetails += "$($modName) $($m.Version)" }
            }
            $detail = if ($modDetails.Count -gt 0) { $modDetails -join ', ' } elseif ($rMods) { 'installed' } else { 'failed' }
            Add-Result -Name 'PowerShell Modules' -Success $rMods -Detail $detail
        } else {
            Add-Result -Name 'PowerShell Modules' -Success $false -Detail 'not selected' -Status 'skip'
        }

        $step++
        Write-GuiLog "[$step/$totalSteps] Configuring profile..." -Type Step
        $rProfile = Install-Profile -RepoPath $RepoPath
        Add-Result -Name 'Profile' -Success $rProfile -Detail $(if ($rProfile) { 'linked' } else { 'failed' })

        if ($InstallAlacritty) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Installing Alacritty..." -Type Step
            $rAlac = Install-Alacritty
            $exe = Get-Executable -Name 'alacritty'
            $detail = if ($exe -and $exe.Version) { $exe.Version } elseif ($rAlac) { 'installed' } else { 'failed' }
            Add-Result -Name 'Alacritty' -Success $rAlac -Detail $detail
        } else {
            Add-Result -Name 'Alacritty' -Success $false -Detail 'not selected' -Status 'skip'
        }

        if ($InstallChocolatey) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Installing Chocolatey..." -Type Step
            $chocoSources = if ($ChocolateySources) { $ChocolateySources -split ',' | ForEach-Object { $_.Trim() } } else { @() }
            $rChoco = Install-Chocolatey -Sources $chocoSources
            $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
            $detail = if ($chocoCmd) { $chocoCmd.Source } elseif ($rChoco) { 'installed' } else { 'failed' }
            Add-Result -Name 'Chocolatey' -Success $rChoco -Detail $detail
        } else {
            Add-Result -Name 'Chocolatey' -Success $false -Detail 'not selected' -Status 'skip'
        }

        if ($InstallScoop) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Installing Scoop..." -Type Step
            $buckets = if ($ScoopBuckets) { $ScoopBuckets -split ',' | ForEach-Object { $_.Trim() } } else { @() }
            $rScoop = Install-Scoop -Buckets $buckets
            $exe = Get-Executable -Name 'scoop'
            $detail = if ($exe -and $exe.Version) { $exe.Version } elseif ($rScoop) { 'installed' } else { 'failed' }
            Add-Result -Name 'Scoop' -Success $rScoop -Detail $detail
        } else {
            Add-Result -Name 'Scoop' -Success $false -Detail 'not selected' -Status 'skip'
        }

        Write-GuiLog '' -Type Info
        Write-GuiLog 'INSTALLATION COMPLETE' -Type Step
        Write-GuiLog '' -Type Info
        Write-GuiLog "Profile:  $(Get-ProfilePath)" -Type Info
        Write-GuiLog "Repo:     $RepoPath" -Type Info
        Write-GuiLog '' -Type Info

        $tools = @('pwsh', 'git', 'oh-my-posh', 'zoxide')
        $versions = @()
        foreach ($tool in $tools) {
            $e = Get-Executable -Name $tool
            if ($e -and $e.Version) {
                $versions += "$($e.Name) $($e.Version)"
            }
        }
        if ($versions.Count -gt 0) {
            Write-GuiLog ($versions -join ' · ') -Type Info
            Write-GuiLog '' -Type Info
        }

        Write-GuiLog 'Restart your terminal to apply all changes!' -Type Ok

        $sync = Get-Variable -Name SyncHash -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($sync) { $sync.InstallComplete = $true }

    } catch {
        Write-GuiLog "CRITICAL ERROR: $($_.Exception.Message)" -Type Fail
        $sync = Get-Variable -Name SyncHash -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($sync) { $sync.InstallComplete = $true; $sync.InstallFailed = $true }
    }
}

function Start-ProfileUninstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    try {
        Write-GuiLog '' -Type Info
        Write-GuiLog 'STARTING UNINSTALL' -Type Step
        Write-GuiLog '' -Type Info

        $null = Uninstall-Profile -RepoPath $RepoPath

        Write-GuiLog '' -Type Info
        Write-GuiLog 'UNINSTALL COMPLETE' -Type Step
        Write-GuiLog '' -Type Info
        Write-GuiLog 'Manual cleanup (optional):' -Type Info
        Write-GuiLog '  Uninstall-Module Terminal-Icons -Force' -Type Info
        Write-GuiLog '  Uninstall-Module PSReadLine -Force' -Type Info
        Write-GuiLog '  winget uninstall JanDeDobbeleer.OhMyPosh' -Type Info
        Write-GuiLog '  winget uninstall ajeetdsouza.zoxide' -Type Info
        Write-GuiLog '  winget uninstall Git.Git' -Type Info

        $sync = Get-Variable -Name SyncHash -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($sync) { $sync.InstallComplete = $true }

    } catch {
        Write-GuiLog "ERROR: $($_.Exception.Message)" -Type Fail
        $sync = Get-Variable -Name SyncHash -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($sync) { $sync.InstallComplete = $true; $sync.InstallFailed = $true }
    }
}
