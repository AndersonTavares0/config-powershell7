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
    Width="720" Height="860"
    MinWidth="640" MinHeight="700"
    WindowStartupLocation="CenterScreen"
    ResizeMode="CanResize"
    TextElement.FontFamily="Segoe UI"
    TextElement.FontSize="13"
    UseLayoutRounding="True"
    SnapsToDevicePixels="True"
    Background="#1E1E1E"
    Foreground="#DCDCDC"
    KeyboardNavigation.TabNavigation="Cycle"
    AutomationProperties.Name="PowerShell Profile Setup">

    <Window.Resources>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Width" Value="260"/>
            <Setter Property="Height" Value="60"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
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
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#DCDCDC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
        </Style>
        <Style x:Key="DarkTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#DCDCDC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="8,6"/>
        </Style>
        <Style x:Key="DarkListBox" TargetType="ListBox">
            <Style.Resources>
                <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#094771"/>
                <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="#FFFFFF"/>
            </Style.Resources>
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#DCDCDC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="ItemContainerStyle">
                <Setter.Value>
                    <Style TargetType="ListBoxItem">
                        <Setter Property="Background" Value="#2D2D30"/>
                        <Setter Property="Foreground" Value="#DCDCDC"/>
                        <Setter Property="BorderThickness" Value="0"/>
                        <Setter Property="Padding" Value="4,2"/>
                    </Style>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SectionBorder" TargetType="Border">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="6"/>
        </Style>
        <Style x:Key="CheckBoxLabel" TargetType="CheckBox">
            <Setter Property="Foreground" Value="#DCDCDC"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Margin" Value="0,0,0,3"/>
        </Style>
        <Style x:Key="SmallCheckBox" TargetType="CheckBox">
            <Setter Property="Foreground" Value="#9D9D9D"/>
            <Setter Property="FontSize" Value="11"/>
        </Style>
        <Style x:Key="FocusButton" TargetType="Button">
            <Setter Property="FocusVisualStyle">
                <Setter.Value>
                    <Style TargetType="Control">
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="Control">
                                    <Rectangle Stroke="#569CD6" StrokeThickness="2" StrokeDashArray="3,2"
                                               Margin="4" SnapsToDevicePixels="True"/>
                                </ControlTemplate>
                            </Setter.Value>
                        </Setter>
                    </Style>
                </Setter.Value>
            </Setter>
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
                   Foreground="#569CD6"
                   HorizontalAlignment="Center"
                   Margin="0,0,0,4"/>

        <TextBlock Grid.Row="1" Text="One-click install/remove - all dependencies included"
                   FontSize="13"
                   Foreground="#9D9D9D"
                   HorizontalAlignment="Center"
                   Margin="0,0,0,20"/>

        <StackPanel Grid.Row="2" Orientation="Horizontal"
                    HorizontalAlignment="Center" Margin="0,0,0,12">
            <Button x:Name="BtnInstall"
                    Style="{StaticResource PrimaryButton}"
                    Background="#0E639C"
                    Content="Install All"
                    Margin="0,0,12,0"
                    ToolTip="Install all selected components and link profile"
                    AutomationProperties.HelpText="Downloads and installs all checked dependencies, then links the PowerShell profile"/>
            <Button x:Name="BtnRemove"
                    Style="{StaticResource PrimaryButton}"
                    Background="#C74B4B"
                    Content="Remove Profile"
                    Margin="12,0,0,0"
                    ToolTip="Remove profile link and clean cache files"
                    AutomationProperties.HelpText="Removes the PowerShell profile link and cleans up cache files, preserving backups"/>
        </StackPanel>

        <StackPanel Grid.Row="3" Margin="0,0,0,8">
            <TextBlock Text="Repository location:" FontSize="11" Foreground="#6E6E6E" Margin="0,0,0,2"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="TxtRepoPath" Grid.Column="0" Style="{StaticResource DarkTextBox}"/>
                <Button x:Name="BtnBrowse" Grid.Column="1"
                        Content="Browse..."
                        Width="70" Height="30"
                        FontSize="11"
                        Foreground="#DCDCDC" Background="#3E3E42"
                        BorderThickness="0" Margin="6,0,0,0"
                        Cursor="Hand"/>
            </Grid>
        </StackPanel>
        <ScrollViewer Grid.Row="4" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"
                      AutomationProperties.Name="Installation options">
            <StackPanel Margin="0,8,0,8">
            <CheckBox x:Name="ChkPS7" Style="{StaticResource CheckBoxLabel}" IsChecked="True"
                      ToolTip="Install the latest version of PowerShell 7 via winget">
                Install PowerShell 7 (latest)
            </CheckBox>
            <CheckBox x:Name="ChkGit" Style="{StaticResource CheckBoxLabel}" IsChecked="True"
                      ToolTip="Install Git version control via winget">
                Install Git
            </CheckBox>
            <CheckBox x:Name="ChkOMP" Style="{StaticResource CheckBoxLabel}" IsChecked="True"
                      ToolTip="Install Oh My Posh prompt theme engine via winget">
                Install Oh My Posh (prompt themes)
            </CheckBox>
            <Border Style="{StaticResource SectionBorder}" Margin="20,0,0,8" Padding="8">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="140"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="Select OMP theme:" FontSize="12" Foreground="#9D9D9D" Margin="0,0,0,4"/>
                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="160"/>
                        </Grid.ColumnDefinitions>
                        <ListBox x:Name="LstTheme" Grid.Column="0"
                                 Style="{StaticResource DarkListBox}" FontSize="11"
                                 ScrollViewer.VerticalScrollBarVisibility="Auto"
                                 IsEnabled="{Binding ElementName=ChkOMP, Path=IsChecked}"/>
                        <ScrollViewer Grid.Column="1" Width="160" Margin="6,0,0,0"
                                      Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1"
                                      VerticalScrollBarVisibility="Auto">
                            <TextBlock x:Name="TxtThemePreview" TextWrapping="Wrap"
                                       FontSize="11" Foreground="#9D9D9D"
                                       Padding="6,4"/>
                        </ScrollViewer>
                    </Grid>
                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,4,0,0">
                        <Button x:Name="BtnRefreshThemes" Content="Reload" Width="80" Height="24"
                                FontSize="10" Foreground="#DCDCDC" Background="#3E3E42"
                                BorderThickness="0" Cursor="Hand"
                                ToolTip="Refresh theme list from GitHub"
                                AutomationProperties.HelpText="Reloads the list of available Oh My Posh themes from GitHub"/>
                        <TextBlock x:Name="TxtThemeCount" Text="Loading themes..." FontSize="11"
                                   Foreground="#6E6E6E" VerticalAlignment="Center" Margin="8,0,0,0"/>
                    </StackPanel>
                    <Border Grid.Row="3" MinHeight="32" Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1" CornerRadius="4" Padding="4" Margin="0,4,0,0">
                        <ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">
                            <StackPanel x:Name="OmpPromptPreview" Orientation="Horizontal"/>
                        </ScrollViewer>
                    </Border>
                </Grid>
            </Border>
            <CheckBox x:Name="ChkZoxide" Style="{StaticResource CheckBoxLabel}" IsChecked="True">
                Install Zoxide (smart cd)
            </CheckBox>
            <CheckBox x:Name="ChkFont" Style="{StaticResource CheckBoxLabel}" IsChecked="True">
                Install FiraCode Nerd Font
            </CheckBox>
            <CheckBox x:Name="ChkTerminalTheme" Style="{StaticResource CheckBoxLabel}" IsChecked="True" Margin="0,6,0,3">
                Apply terminal color theme (optional)
            </CheckBox>
            <Border x:Name="TerminalThemeSection" Style="{StaticResource SectionBorder}" Margin="20,0,0,8" Padding="8">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="130"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="Select terminal theme:" FontSize="12" Foreground="#9D9D9D" Margin="0,0,0,4"/>
                    <ListBox x:Name="LstTerminalTheme" Grid.Row="1"
                             Style="{StaticResource DarkListBox}" FontSize="11"
                             ScrollViewer.VerticalScrollBarVisibility="Auto"/>
                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,4,4,4">
                        <CheckBox x:Name="ChkThemeWT" Style="{StaticResource SmallCheckBox}" Content="Windows Terminal" IsChecked="True" Margin="0,0,12,0"/>
                        <CheckBox x:Name="ChkThemeAla" Style="{StaticResource SmallCheckBox}" Content="Alacritty" IsChecked="True"/>
                    </StackPanel>
                    <Border Grid.Row="3" Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1" CornerRadius="4" Padding="6,4" MinHeight="40">
                        <StackPanel>
                            <TextBlock x:Name="TxtTerminalThemePreview" TextWrapping="Wrap" FontSize="11" Foreground="#9D9D9D"/>
                            <WrapPanel x:Name="TerminalThemeColors" Margin="0,4,0,0"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </Border>
            <CheckBox x:Name="ChkAlacritty" Style="{StaticResource CheckBoxLabel}" IsChecked="False" Margin="0,6,0,3">
                Install Alacritty terminal emulator
            </CheckBox>
            <CheckBox x:Name="ChkScoop" Style="{StaticResource CheckBoxLabel}" IsChecked="False" Margin="0,6,0,3">
                Install Scoop package manager
            </CheckBox>
            <StackPanel Orientation="Horizontal" Margin="20,0,0,8">
                <TextBlock Text="Buckets (comma-separated):" FontSize="11" Foreground="#6E6E6E" VerticalAlignment="Center" Margin="0,0,6,0"/>
                <TextBox x:Name="TxtScoopBuckets" Width="280" Text="extras, versions, nerd-fonts" Style="{StaticResource DarkTextBox}" FontSize="11"/>
            </StackPanel>
            <CheckBox x:Name="ChkTopgrade" Style="{StaticResource CheckBoxLabel}" IsChecked="False" Margin="0,6,0,3"
                       ToolTip="Install Topgrade - upgrade all package managers with one command">
                Install Topgrade (universal package updater)
            </CheckBox>
            </StackPanel>
        </ScrollViewer>

        <Grid Grid.Row="5" Margin="0,4,0,6">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtStatus" Grid.Column="0"
                       Text="Ready."
                       FontSize="12" Foreground="#9D9D9D"
                       VerticalAlignment="Center"/>
            <TextBlock x:Name="TxtProgress" Grid.Column="1"
                       Text=""
                       FontSize="11" Foreground="#6E6E6E"
                       VerticalAlignment="Center"/>
        </Grid>

        <Border Grid.Row="6" CornerRadius="6">
            <RichTextBox x:Name="TxtLog"
                         Style="{StaticResource LogTextBox}"/>
        </Border>

        <StackPanel Grid.Row="7" Orientation="Horizontal"
                    HorizontalAlignment="Right" Margin="0,10,0,0">
            <TextBlock Text="Invoke via irm: "
                       FontSize="10" Foreground="#6E6E6E"
                       VerticalAlignment="Center"/>
            <TextBlock Text="irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex"
                       FontSize="10" Foreground="#9D9D9D"
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
    $lstTheme        = $window.FindName('LstTheme')
    $txtThemePreview = $window.FindName('TxtThemePreview')
    $btnRefreshThemes = $window.FindName('BtnRefreshThemes')
    $txtThemeCount   = $window.FindName('TxtThemeCount')
    $chkZoxide       = $window.FindName('ChkZoxide')
    $chkFont         = $window.FindName('ChkFont')
    $chkTerminalTheme  = $window.FindName('ChkTerminalTheme')
    $terminalThemeSection = $window.FindName('TerminalThemeSection')
    $lstTerminalTheme  = $window.FindName('LstTerminalTheme')
    $chkThemeWT        = $window.FindName('ChkThemeWT')
    $chkThemeAla       = $window.FindName('ChkThemeAla')
    $txtTerminalThemePreview = $window.FindName('TxtTerminalThemePreview')
    $chkAlacritty    = $window.FindName('ChkAlacritty')
    $chkScoop        = $window.FindName('ChkScoop')
    $txtScoopBuckets = $window.FindName('TxtScoopBuckets')
    $chkTopgrade     = $window.FindName('ChkTopgrade')

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

        # Populate terminal theme ComboBox (runs synchronously since data is local)
    try {
        $termThemes = Get-TerminalThemeList
        if ($termThemes) {
            $lstTerminalTheme.Items.Clear()
            foreach ($tt in $termThemes) { $lstTerminalTheme.Items.Add($tt.Name) | Out-Null }
            $lstTerminalTheme.SelectedIndex = 0
        }
    } catch {
        $txtTerminalThemePreview.Text = "Error loading themes: $_"
    }

    # Show OMP theme preview - realistic prompt bar
    $lstTheme.Add_SelectionChanged({
        $theme = $lstTheme.SelectedItem
        $previewBox = $window.FindName('TxtThemePreview')
        $promptPanel = $window.FindName('OmpPromptPreview')
        if (-not $theme) { $previewBox.Text = ''; $promptPanel.Children.Clear(); return }
        $previewBox.Text = "Loading..."
        $promptPanel.Children.Clear()

        try {
            Enable-Tls12
            $url = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$theme.omp.json"
            $json = Invoke-RestMethod -Uri $url -ErrorAction Stop -UseBasicParsing

            $segTypes = @{}
            $segTypes['path'] = ' ~\project '
            $segTypes['git'] = ' [main] '; $segTypes['gitbranch'] = ' [main] '
            $segTypes['node'] = ' v18 '; $segTypes['python'] = ' .venv '
            $segTypes['text'] = ' demo '; $segTypes['shell'] = ' > '
            $segTypes['exit'] = ' x '; $segTypes['time'] = ' 14:30 '
            $segTypes['date'] = ' Mon6 '; $segTypes['session'] = ' user '
            $segTypes['os'] = ' Win '; $segTypes['executiontime'] = ' 2m '
            $segTypes['status'] = ' ok '; $segTypes['root'] = ' # '
            $segTypes['dotnet'] = ' .NET '; $segTypes['go'] = ' go '
            $segTypes['ruby'] = ' ruby '; $segTypes['docker'] = ' D '
            $segTypes['kubectl'] = ' K8s '

            $totalSegments = 0
            $bc = [System.Windows.Media.BrushConverter]::new()

            foreach ($block in $json.blocks) {
                if (-not $block.segments) { continue }
                foreach ($seg in $block.segments) {
                    $totalSegments++
                    $fg = if ($seg.foreground) { $seg.foreground } else { '#DCDCDC' }
                    $bg = if ($seg.background) { $seg.background } else { 'Transparent' }
                    $sample = if ($segTypes.ContainsKey($seg.type)) { $segTypes[$seg.type] } else { " $($seg.type) " }

                    $border = New-Object System.Windows.Controls.Border
                    $border.Padding = New-Object System.Windows.Thickness(0)
                    $border.BorderThickness = New-Object System.Windows.Thickness 0

                    try { $border.Background = $bc.ConvertFromString($bg) } catch { }

                    $txt = New-Object System.Windows.Controls.TextBlock
                    $txt.Text = $sample
                    $txt.FontFamily = 'Consolas'
                    $txt.FontSize = 13
                    $txt.Padding = New-Object System.Windows.Thickness(4, 2, 4, 2)
                    try { $txt.Foreground = $bc.ConvertFromString($fg) } catch { }
                    $txt.ToolTip = "$($seg.type)`nBG: $bg  FG: $fg"

                    $border.Child = $txt
                    $promptPanel.Children.Add($border) | Out-Null
                }
            }

            $previewBox.Text = "$theme - $($json.blocks.Count) block(s), $totalSegments segment(s)"
        } catch {
            $previewBox.Text = "$theme - Preview unavailable"
        }
    })

    # Show terminal theme preview with color swatches
    $lstTerminalTheme.Add_SelectionChanged({
        $name = $lstTerminalTheme.SelectedItem
        $previewPanel = $window.FindName('TerminalThemeColors')
        $previewPanel.Children.Clear()
        if (-not $name) { $txtTerminalThemePreview.Text = 'Select a theme above'; return }
        $data = Get-TerminalThemeData -Name $name
        if (-not $data) { $txtTerminalThemePreview.Text = "No data for '$name'"; return }

        $txtTerminalThemePreview.Text = "$name ($($data.Type))"

        $bc = [System.Windows.Media.BrushConverter]::new()
        $swatchColors = @(
            @{ Label = 'BG';   Color = $data.WT.background }
            @{ Label = 'FG';   Color = $data.WT.foreground }
            @{ Label = 'Red';  Color = $data.WT.red }
            @{ Label = 'Green'; Color = $data.WT.green }
            @{ Label = 'Blue'; Color = $data.WT.blue }
            @{ Label = 'Yel';  Color = $data.WT.yellow }
            @{ Label = 'Purp'; Color = $data.WT.purple }
            @{ Label = 'Cyan'; Color = $data.WT.cyan }
        )

        foreach ($swatch in $swatchColors) {
            $b = New-Object System.Windows.Controls.Border
            $b.Width = 28; $b.Height = 28
            $b.Margin = New-Object System.Windows.Thickness(0, 0, 4, 4)
            $b.CornerRadius = New-Object System.Windows.CornerRadius 4
            $b.BorderThickness = New-Object System.Windows.Thickness 1
            $b.BorderBrush = $bc.ConvertFromString('#3E3E42')
            try { $b.Background = $bc.ConvertFromString($swatch.Color) } catch { }
            $b.ToolTip = "$($swatch.Label): $($swatch.Color)"
            $b.Cursor = [System.Windows.Input.Cursors]::Help
            $previewPanel.Children.Add($b) | Out-Null
        }
    })

    # Toggle terminal theme section visibility
    $chkTerminalTheme.Add_Checked({
        $terminalThemeSection.Visibility = [System.Windows.Visibility]::Visible
    })
    $chkTerminalTheme.Add_Unchecked({
        $terminalThemeSection.Visibility = [System.Windows.Visibility]::Collapsed
    })

    # Load OMP theme list in background async (via Start-Job)
    $txtThemeCount.Text = "Loading themes..."
    $script:ThemeJob = $null
    function Start-OmpThemeLoad {
        $script:ThemeJob = Start-Job -ScriptBlock {
            try {
                Enable-Tls12
                $apiUrl = 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes'
                $items = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
                @($items | Where-Object { $_.name -like '*.omp.json' } |
                    ForEach-Object { $_.name -replace '\.omp\.json$', '' } |
                    Sort-Object)
            } catch { $null }
        } -Name 'OmpThemeLoad'
    }

    # Check async result in timer
    function Check-OmpThemeLoad {
        if (-not $script:ThemeJob) { return }
        if ($script:ThemeJob.State -eq 'Running') { return }
        try {
            $themes = Receive-Job $script:ThemeJob -ErrorAction SilentlyContinue
            if ($themes) {
                $lstTheme.Items.Clear()
                foreach ($t in $themes) { $lstTheme.Items.Add($t) | Out-Null }
                $txtThemeCount.Text = "$($themes.Count) themes loaded"
                $lstTheme.SelectedIndex = [Math]::Max(0, [Array]::IndexOf([string[]]$themes, 'jandedobbeleer'))
            } else {
                $txtThemeCount.Text = "Failed to load themes"
            }
        } catch {
            $txtThemeCount.Text = "Error: $_"
        } finally {
            Remove-Job $script:ThemeJob -Force -ErrorAction SilentlyContinue
            $script:ThemeJob = $null
        }
    }

    $logIndex = 0
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick({
        # Check for async theme load completion
        Check-OmpThemeLoad

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
                $chkPS7, $chkGit, $chkOMP, $lstTheme, $chkTerminalTheme,
                $lstTerminalTheme, $chkThemeWT, $chkThemeAla,
                $chkZoxide, $chkFont,
                $chkAlacritty, $chkScoop, $txtScoopBuckets, $chkTopgrade)) {
                $ctrl.IsEnabled = $true
            }
            $script:SyncHash.IsRunning = $false
        }
    })
    $timer.Start()

    # Wire refresh button
    $btnRefreshThemes.Add_Click({
        $lstTheme.Items.Clear()
        $txtThemeCount.Text = "Loading themes..."
        $txtThemePreview.Text = ''
        Start-OmpThemeLoad
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
            $chkPS7, $chkGit, $chkOMP, $lstTheme, $chkTerminalTheme,
            $lstTerminalTheme, $chkThemeWT, $chkThemeAla,
            $chkZoxide, $chkFont,
            $chkAlacritty, $chkScoop, $txtScoopBuckets, $chkTopgrade)) {
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
        $selTheme = if ($lstTheme.SelectedItem) { $lstTheme.SelectedItem } else { '' }
        $selTermTheme = if ($lstTerminalTheme.SelectedItem -and $chkTerminalTheme.IsChecked) { $lstTerminalTheme.SelectedItem } else { '' }
        $ps.AddParameter('Params', @{
            RepoPath          = $repoPath
            InstallPS7        = $chkPS7.IsChecked
            InstallGit        = $chkGit.IsChecked
            InstallOMP        = $chkOMP.IsChecked
            ThemeName         = $selTheme
            InstallZoxide     = $chkZoxide.IsChecked
            InstallFont       = $chkFont.IsChecked
            InstallModules    = $true
            TerminalThemeName = $selTermTheme
            TerminalThemeWT   = $chkThemeWT.IsChecked -and $chkTerminalTheme.IsChecked
            TerminalThemeAla  = $chkThemeAla.IsChecked -and $chkTerminalTheme.IsChecked
            InstallAlacritty  = $chkAlacritty.IsChecked
            InstallTopgrade   = $chkTopgrade.IsChecked
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
            $chkPS7, $chkGit, $chkOMP, $lstTheme, $chkTerminalTheme,
            $lstTerminalTheme, $chkThemeWT, $chkThemeAla,
            $chkZoxide, $chkFont,
            $chkAlacritty, $chkScoop, $txtScoopBuckets, $chkTopgrade)) {
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

    # Start background OMP theme load + timer
    Start-OmpThemeLoad
    $timer.Start()

    $window.Add_Closing({ $timer.Stop() })
    $window.ShowDialog() | Out-Null
}
