#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [switch]$NonInteractive,
    [string]$ThemeName = '',
    [switch]$InstallAlacritty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$localSetup = Join-Path $PSScriptRoot 'setup.ps1'
if (Test-Path $localSetup -PathType Leaf) {
    & $localSetup -NonInteractive:$NonInteractive -ThemeName $ThemeName `
        -InstallAlacritty:$InstallAlacritty
    return
}

$setupUrl = 'https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/setup.ps1'
$tempSetup = Join-Path $env:TEMP "config-powershell7-setup-$([guid]::NewGuid().ToString('N')).ps1"
try {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    }
    Invoke-WebRequest -Uri $setupUrl -OutFile $tempSetup -ErrorAction Stop
    Unblock-File -Path $tempSetup -ErrorAction SilentlyContinue
    & $tempSetup -NonInteractive:$NonInteractive -ThemeName $ThemeName `
        -InstallAlacritty:$InstallAlacritty
} finally {
    Remove-Item $tempSetup -Force -ErrorAction SilentlyContinue
}
