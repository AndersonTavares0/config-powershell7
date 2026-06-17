# PowerShell Config (PS7)

> High-performance, modular PowerShell 7+ startup profile optimized for developer ergonomics.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions)
![Tests](https://img.shields.io/badge/Test-Custom_Framework-cf4647?logo=powershell)
![Oh My Posh](https://img.shields.io/badge/Prompt-Oh_My_Posh-4b32c3)
![Zoxide](https://img.shields.io/badge/Nav-Zoxide-purple)
![PSReadLine](https://img.shields.io/badge/Input-PSReadLine-darkgreen?logo=powershell)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

## One-Line Install

```powershell
irm https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/install.ps1 | iex
```

Elevação automática para Administrador, WinGet silencioso, caminhos blindados contra OneDrive, idempotente.

## Key Technical Features

- **Extreme Performance**: Optimized boot sequence with TTL-based plugin cache (24h). Hot path skips `Get-Command` and `Get-FileHash` entirely (~5ms cache validation + ~120ms OMP init + ~30ms zoxide init). Config paths resolved inline (no function overhead). Fingerprint uses `LastWriteTime` + file size (not SHA256) for change detection. Boot time color-coded: 🟢 Green < 300ms, 🟡 Yellow < 600ms, 🔴 Red > 600ms. [Benchmark real: ~420ms média](tests/benchmark.ps1).
- **TTL Cache System**: Third-party plugins (`oh-my-posh`, `zoxide`) are cached with a 24-hour Time-To-Live. Cache header includes fingerprint + Unix timestamp; when TTL is valid, `Get-Command` and fingerprint recalculation are skipped entirely. Fingerprint uses file `LastWriteTime` + size for fast change detection (~0ms vs SHA256's ~43ms).
- **Universal Installer**: Auto-elevação para Admin, WinGet com `--silent --accept-source-agreements --accept-package-agreements`, caminhos dinâmicos via `[Environment]::GetFolderPath` (blindado contra OneDrive), idempotente (pode rodar múltiplas vezes).
- **WPF GUI Installer**: Interactive Windows installer with progress bar, synchronized logging, and terminal menu fallback for non-interactive/CI environments. Installs PS7, Git, Oh My Posh, Zoxide, Nerd Font, Alacritty, Chocolatey, Scoop — all from one unified setup.
- **Zero-Elevation Installer**: No symlinks, no UAC prompts. The installer writes a lightweight `$PROFILE` file that dot-sources the repository via `$env:__PROFILE_REPO_ROOT`, ensuring 100% path resolution without Administrator privileges.
- **Strict-Mode Compliant**: Entire codebase passes `Set-StrictMode -Version Latest` — zero uninitialized variables, no hidden scoping bugs. Code Quality Guide enforced: no bare `catch {}`, no silent failures. Globals migrated to environment variables (`$env:__PROFILE_LOADED`, `$env:__PROFILE_REPO_ROOT`).
- **Cross-Platform**: Full support for Windows, Linux (Fedora), and macOS with graceful degradation per platform.
- **Dynamic Boot Summary**: Clean, highlighted boot report with platform info, loaded modules, and admin status.

## Documentation

- [Installation & Compatibility](docs/installation.md)
- [Modules, Features & Technical Reference](docs/modules.md)
- [Troubleshooting & Tests](docs/troubleshooting.md)

---

## Architecture Overview

The profile is structured into strict modular components for isolation and fault tolerance:

```text
config-powershell7/
├── .github/workflows/          # CI/CD (GitHub Actions) — 1 pipeline
├── Microsoft.PowerShell_profile.ps1 # Entrypoint Profile (Loader)
├── install.ps1                 # Universal installer (irm | iex, admin elevation, winget, idempotent)
├── uninstall.ps1               # Safe Uninstaller (backup + cache cleanup)
├── install.cmd                 # Bootstrap launcher (batch/PowerShell hybrid — double-click or irm | iex)
├── uninstall.cmd               # Double-click uninstaller (Windows)
├── setup.ps1                   # Entry point for WPF GUI installer
├── setup/                      # Modular GUI installer
│   ├── setup.ps1               # Module loader/dispatcher (GUI or CLI)
│   └── modules/                # Installer sub-modules
│       ├── core.ps1            # Platform detection, constants, logging
│       ├── deps.ps1            # Dependency installers (WinGet, Nerd Font, etc.)
│       ├── profile.ps1         # Profile link management
│       ├── orchestrator.ps1    # Install/uninstall orchestration
│       ├── gui.ps1             # WPF XAML UI with runspace logging
│       └── cli.ps1             # Terminal menu fallback (CI/non-interactive)
├── lib/                        # Shared Utilities (DRY)
│   ├── platform.ps1            # Cross-platform detection + elevation
│   ├── ux-helpers.ps1          # Console output (Write-Ok, Write-Warn, etc.)
│   └── profile-paths.ps1       # Profile path resolution
├── modules/                    # Modular Logic
│   ├── config/                 # Centralized configuration (critical, loaded first)
│   ├── cache/                  # TTL Cache Engine & Lazy Loaders
│   ├── navigation/             # Directory shortcuts
│   ├── git/                    # Git shortcuts (conditional)
│   ├── system/                 # System/Network utilities + sudo
│   ├── psreadline/             # PSReadLine configuration + keybindings
│   └── text_utils/             # Unix-like tools (grep, tail, sed, touch)
├── tests/                      # Test Suites + Benchmarks (custom framework)
│   ├── benchmark.ps1                    # Profile boot timing benchmark (5+ runs, fresh processes)
│   ├── Test-ProfileInstallation.ps1     # 64 post-install checks
│   ├── Microsoft.PowerShell_profile.Tests.ps1  # Behavioral integration tests
│   └── Setup.Tests.ps1                 # 32 TDD tests for setup modules
└── graphify-out/               # Knowledge graph (queryable via /graphify)
```

**Loading order** (critical): config (0) → cache (1) → navigation → git → system → psreadline → text_utils

---

## Quick Start

**Option A — Remote (recommended):**

```powershell
irm https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/install.ps1 | iex
```

> Eleva para Admin automaticamente, instala tudo via WinGet e configura o profile.

**Option B — WPF GUI (Windows):**

> Clone the repo and double-click `install.cmd`.

**Option C — Terminal:**

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
.\setup.ps1
```

**Option D — Headless (CI):**

```powershell
.\install.ps1 -NonInteractive
```

**Uninstall:**

> Double-click `uninstall.cmd` or run `.\uninstall.ps1`.

---

## Requirements

- **PowerShell 7.x** (Core) highly recommended (supports PS 5.1 Legacy via graceful degradation)
- **FiraCode Nerd Font** (for icons/ligatures)
- **Alacritty** or **Windows Terminal**
- **Git** (required for Git aliases)
- **Oh My Posh** (optional — prompt theming)
- **Zoxide** (optional — smart directory navigation)
- **Terminal-Icons** (optional — file icons in listings)

## Startup Directory

The profile preserves the terminal's current working directory by default. On Windows, if an elevated shell opens in `System32` or `SysWOW64`, it redirects to `POWERSHELL_START_DIR` when valid, otherwise to `$HOME`.

```powershell
Set-ProfileStartDirectory "$HOME"
Get-ProfileStartDirectory
Clear-ProfileStartDirectory
```
