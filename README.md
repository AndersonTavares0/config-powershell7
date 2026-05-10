# PowerShell Config (PS7)

> High-performance, modular PowerShell 7+ startup profile optimized for developer ergonomics.
> Perfil de inicialização modular e de alta performance para PowerShell 7+, otimizado para ergonomia.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions)
![Pester](https://img.shields.io/badge/Test-Pester_5.x-cf4647?logo=powershell)
![Oh My Posh](https://img.shields.io/badge/Prompt-Oh_My_Posh-4b32c3)
![Zoxide](https://img.shields.io/badge/Nav-Zoxide-purple)
![PSReadLine](https://img.shields.io/badge/Input-PSReadLine-darkgreen?logo=powershell)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

## Key Technical Features / Principais Recursos Tecnicos

- **Extreme Performance**: Optimized boot sequence with TTL-based plugin cache (60 min). Hot path skips `Get-Command` and SHA256 fingerprint entirely, achieving ~5ms overhead. Boot time color-coded: 🟢 Green < 300ms, 🟡 Yellow < 600ms, 🔴 Red > 600ms.
- **TTL Cache System**: Third-party plugins (`oh-my-posh`, `zoxide`) are cached with a 60-minute Time-To-Live. Cache header includes fingerprint + Unix timestamp; when TTL is valid, `Get-Command` and fingerprint recalculation are skipped entirely.
- **Zero-Elevation Installer**: No symlinks, no UAC prompts. The installer writes a lightweight `$PROFILE` file that dot-sources the repository via `$env:__PROFILE_REPO_ROOT`, ensuring 100% path resolution without Administrator privileges.
- **Strict-Mode Compliant**: Entire codebase passes `Set-StrictMode -Version Latest` — zero uninitialized variables, no hidden scoping bugs. Code Quality Guide enforced: no bare `catch {}`, no silent failures. Globals migrated to environment variables (`$env:__PROFILE_LOADED`, `$env:__PROFILE_REPO_ROOT`).
- **Cross-Platform**: Full support for Windows, Linux (Fedora), and macOS with graceful degradation per platform.
- **Dynamic Boot Summary**: Clean, highlighted boot report with platform info, loaded modules, and admin status.

## Documentation / Documentacao

Choose your preferred language / Escolha seu idioma preferido:

- 🇺🇸 **English Documentation**: [`docs/en/`](docs/en/)
  - [Installation & Compatibility](docs/en/installation.md)
  - [Modules, Features & Technical Reference](docs/en/modules.md)
  - [Troubleshooting & Tests](docs/en/troubleshooting.md)

- 🇧🇷 **Documentacao em Portugues**: [`docs/pt-br/`](docs/pt-br/)
  - [Instalacao e Compatibilidade](docs/pt-br/installation.md)
  - [Modulos, Recursos e Referencia Tecnica](docs/pt-br/modules.md)
  - [Solucao de Problemas e Testes](docs/pt-br/troubleshooting.md)

---

## Architecture Overview / Visao Geral da Arquitetura

The profile is structured into strict modular components for isolation and fault tolerance:

```text
config-powershell7/
├── .github/workflows/          # CI/CD (GitHub Actions) — 1 pipeline
├── Microsoft.PowerShell_profile.ps1 # Entrypoint Profile (Loader)
├── install.ps1                 # Automated Installer (Zero-UAC)
├── uninstall.ps1               # Safe Uninstaller (backup + cache cleanup)
├── install.cmd                 # Double-click installer (Windows)
├── uninstall.cmd               # Double-click uninstaller (Windows)
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
└── tests/                      # Test Suites (custom + Pester)
```

**Loading order** (critical): config → cache → navigation → git → system → psreadline → text_utils

---

## Quick Start / Inicio Rapido

**Option A — Double-click (Windows):**

> Clone the repo and double-click `install.cmd`.

**Option B — Terminal:**

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
.\install.ps1
```

**Uninstall / Desinstalar:**

> Double-click `uninstall.cmd` or run `.\uninstall.ps1`.

---

## Requirements / Requisitos

- **PowerShell 7.x** (Core) highly recommended (supports PS 5.1 Legacy via graceful degradation)
- **FiraCode Nerd Font** (for icons/ligatures)
- **Alacritty** or **Windows Terminal**
- **Git** (required for Git aliases)
- **Oh My Posh** (optional — prompt theming)
- **Zoxide** (optional — smart directory navigation)
- **Terminal-Icons** (optional — file icons in listings)
