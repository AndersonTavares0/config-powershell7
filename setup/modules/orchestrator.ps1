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
        $step = 0
        $totalSteps = 1
        if ($InstallPS7)    { $totalSteps++ }
        if ($InstallGit)    { $totalSteps++ }
        if ($InstallOMP)    { $totalSteps++ }
        if ($InstallZoxide) { $totalSteps++ }
        if ($InstallFont)   { $totalSteps++ }
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
            $null = Install-PowerShell7
        }

        if ($InstallGit) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking Git..." -Type Step
            $null = Install-Git
        }

        if ($InstallOMP) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking Oh My Posh..." -Type Step
            $null = Install-OhMyPosh
        }

        if ($InstallZoxide) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking Zoxide..." -Type Step
            $null = Install-Zoxide
        }

        if ($InstallFont) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Checking FiraCode Nerd Font..." -Type Step
            $null = Install-NerdFont
        }

        if ($InstallModules) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Installing PowerShell modules..." -Type Step
            Install-PSModules
        }

        $step++
        Write-GuiLog "[$step/$totalSteps] Configuring profile..." -Type Step
        $null = Install-Profile -RepoPath $RepoPath

        if ($InstallAlacritty) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Installing Alacritty..." -Type Step
            $null = Install-Alacritty
        }

        if ($InstallChocolatey) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Installing Chocolatey..." -Type Step
            $chocoSources = if ($ChocolateySources) { $ChocolateySources -split ',' | ForEach-Object { $_.Trim() } } else { @() }
            $null = Install-Chocolatey -Sources $chocoSources
        }

        if ($InstallScoop) {
            $step++
            Write-GuiLog "[$step/$totalSteps] Installing Scoop..." -Type Step
            $buckets = if ($ScoopBuckets) { $ScoopBuckets -split ',' | ForEach-Object { $_.Trim() } } else { @() }
            $null = Install-Scoop -Buckets $buckets
        }

        Write-GuiLog '' -Type Info
        Write-GuiLog 'INSTALLATION COMPLETE' -Type Step
        Write-GuiLog '' -Type Info
        Write-GuiLog "Profile:  $(Get-ProfilePath)" -Type Info
        Write-GuiLog "Repo:     $RepoPath" -Type Info
        Write-GuiLog '' -Type Info
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
