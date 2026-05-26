<# : batch script
@echo off & setlocal
title config-powershell7 Installer
chcp 65001 >nul
echo.
echo  Baixando instalador...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$script = Invoke-RestMethod 'https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/install.ps1';" ^
  "Invoke-Expression $script"
echo.
echo  Concluido. Pressione qualquer tecla para sair...
pause >nul
exit /b
#>
# PowerShell code aqui (executado quando via irm | iex)
$script = Invoke-RestMethod 'https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/install.ps1'
Invoke-Expression $script
