# PowerShell Config (PS7)

> High-performance, modular PowerShell 7 startup profile optimized for developer ergonomics.
> Perfil de inicialização modular e de alta performance para PowerShell 7, otimizado para ergonomia.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![Tests](https://img.shields.io/badge/CI-Configured-blue?logo=github-actions&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

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

The profile is structured into modular components for easier maintenance:

```text
config-powershell7/
├── .github/workflows/          # CI/CD (GitHub Actions)
├── Microsoft.PowerShell_profile.ps1
├── install.ps1                 # Automated Installer
├── modules/                    # Modular Logic
│   ├── cache/
│   ├── git/
│   ├── navigation/
│   ├── system/
│   └── text_utils/
├── tests/                      # Unit Tests
└── docs/                       # Bilingual Documentation
```

---

## 🚀 Quick Start / Início Rápido

```powershell
# Clone and run the automated installer (Run as Administrator)
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
.\install.ps1
```

---

## ⚙️ Requirements / Requisitos

- **PowerShell 7.x** (Core) recommended (supports PS 5.1 Legacy)
- **FiraCode Nerd Font** (for icons/ligatures)
- **Alacritty** (recommended) or Windows Terminal