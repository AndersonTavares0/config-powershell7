# ── UX HELPERS (SHARED) ──────────────────────────────────────
# Funções de output padronizadas para instaladores e scripts standalone.
# Dot-source: . (Join-Path $PSScriptRoot 'lib/ux-helpers.ps1')

function Write-Step  { param([string]$Msg) Write-Host "  → $Msg" -ForegroundColor White }
function Write-Ok    { param([string]$Msg) Write-Host "  ✔ $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }
function Write-Fail  { param([string]$Msg) Write-Host "  ❌ $Msg" -ForegroundColor Red }
function Write-Info  { param([string]$Msg) Write-Host "  ℹ $Msg" -ForegroundColor DarkGray }


