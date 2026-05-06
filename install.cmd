@echo off
:: ──────────────────────────────────────────────────────────────
:: install.cmd — Double-click wrapper for install.ps1
:: Detects pwsh (PowerShell 7+) or falls back to powershell.exe
:: ──────────────────────────────────────────────────────────────
title PowerShell Profile Installer

where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
)
