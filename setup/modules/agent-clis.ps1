#Requires -Version 5.1
# Optional CLI installers for coding agents
# Load after core.ps1 and deps.ps1.

function Get-AgentCliInstallSpec {
    param([string]$Name)

    $specs = @(
        [PSCustomObject]@{
            Name = 'Antigravity'
            DisplayName = 'Google Antigravity CLI'
            Method = 'PowerShellScript'
            Source = 'https://antigravity.google/cli/install.ps1'
            Command = 'agy'
        }
        [PSCustomObject]@{
            Name = 'ClaudeCode'
            DisplayName = 'Claude Code'
            Method = 'PowerShellScript'
            Source = 'https://claude.ai/install.ps1'
            Command = 'claude'
        }
        [PSCustomObject]@{
            Name = 'Codex'
            DisplayName = 'OpenAI Codex CLI'
            Method = 'PowerShellScript'
            Source = 'https://chatgpt.com/codex/install.ps1'
            Command = 'codex'
        }
        [PSCustomObject]@{
            Name = 'OpenCode'
            DisplayName = 'OpenCode (requires Node.js)'
            Method = 'Npm'
            Package = 'opencode-ai'
            Command = 'opencode'
        }
    )

    if ($Name) {
        return $specs | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    }
    return $specs
}

function Get-AgentCliCommand {
    param([Parameter(Mandatory)][string]$Name)
    return Get-Command $Name -ErrorAction SilentlyContinue
}

function Invoke-OfficialPowerShellInstaller {
    param([Parameter(Mandatory)][PSCustomObject]$Spec)

    $installerPath = Join-Path $env:TEMP "config-powershell7-$($Spec.Name)-$([guid]::NewGuid().ToString('N')).ps1"
    try {
        Write-GuiLog "Downloading official $($Spec.DisplayName) installer from $($Spec.Source)." -Type Step
        if (-not (Get-FileFromUrl -Url $Spec.Source -OutFile $installerPath -MinBytes 100 -Description "$($Spec.DisplayName) installer")) {
            return $false
        }

        Unblock-File -LiteralPath $installerPath -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = 0
        & $installerPath 2>&1 | ForEach-Object { Write-GuiLog "$_" -Type Info }
        if ($LASTEXITCODE -ne 0) {
            Write-GuiLog "$($Spec.DisplayName) installer failed (exit code $LASTEXITCODE)." -Type Warn
            return $false
        }
        Update-ProcessPathFromUser
        $installed = Get-AgentCliCommand -Name $Spec.Command
        if (-not $installed) {
            Write-GuiLog "$($Spec.DisplayName) installer finished, but '$($Spec.Command)' is not available in PATH. Open a new terminal and check again." -Type Warn
            return $false
        }
        Write-GuiLog "$($Spec.DisplayName) is available as '$($Spec.Command)'." -Type Ok
        return $true
    } catch {
        Write-GuiLog "$($Spec.DisplayName) installation failed: $($_.Exception.Message)" -Type Warn
        return $false
    } finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

function Install-AgentCli {
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Force
    )

    $spec = Get-AgentCliInstallSpec -Name $Name
    if (-not $spec) {
        Write-GuiLog "Unknown agent CLI '$Name'." -Type Warn
        return $false
    }
    $existing = Get-AgentCliCommand -Name $spec.Command
    if ($existing -and -not $Force) {
        Write-GuiLog "$($spec.DisplayName) already available at $($existing.Source)." -Type Ok
        return $true
    }

    if ($spec.Method -eq 'PowerShellScript') {
        return Invoke-OfficialPowerShellInstaller -Spec $spec
    }

    if ($spec.Method -eq 'Npm') {
        $npm = Get-AgentCliCommand -Name 'npm'
        if (-not $npm) {
            Write-GuiLog "Node.js and npm are required for $($spec.DisplayName). Install Node.js, then retry." -Type Warn
            return $false
        }
        try {
            Write-GuiLog "Installing $($spec.DisplayName) with npm for the current user." -Type Step
            & $npm.Source install --global $spec.Package 2>&1 | ForEach-Object { Write-GuiLog "$_" -Type Info }
            if ($LASTEXITCODE -ne 0) {
                Write-GuiLog "npm failed to install $($spec.DisplayName) (exit code $LASTEXITCODE)." -Type Warn
                return $false
            }
            Update-ProcessPathFromUser
            $installed = Get-AgentCliCommand -Name $spec.Command
            if (-not $installed) {
                Write-GuiLog "$($spec.DisplayName) installed, but '$($spec.Command)' is not available in PATH. Open a new terminal and check again." -Type Warn
                return $false
            }
            Write-GuiLog "$($spec.DisplayName) installed at $($installed.Source)." -Type Ok
            return $true
        } catch {
            Write-GuiLog "$($spec.DisplayName) installation failed: $($_.Exception.Message)" -Type Warn
            return $false
        }
    }

    Write-GuiLog "Unsupported installer method '$($spec.Method)' for $($spec.DisplayName)." -Type Warn
    return $false
}
