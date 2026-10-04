# PowerShell Config (PS7)

> A modular PowerShell 7 profile with Git shortcuts, directory navigation and a cached prompt.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![CI](https://github.com/AndersonTavares0/config-powershell7/actions/workflows/validate.yml/badge.svg)
![Tests](https://img.shields.io/badge/Tests-Custom_Framework-4b32c3?logo=powershell)
![Oh My Posh](https://img.shields.io/badge/Prompt-Oh_My_Posh-4b32c3)
![Zoxide](https://img.shields.io/badge/Nav-Zoxide-purple)
![PSReadLine](https://img.shields.io/badge/Input-PSReadLine-darkgreen?logo=powershell)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

## One-Line Install

```powershell
irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex
```

CLI setup installs PowerShell 7, Git, Oh My Posh, Zoxide, FiraCode Nerd Font,
PSReadLine, and Terminal-Icons. Fastfetch, Topgrade, Scoop, and four coding
agent CLIs are optional. Use `-Gui` to open graphical installer.

## Key Technical Features

- **Startup Cache**: Boot sequence with TTL-based plugin cache
  (24h). Hot path skips `Get-Command` and `Get-FileHash` entirely (~5ms cache
  validation + ~120ms OMP init + ~30ms zoxide init). Config paths resolved
  inline (no function overhead). Fingerprint uses `LastWriteTime` + file size
  (not SHA256). Boot time color-coded: Green < 300ms, Yellow < 600ms,
  Red > 600ms. Run `tests/benchmark.ps1` to measure your machine.
- **TTL Cache System**: Third-party plugins (`oh-my-posh`, `zoxide`) cached
  with 24-hour TTL. Cache header includes fingerprint + Unix timestamp; valid
  TTL skips `Get-Command` and fingerprint recalculation entirely.
- **CLI-first Installer**: Interactive terminal setup by default. Optional WPF
  GUI supports OMP theme selection, Windows Terminal themes, and component logs.
- **CONFIG_PWSH7_THEME Env Var**: OMP theme selection is read during profile
  loading. The managed stub sets an installation-selected theme before loading;
  an inherited value is used only when the stub does not assign one.
- **Windows Installer**: Per-user WinGet installs, optional Scoop fallback when
  WinGet is missing, dynamic paths via `[Environment]::GetFolderPath`, stable
  GitHub Release downloads, and convergent repeat runs.
- **Per-User Profile**: Profile linking needs no elevation or symlinks. It
  maintains a marked block in `$PROFILE.CurrentUserAllHosts` without replacing
  user content. Package installs start in user scope.
- **Strict-Mode Loading**: Profile modules load with
  `Set-StrictMode -Version Latest`; the interactive shell's error preference is
  restored afterwards. Regression suites exercise failure paths. Profile load
  guards stay process-local and are not inherited by child shells.
- **Windows Target**: Installer supports Windows 10/11 x64. Profile modules
  retain graceful platform checks on Linux and macOS.
- **Dynamic Boot Summary**: Clean boot report with platform info, loaded
  modules, and admin status.

## Documentation

- [Installation & Compatibility](docs/installation.md)
- [Modules, Features & Technical Reference](docs/modules.md)
- [Troubleshooting & Tests](docs/troubleshooting.md)
- [Windows 10/11 compatibility audit](docs/auditoria-windows.md)

---

## Architecture Overview

The profile is structured into strict modular components for isolation and
fault tolerance:

```text
config-powershell7/
├── .github/workflows/          # CI/CD (GitHub Actions)
├── Microsoft.PowerShell_profile.ps1 # Entrypoint Profile (Loader)
├── install.ps1                 # Compatibility wrapper that forwards to setup.ps1
├── setup.ps1                   # Main installer entry point (CLI or optional GUI)
├── uninstall.ps1               # Safe uninstaller (backup + cache cleanup)
├── install.cmd / uninstall.cmd # Double-click launchers (Windows)
├── setup/
│   ├── modules/
│   │   ├── core.ps1            # Logging, platform detection, constants
│   │   ├── deps.ps1            # Dependency installers (WinGet, fonts, themes)
│   │   ├── agent-clis.ps1      # Optional coding-agent CLI installers
│   │   ├── profile.ps1         # Profile link management
│   │   ├── orchestrator.ps1    # Install/uninstall orchestration
│   │   ├── gui.ps1             # WPF XAML UI with runspace logging
│   │   └── cli.ps1             # Terminal menu (CI/non-interactive fallback)
│   └── setup.ps1               # Module loader/dispatcher
├── lib/
│   ├── platform.ps1            # Cross-platform detection + elevation
│   ├── ux-helpers.ps1          # Console output helpers
│   └── executable.ps1          # Executable discovery and version probing
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
    ├── ThemeOverride.Tests.ps1 # 6 env-var theme override tests
    ├── WindowsCompatibility.Tests.ps1 # Isolated Windows regression tests
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

> Opens CLI menu by default. Use `-Gui` from a local clone for WPF.

**Option B — WPF GUI (Windows):**

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
.\setup.ps1 -Gui
```

> Graphical installer with OMP theme preview and Windows Terminal color swatches.

**Option C — Headless/CI compatibility wrapper:**

```powershell
.\install.ps1 -NonInteractive
```

**Uninstall:**

> Double-click `uninstall.cmd` or run `.\uninstall.ps1`.

---

## Requirements

- **Windows 10/11 x64** for the automated installer; PowerShell 5.1 can launch
  setup, which resolves or installs PowerShell 7 and delegates to it.
- **PowerShell 7.x** for the managed profile. Manual PS5.1 use has reduced
  features; Linux/macOS platform checks do not constitute installer support.
- **FiraCode Nerd Font** (for icons/ligatures)
- **Windows Terminal** (optional; any terminal that supports PowerShell works)
- **Git** (required for Git aliases)
- **Oh My Posh** (optional — prompt theming)
- **Zoxide** (optional — smart directory navigation)
- **Terminal-Icons** (optional — file icons in listings)

## CONFIG_PWSH7_THEME (Theme at Profile Load)

Set `$env:CONFIG_PWSH7_THEME` before the initial profile load to choose a theme:

```powershell
$env:CONFIG_PWSH7_THEME = 'montys'
```

The profile reads this variable each session. Unset or empty falls back to
`atomic`. A selected installation theme is assigned by the managed profile
block; a missing custom file also falls back to `atomic` with a warning.
Assigning the variable after loading does not reinitialize the current prompt.
Use setup to change the managed theme persistently, then open a new session.

## Startup Directory

The profile preserves the terminal's current working directory by default. On
Windows, elevated shells opening in `System32` or `SysWOW64` redirect to
`POWERSHELL_START_DIR` when valid, otherwise to `$HOME`.

```powershell
Set-ProfileStartDirectory "$HOME"
Get-ProfileStartDirectory
Clear-ProfileStartDirectory
```
