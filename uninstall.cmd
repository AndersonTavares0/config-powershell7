@echo off
:: ──────────────────────────────────────────────────────────────
:: uninstall.cmd — Double-click wrapper for uninstall.ps1
:: Detects pwsh (PowerShell 7+) or falls back to powershell.exe
:: ──────────────────────────────────────────────────────────────
title PowerShell Profile Uninstaller

where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -NonInteractive
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -NonInteractive
)
