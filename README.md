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

## Key Technical Features

- **Extreme Performance**: Optimized boot sequence with **24-hour TTL-based plugin cache**. Hot path skips `Get-Command` and `Get-FileHash` entirely (~5ms cache validation + ~120ms OMP init execution). Cache fingerprint uses `LastWriteTime` + file size (not SHA256) for change detection. Boot time color-coded: Green < 300ms, Yellow < 600ms, Red > 600ms.
- **TTL Cache System**: Third-party plugins (`oh-my-posh`, `zoxide`) are cached with a **24-hour Time-To-Live**. Cache header includes fingerprint + Unix timestamp; when TTL is valid, `Get-Command` and fingerprint recalculation are skipped entirely. Fingerprint uses file `LastWriteTime` + size for change detection (~0ms vs SHA256 ~43ms).
- **WPF GUI Installer**: Interactive Windows installer with progress bar, synchronized runspace logging, and terminal menu fallback for non-interactive/CI environments. Installs PS7, Git, Oh My Posh, Zoxide, Nerd Font, Alacritty, Chocolatey, Scoop from a unified entry point.
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
├── install.ps1                 # Legacy CLI installer (preserved for CI)
├── uninstall.ps1               # Safe Uninstaller (backup + cache cleanup)
├── install.cmd                 # Double-click GUI launcher (calls setup/)
├── uninstall.cmd               # Double-click uninstaller (Windows)
├── setup.ps1                   # Entry point for new GUI/CLI installer
├── setup/                      # Modular GUI installer
│   └── modules/                # Installer sub-modules
│       ├── core.ps1            # Platform detection, constants, logging
│       ├── deps.ps1            # Dependency installers
│       ├── profile.ps1         # Profile link management
│       ├── orchestrator.ps1    # Install/uninstall orchestration
│       ├── gui.ps1             # WPF XAML UI with runspaces
│       └── cli.ps1             # Terminal menu fallback
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
├── tests/                      # Test Suites (custom framework)
│   ├── Setup.Tests.ps1         # 32 TDD tests for setup modules
│   ├── Test-ProfileInstallation.ps1  # 64 post-install checks
│   └── Microsoft.PowerShell_profile.Tests.ps1  # Behavioral integration tests
└── graphify-out/               # Knowledge graph (queryable via /graphify)
```

**Loading order** (critical): config → cache → navigation → git → system → psreadline → text_utils

---

## Quick Start

**Option A — One-line remote install (recommended):**

```powershell
irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex
```

**Option B — WPF GUI (Windows):**

Clone the repo and double-click `install.cmd`.

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

Double-click `uninstall.cmd` or run `.\uninstall.ps1`.

---

## Requirements

- **PowerShell 7.x** (Core) highly recommended (supports PS 5.1 Legacy via graceful degradation)
- **FiraCode Nerd Font** (for icons/ligatures)
- **Alacritty** or **Windows Terminal**
- **Git** (required for Git aliases)
- **Oh My Posh** (optional — prompt theming)
- **Zoxide** (optional — smart directory navigation)
- **Terminal-Icons** (optional — file icons in listings)
