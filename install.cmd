@echo off
:: ──────────────────────────────────────────────────────────────
:: install.cmd — Double-click GUI installer for PowerShell Profile
:: Opens the interactive WPF setup window
:: ──────────────────────────────────────────────────────────────
title PowerShell Profile Setup

where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
)
