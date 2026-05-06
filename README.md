# PowerShell Config (PS7)

> High-performance, modular PowerShell 7 startup profile optimized for developer ergonomics.
> Perfil de inicialização modular e de alta performance para PowerShell 7, otimizado para ergonomia.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![Performance](https://img.shields.io/badge/Boot-Sub_300ms-brightgreen)
![Status](https://img.shields.io/badge/Status-Industrial_Stable-brightgreen)

## ⚡ Key Technical Features / Principais Recursos Técnicos

*   **Extreme Performance (Sub 300ms)**: Heavily optimized boot sequence with conditional lazy loading. Non-critical modules (like `Terminal-Icons`) are loaded on-demand via aliases (e.g., `icons`), slicing boot times by over 50%.
*   **TTL Cache System**: Third-party plugins (`oh-my-posh`, `zoxide`) are cached intelligently with a 30-minute Time-To-Live. The custom MD5 hashing completely skips hash evaluation during the hot path, achieving near-zero overhead (`~5ms`).
*   **Zero-Elevation Installer**: Migrated away from symbolic links. The installer dynamically dot-sources the profile (`$global:__ProfileRepoRoot`), ensuring 100% path resolution accuracy without ever triggering UAC Administrator prompts.
*   **Strict-Mode Compliant**: The entire codebase passes `Set-StrictMode -Version Latest`, ensuring absolutely zero uninitialized variables or hidden scoping bugs.
*   **Dynamic Visual Boot Summary**: Displays a clean, highlighted boot report with dynamic colors based on performance (🟢 Green < 300ms, 🟡 Yellow < 600ms, 🔴 Red > 600ms).

## 📖 Documentation / Documentação

Choose your preferred language / Escolha seu idioma preferido:

- 🇺🇸 **English Documentation**: [`docs/en/`](docs/en/)
  - [Installation & Compatibility](docs/en/installation.md)
  - [Modules, Features & Technical Reference](docs/en/modules.md)
  - [Troubleshooting & Tests](docs/en/troubleshooting.md)

- 🇧🇷 **Documentação em Português**: [`docs/pt-br/`](docs/pt-br/)
  - [Instalação e Compatibilidade](docs/pt-br/installation.md)
  - [Módulos, Recursos e Referência Técnica](docs/pt-br/modules.md)
  - [Solução de Problemas e Testes](docs/pt-br/troubleshooting.md)

---

## 🏗 Architecture Overview / Visão Geral da Arquitetura

The profile is structured into strict modular components for isolation and fault tolerance:

```text
config-powershell7/
├── .github/workflows/          # CI/CD (GitHub Actions)
├── Microsoft.PowerShell_profile.ps1 # Entrypoint Profile
├── install.ps1                 # Automated Installer (Zero-UAC)
├── install.cmd                 # Installer (double-click on Windows)
├── modules/                    # Modular Logic
│   ├── cache/                  # TTL Cache Engine & Lazy Loaders
│   ├── git/                    # Git shortcuts
│   ├── navigation/             # Directory shortcuts
│   ├── system/                 # System/Network shortcuts
│   └── text_utils/             # Unix-like tools (grep, tail)
└── tests/                      # Unit Tests (Strict-Mode Ready)
```

---

## 🚀 Quick Start / Início Rápido

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

## ⚙️ Requirements / Requisitos

- **PowerShell 7.x** (Core) highly recommended (supports PS 5.1 Legacy via graceful degradation)
- **FiraCode Nerd Font** (for icons/ligatures)
- **Alacritty** or Windows Terminal
