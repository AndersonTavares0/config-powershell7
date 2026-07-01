#Requires -Version 5.1
# WPF GUI

function Show-Gui {
    param(
        [string]$SetupDir,
        [string]$RepoPath
    )

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    $xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="PowerShell 7 Profile Setup"
    Width="680" Height="780"
    MinWidth="600" MinHeight="600"
    WindowStartupLocation="CenterScreen"
    ResizeMode="CanResize"
    Background="#1E1E2E"
    Foreground="#CDD6F4">

    <Window.Resources>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Width" Value="260"/>
            <Setter Property="Height" Value="60"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="#1E1E2E"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="8"
                                Padding="20,12">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="LogTextBox" TargetType="RichTextBox">
            <Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="Background" Value="#181825"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#313244"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
        </Style>
    </Window.Resources>

    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="PowerShell 7 Profile Setup"
                   FontSize="28" FontWeight="Bold"
                   Foreground="#CBA6F7"
                   HorizontalAlignment="Center"
                   Margin="0,0,0,4"/>

        <TextBlock Grid.Row="1" Text="One-click install/remove - all dependencies included"
                   FontSize="13"
                   Foreground="#A6ADC8"
                   HorizontalAlignment="Center"
                   Margin="0,0,0,20"/>

        <StackPanel Grid.Row="2" Orientation="Horizontal"
                    HorizontalAlignment="Center" Margin="0,0,0,12">
            <Button x:Name="BtnInstall"
                    Style="{StaticResource PrimaryButton}"
                    Background="#A6E3A1"
                    Content="Install All"
                    Margin="0,0,12,0"/>
            <Button x:Name="BtnRemove"
                    Style="{StaticResource PrimaryButton}"
                    Background="#F38BA8"
                    Content="Remove Profile"
                    Margin="12,0,0,0"/>
        </StackPanel>

        <StackPanel Grid.Row="3" Margin="0,0,0,8">
            <TextBlock Text="Repository location:" FontSize="11" Foreground="#6C7086" Margin="0,0,0,2"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="TxtRepoPath" Grid.Column="0"
                         Background="#313244" Foreground="#CDD6F4"
                         BorderBrush="#45475A" BorderThickness="1"
                         FontFamily="Consolas" FontSize="12"
                         Padding="8,6"/>
                <Button x:Name="BtnBrowse" Grid.Column="1"
                        Content="Browse..."
                        Width="70" Height="30"
                        FontSize="11"
                        Foreground="#CDD6F4" Background="#45475A"
                        BorderThickness="0" Margin="6,0,0,0"
                        Cursor="Hand"/>
            </Grid>
        </StackPanel>

        <StackPanel Grid.Row="4" Margin="0,8,0,8">
            <CheckBox x:Name="ChkPS7" IsChecked="True"
                      Foreground="#CDD6F4" FontSize="12" Margin="0,0,0,3">
                Install PowerShell 7 (latest)
            </CheckBox>
            <CheckBox x:Name="ChkGit" IsChecked="True"
                      Foreground="#CDD6F4" FontSize="12" Margin="0,0,0,3">
                Install Git
            </CheckBox>
            <CheckBox x:Name="ChkOMP" IsChecked="True"
                      Foreground="#CDD6F4" FontSize="12" Margin="0,0,0,3">
                Install Oh My Posh (prompt themes)
            </CheckBox>
            <CheckBox x:Name="ChkZoxide" IsChecked="True"
                      Foreground="#CDD6F4" FontSize="12" Margin="0,0,0,3">
                Install Zoxide (smart cd)
            </CheckBox>
            <CheckBox x:Name="ChkFont" IsChecked="True"
                      Foreground="#CDD6F4" FontSize="12" Margin="0,0,0,3">
                Install FiraCode Nerd Font
            </CheckBox>
            <CheckBox x:Name="ChkModules" IsChecked="True"
                      Foreground="#CDD6F4" FontSize="12">
                Install PS modules (PSReadLine, Terminal-Icons)
            </CheckBox>
            <CheckBox x:Name="ChkAlacritty" IsChecked="False"
                      Foreground="#CDD6F4" FontSize="12" Margin="0,6,0,3">
                Install Alacritty terminal + config (Catppuccin Mocha theme)
            </CheckBox>
            <CheckBox x:Name="ChkChoco" IsChecked="False"
                      Foreground="#CDD6F4" FontSize="12" Margin="0,6,0,3">
                Install Chocolatey package manager
            </CheckBox>
            <StackPanel Orientation="Horizontal" Margin="20,0,0,3">
                <TextBlock Text="Sources (comma-separated URLs):" FontSize="10" Foreground="#585B70" VerticalAlignment="Center" Margin="0,0,6,0"/>
                <TextBox x:Name="TxtChocoSources" Width="300"
                         Background="#313244" Foreground="#CDD6F4"
                         BorderBrush="#45475A" BorderThickness="1"
                         FontFamily="Consolas" FontSize="10"
                         Padding="4,2"/>
            </StackPanel>
            <CheckBox x:Name="ChkScoop" IsChecked="False"
                      Foreground="#CDD6F4" FontSize="12" Margin="0,6,0,3">
                Install Scoop package manager
            </CheckBox>
            <StackPanel Orientation="Horizontal" Margin="20,0,0,8">
                <TextBlock Text="Buckets (comma-separated):" FontSize="10" Foreground="#585B70" VerticalAlignment="Center" Margin="0,0,6,0"/>
                <TextBox x:Name="TxtScoopBuckets" Width="300" Text="extras, versions, nerd-fonts"
                         Background="#313244" Foreground="#CDD6F4"
                         BorderBrush="#45475A" BorderThickness="1"
                         FontFamily="Consolas" FontSize="10"
                         Padding="4,2"/>
            </StackPanel>
        </StackPanel>

        <Grid Grid.Row="5" Margin="0,4,0,6">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtStatus" Grid.Column="0"
                       Text="Ready."
                       FontSize="12" Foreground="#A6ADC8"
                       VerticalAlignment="Center"/>
            <TextBlock x:Name="TxtProgress" Grid.Column="1"
                       Text=""
                       FontSize="11" Foreground="#6C7086"
                       VerticalAlignment="Center"/>
        </Grid>

        <Border Grid.Row="6" CornerRadius="6">
            <RichTextBox x:Name="TxtLog"
                         Style="{StaticResource LogTextBox}"/>
        </Border>

        <StackPanel Grid.Row="7" Orientation="Horizontal"
                    HorizontalAlignment="Right" Margin="0,10,0,0">
            <TextBlock Text="Invoke via irm: "
                       FontSize="10" Foreground="#6C7086"
                       VerticalAlignment="Center"/>
            <TextBlock Text="irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex"
                       FontSize="10" Foreground="#585B70"
                       FontFamily="Consolas"
                       VerticalAlignment="Center"/>
        </StackPanel>
    </Grid>
</Window>
'@

    $reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $btnInstall      = $window.FindName('BtnInstall')
    $btnRemove       = $window.FindName('BtnRemove')
    $txtRepoPath     = $window.FindName('TxtRepoPath')
    $btnBrowse       = $window.FindName('BtnBrowse')
    $txtLog          = $window.FindName('TxtLog')
    $txtStatus       = $window.FindName('TxtStatus')
    $txtProgress     = $window.FindName('TxtProgress')
    $chkPS7          = $window.FindName('ChkPS7')
    $chkGit          = $window.FindName('ChkGit')
    $chkOMP          = $window.FindName('ChkOMP')
    $chkZoxide       = $window.FindName('ChkZoxide')
    $chkFont         = $window.FindName('ChkFont')
    $chkModules      = $window.FindName('ChkModules')
    $chkAlacritty    = $window.FindName('ChkAlacritty')
    $chkChoco        = $window.FindName('ChkChoco')
    $txtChocoSources = $window.FindName('TxtChocoSources')
    $chkScoop        = $window.FindName('ChkScoop')
    $txtScoopBuckets = $window.FindName('TxtScoopBuckets')

    $txtRepoPath.Text = $RepoPath

    $script:SyncHash = [hashtable]::Synchronized(@{
        LogMessages     = [System.Collections.Generic.List[object]]::new()
        InstallComplete = $false
        InstallFailed   = $false
        IsRunning       = $false
        Progress        = ''
    })

    $bc = [System.Windows.Media.BrushConverter]::new()
    $colors = @{
        Ok   = $bc.ConvertFromString('#A6E3A1')
        Warn = $bc.ConvertFromString('#F9E2AF')
        Fail = $bc.ConvertFromString('#F38BA8')
        Step = $bc.ConvertFromString('#89B4FA')
        Info = $bc.ConvertFromString('#BAC2DE')
        Time = $bc.ConvertFromString('#585B70')
    }

    $logIndex = 0
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(150)
    $timer.Add_Tick({
        $sync = $script:SyncHash
        while ($logIndex -lt $sync.LogMessages.Count) {
            $entry = $sync.LogMessages[$logIndex]
            $timeStr = $entry.Time.ToString('HH:mm:ss')
            $paragraph = New-Object System.Windows.Documents.Paragraph
            $paragraph.Margin = New-Object System.Windows.Thickness(0)
            $paragraph.LineHeight = 2
            $timeRun = New-Object System.Windows.Documents.Run("[${timeStr}] ")
            $timeRun.Foreground = $colors.Time
            $paragraph.Inlines.Add($timeRun)
            $msgRun = New-Object System.Windows.Documents.Run($entry.Message)
            $msgRun.Foreground = $colors[$entry.Type]
            $paragraph.Inlines.Add($msgRun)
            $txtLog.Document.Blocks.Add($paragraph)
            $logIndex++
        }
        $txtLog.ScrollToEnd()
        if ($sync.Progress) { $txtProgress.Text = $sync.Progress }

        if ($sync.InstallComplete) {
            $timer.Stop()
            if ($sync.InstallFailed) {
                $txtStatus.Text = 'Completed with errors. Check log above.'
                $txtStatus.Foreground = $colors.Fail
            } else {
                $txtStatus.Text = 'Done! Restart your terminal to apply changes.'
                $txtStatus.Foreground = $colors.Ok
            }
            foreach ($ctrl in @($btnInstall, $btnRemove, $btnBrowse, $txtRepoPath,
                $chkPS7, $chkGit, $chkOMP, $chkZoxide, $chkFont, $chkModules,
                $chkAlacritty, $chkChoco, $txtChocoSources, $chkScoop, $txtScoopBuckets)) {
                $ctrl.IsEnabled = $true
            }
            $script:SyncHash.IsRunning = $false
        }
    })

    $btnInstall.Add_Click({
        if ($script:SyncHash.IsRunning) {
            [System.Windows.MessageBox]::Show($window, 'An operation is already in progress.', 'Busy', 'OK', 'Information')
            return
        }
        $repoPath = $txtRepoPath.Text.Trim()
        if (-not $repoPath) {
            [System.Windows.MessageBox]::Show($window, 'Please specify a repository path.', 'Path required', 'OK', 'Warning')
            return
        }

        foreach ($ctrl in @($btnInstall, $btnRemove, $btnBrowse, $txtRepoPath,
            $chkPS7, $chkGit, $chkOMP, $chkZoxide, $chkFont, $chkModules,
            $chkAlacritty, $chkChoco, $txtChocoSources, $chkScoop, $txtScoopBuckets)) {
            $ctrl.IsEnabled = $false
        }
        $script:SyncHash.InstallComplete = $false
        $script:SyncHash.InstallFailed = $false
        $script:SyncHash.IsRunning = $true
        $script:SyncHash.LogMessages.Clear()
        $logIndex = 0
        $txtLog.Document.Blocks.Clear()
        $txtStatus.Text = 'Installing...'
        $txtStatus.Foreground = $colors.Warn
        $txtProgress.Text = ''
        $timer.Start()

        $needDownload = -not (Test-Path (Join-Path $repoPath 'Microsoft.PowerShell_profile.ps1'))

        $ps = [PowerShell]::Create()
        $ps.AddScript({
            param($SetupDir, $RepoPath, $NeedDownload, $SyncHash, $RepoZipUrl, $RepoName, $Params, $ProfilePath)

            $script:SyncHash = $SyncHash
            $script:RepoZipUrl = $RepoZipUrl
            $script:RepoName = $RepoName
            $global:PROFILE = $ProfilePath

            . (Join-Path $SetupDir '../lib/executable.ps1')
            . (Join-Path $SetupDir 'modules/core.ps1')
            . (Join-Path $SetupDir 'modules/deps.ps1')
            . (Join-Path $SetupDir 'modules/profile.ps1')
            . (Join-Path $SetupDir 'modules/orchestrator.ps1')

            if ($NeedDownload) {
                Download-Repo -TargetDir $RepoPath
            }

            Start-ProfileInstall @Params
        })

        $ps.AddParameter('SetupDir', $SetupDir)
        $ps.AddParameter('RepoPath', $repoPath)
        $ps.AddParameter('NeedDownload', $needDownload)
        $ps.AddParameter('SyncHash', $script:SyncHash)
        $ps.AddParameter('RepoZipUrl', $script:RepoZipUrl)
        $ps.AddParameter('RepoName', $script:RepoName)
        $ps.AddParameter('ProfilePath', $PROFILE)
        $ps.AddParameter('Params', @{
            RepoPath          = $repoPath
            InstallPS7        = $chkPS7.IsChecked
            InstallGit        = $chkGit.IsChecked
            InstallOMP        = $chkOMP.IsChecked
            InstallZoxide     = $chkZoxide.IsChecked
            InstallFont       = $chkFont.IsChecked
            InstallModules    = $chkModules.IsChecked
            InstallAlacritty  = $chkAlacritty.IsChecked
            InstallChocolatey = $chkChoco.IsChecked
            ChocolateySources = $txtChocoSources.Text
            InstallScoop      = $chkScoop.IsChecked
            ScoopBuckets      = $txtScoopBuckets.Text
        })
        $ps.BeginInvoke() | Out-Null
    })

    $btnRemove.Add_Click({
        if ($script:SyncHash.IsRunning) {
            [System.Windows.MessageBox]::Show($window, 'An operation is already in progress.', 'Busy', 'OK', 'Information')
            return
        }
        $repoPath = $txtRepoPath.Text.Trim()
        $confirm = [System.Windows.MessageBox]::Show(
            $window, "This will remove the PowerShell profile link and clean up cache files.`n`nYour original profile backup will be preserved.`n`nContinue?",
            'Confirm Removal', 'YesNo', 'Warning')
        if ($confirm -ne 'Yes') { return }

        foreach ($ctrl in @($btnInstall, $btnRemove, $btnBrowse, $txtRepoPath,
            $chkPS7, $chkGit, $chkOMP, $chkZoxide, $chkFont, $chkModules,
            $chkAlacritty, $chkChoco, $txtChocoSources, $chkScoop, $txtScoopBuckets)) {
            $ctrl.IsEnabled = $false
        }
        $script:SyncHash.InstallComplete = $false
        $script:SyncHash.InstallFailed = $false
        $script:SyncHash.IsRunning = $true
        $script:SyncHash.LogMessages.Clear()
        $logIndex = 0
        $txtLog.Document.Blocks.Clear()
        $txtStatus.Text = 'Removing...'
        $txtStatus.Foreground = $colors.Warn
        $txtProgress.Text = ''
        $timer.Start()

        $ps = [PowerShell]::Create()
        $ps.AddScript({
            param($SetupDir, $RepoPath, $SyncHash, $ProfilePath)

            $script:SyncHash = $SyncHash
            $global:PROFILE = $ProfilePath

            . (Join-Path $SetupDir '../lib/executable.ps1')
            . (Join-Path $SetupDir 'modules/core.ps1')
            . (Join-Path $SetupDir 'modules/profile.ps1')
            . (Join-Path $SetupDir 'modules/orchestrator.ps1')

            Start-ProfileUninstall -RepoPath $RepoPath
        })
        $ps.AddParameter('SetupDir', $SetupDir)
        $ps.AddParameter('RepoPath', $repoPath)
        $ps.AddParameter('SyncHash', $script:SyncHash)
        $ps.AddParameter('ProfilePath', $PROFILE)
        $ps.BeginInvoke() | Out-Null
    })

    $btnBrowse.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the config-powershell7 repository folder'
        $dialog.ShowNewFolderButton = $true
        if ($dialog.ShowDialog() -eq 'OK') {
            $txtRepoPath.Text = $dialog.SelectedPath
        }
    })

    $window.Add_Closing({ $timer.Stop() })
    $window.ShowDialog() | Out-Null
}
