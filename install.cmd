<# : batch script
@echo off & setlocal
title config-powershell7 Installer
chcp 65001 >nul
echo.
echo  Baixando instalador...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$c = (irm 'https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/install.ps1'); ^
   $c = $c -replace '^\uFEFF',''; ^
   iex $c"
echo.
echo  Concluido. Pressione qualquer tecla para sair...
pause >nul
exit /b
#>
# PowerShell code aqui (executado quando via irm | iex)
$c = (Invoke-RestMethod 'https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/install.ps1') -replace '^\uFEFF',''
Invoke-Expression $c
