# PowerShell Config (PS7)

> High-performance, modular PowerShell 7+ startup profile optimized for developer ergonomics.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![CI](https://github.com/AndersonTavares0/config-powershell7/actions/workflows/test.yml/badge.svg)
![Tests](https://img.shields.io/badge/Tests-Custom_Framework-4b32c3?logo=powershell)
![Oh My Posh](https://img.shields.io/badge/Prompt-Oh_My_Posh-4b32c3)
![Zoxide](https://img.shields.io/badge/Nav-Zoxide-purple)
![PSReadLine](https://img.shields.io/badge/Input-PSReadLine-darkgreen?logo=powershell)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

## One-Line Install

```powershell
irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex
```

Installs PS7, Git, Oh My Posh, Zoxide, FiraCode Nerd Font, PSReadLine,
Terminal-Icons, and Alacritty. Topgrade and Scoop remain optional. Package
installers can request UAC when their WinGet manifest requires machine scope.

## Key Technical Features

- **Extreme Performance**: Optimized boot sequence with TTL-based plugin cache
  (24h). Hot path skips `Get-Command` and `Get-FileHash` entirely (~5ms cache
  validation + ~120ms OMP init + ~30ms zoxide init). Config paths resolved
  inline (no function overhead). Fingerprint uses `LastWriteTime` + file size
  (not SHA256). Boot time color-coded: Green < 300ms, Yellow < 600ms,
  Red > 600ms. Run `tests/benchmark.ps1` to measure your machine.
- **TTL Cache System**: Third-party plugins (`oh-my-posh`, `zoxide`) cached
  with 24-hour TTL. Cache header includes fingerprint + Unix timestamp; valid
  TTL skips `Get-Command` and fingerprint recalculation entirely.
- **WPF GUI Installer**: Dark VS Code-themed interactive installer with OMP
  theme selection (live prompt preview from GitHub), terminal color theme
  selection (Windows Terminal + Alacritty) with color swatch preview, progress
  bar, synchronized logging, and CLI fallback for headless/CI environments.
- **POSH_THEME Env Var**: Runtime OMP theme selection via
  `$env:POSH_THEME` — overrides the theme chosen at install time. Set it in
  `$PROFILE` or per-session to switch themes without reinstalling.
- **Universal Installer**: Per-user orchestration, WinGet with
  `--silent --accept-source-agreements --accept-package-agreements`, dynamic
  paths via `[Environment]::GetFolderPath`, stable GitHub Release downloads,
  and convergent repeat runs.
- **Zero-Elevation Profile**: No symlinks, no UAC prompts. The installer
  maintains a lightweight block in `$PROFILE.CurrentUserAllHosts` that
  dot-sources the repository without replacing user content.
- **Strict-Mode Compliant**: Entire codebase passes
  `Set-StrictMode -Version Latest` — zero uninitialized variables, no hidden
  scoping. No bare `catch {}`. Profile load guards stay process-local and are
  not inherited by child shells.
- **Windows Target**: Installer support covers Windows 10/11 x64 with
  PowerShell 7 and Alacritty. Profile modules retain graceful platform checks.
- **Dynamic Boot Summary**: Clean boot report with platform info, loaded
  modules, and admin status.

## Documentation

- [Installation & Compatibility](docs/installation.md)
- [Modules, Features & Technical Reference](docs/modules.md)
- [Troubleshooting & Tests](docs/troubleshooting.md)

---

## Architecture Overview

The profile is structured into strict modular components for isolation and
fault tolerance:

```text
config-powershell7/
├── .github/workflows/          # CI/CD (GitHub Actions)
├── Microsoft.PowerShell_profile.ps1 # Entrypoint Profile (Loader)
├── install.ps1                 # Legacy installer (irm | iex, admin elevation)
├── setup.ps1                   # Main installer entry point (GUI or CLI)
├── uninstall.ps1               # Safe uninstaller (backup + cache cleanup)
├── install.cmd / uninstall.cmd # Double-click launchers (Windows)
├── setup/
│   ├── modules/
│   │   ├── core.ps1            # Logging, platform detection, constants
│   │   ├── deps.ps1            # Dependency installers (WinGet, fonts, themes)
│   │   ├── profile.ps1         # Profile link management
│   │   ├── orchestrator.ps1    # Install/uninstall orchestration
│   │   ├── gui.ps1             # WPF XAML UI with runspace logging
│   │   └── cli.ps1             # Terminal menu (CI/non-interactive fallback)
│   └── setup.ps1               # Module loader/dispatcher
├── lib/
│   ├── platform.ps1            # Cross-platform detection + elevation
│   ├── ux-helpers.ps1          # Console output helpers
│   └── profile-paths.ps1       # Profile path resolution
├── modules/
│   ├── config/                 # Centralized config (critical, loaded first)
│   ├── cache/                  # TTL cache engine & lazy loaders
│   ├── navigation/             # Directory shortcuts
│   ├── git/                    # Git aliases
│   ├── system/                 # System/network utilities + sudo
│   ├── psreadline/             # PSReadLine config + keybindings
│   └── text_utils/             # Unix-like tools (grep, sed, touch)
└── tests/
    ├── Unit.Tests.ps1          # Unit tests (cache, system, git, text)
    ├── POSH_THEME.Tests.ps1    # 5 env-var theme override tests
    ├── Microsoft.PowerShell_profile.Tests.ps1  # Integration tests
    ├── Test-ProfileInstallation.ps1            # Post-install checks
    ├── Setup.Tests.ps1         # Setup module tests
    └── benchmark.ps1           # Profile boot timing benchmark
```

**Loading order** (critical): config (0) → cache (1) → navigation → git →
system → psreadline → text_utils

---

## Quick Start

**Option A — Remote (recommended):**

```powershell
irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex
```

> Detects interactive versus headless use and guides theme selection. WinGet
> package installers can request UAC independently.

**Option B — WPF GUI (Windows):**

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
.\setup.ps1
```

> Full graphical installer with OMP theme preview and terminal color swatches.

**Option C — Headless/CI compatibility wrapper:**

```powershell
.\install.ps1 -NonInteractive
```

**Uninstall:**

> Double-click `uninstall.cmd` or run `.\uninstall.ps1`.

---

## Requirements

- **PowerShell 7.x** (Core) highly recommended (supports PS 5.1 via graceful
  degradation)
- **FiraCode Nerd Font** (for icons/ligatures)
- **Windows Terminal** or **Alacritty**
- **Git** (required for Git aliases)
- **Oh My Posh** (optional — prompt theming)
- **Zoxide** (optional — smart directory navigation)
- **Terminal-Icons** (optional — file icons in listings)

## POSH_THEME (Runtime Theme Override)

Set `$env:POSH_THEME` to switch your Oh My Posh theme at runtime without
reinstalling:

```powershell
$env:POSH_THEME = 'montys'
```

The profile reads this variable each session. Unset or empty falls back to the
theme selected during installation.

## Startup Directory

The profile preserves the terminal's current working directory by default. On
Windows, elevated shells opening in `System32` or `SysWOW64` redirect to
`POWERSHELL_START_DIR` when valid, otherwise to `$HOME`.

```powershell
Set-ProfileStartDirectory "$HOME"
Get-ProfileStartDirectory
Clear-ProfileStartDirectory
```
