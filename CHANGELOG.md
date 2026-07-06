# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Suporte a `POSH_THEME` env var para seleção de tema do Oh My Posh
  via ambiente, com fallback para `$script:Config.ThemePath`
- Testes isolados para o mecanismo `POSH_THEME`
  (`tests/POSH_THEME.Tests.ps1`)
- System32/SysWOW64 startup guard — redirect independente de módulos,
  executa antes do config.ps1 para proteger sessões Admin
- Unit tests para lógica interna dos módulos (`tests/Unit.Tests.ps1`):
  - Cache: 14 ACs — fingerprints, TTL hot/cold, rebuild, clear (CACHE-01–14)
  - System: 10 ACs — pubip cache/fallback, sudo sanitização (SYS-01–10)
  - Text utils: 9 ACs — sed validação/backup/cleanup, clipboard, touch (TEXT-01–09)
  - Git: 9 ACs — gcom/lazyg LASTEXITCODE branching (GIT-01–09)
  - 88 asserções, zero dependências externas, ~350ms total

### Fixed
- install.ps1: removido passo duplicado de instalação do PowerShell 7
- install.ps1: `$targetProfile` agora exibe caminho correto no sumário
- install.ps1: detecção de executáveis via `-CommandName` explícito
  (substitui regex frágil que quebrava para `oh-my-posh` e `pwsh`)
- Cache de plugins invalidado imediatamente ao trocar tema, mesmo
  dentro da janela TTL (issue #46)
- system.ps1: caminhos hardcoded `/usr/bin/*` substituídos por
  `Get-Command` com nome simples (compatível com macOS ARM, Linux
  não-standard)
- setup/modules/deps.ps1: detecção de executáveis centralizada via
  `Get-Executable` com exibição de versão
- install.ps1: sumário final exibe versão de cada ferramenta instalada
- setup/modules/orchestrator.ps1: sumário final exibe versão de cada
  ferramenta instalada

### Fixed
- Microsoft.PowerShell_profile.Tests.ps1: parser não reconhecia `catch`
  como keyword na linha 504 — adicionado UTF-8 BOM (#70)
- Test-ProfileInstallation.ps1: Missing closing `}` falso positivo nas
  linhas 45/59 — adicionado UTF-8 BOM (#71)

## [v0.1] — 2026-07

### Added
- Modular PowerShell profile with strict-mode compliance
- TTL-based plugin cache (24h) for oh-my-posh and zoxide
- Cross-platform support (Windows, Linux, macOS)
- WPF GUI installer with terminal fallback
- Zero-elevation profile linking
- PSReadLine configuration with history prediction (PS 7+)
- Git aliases and utilities (gst, ga, gcmt, gco, gpush, gpull, glog, gundo, gdiff, gcl, gcom, lazyg)
- System utilities (sudo, pkill, pgrep, flushdns, df, pubip, sysinfo)
- Text utilities (touch, which, unzip, head, tail, grep, sed, clip)
- 3 test suites + boot benchmark (custom framework)
- GitHub Actions CI pipeline

[Unreleased]: https://github.com/AndersonTavares0/config-powershell7/compare/v0.1...HEAD
[v0.1]: https://github.com/AndersonTavares0/config-powershell7/releases/tag/v0.1
