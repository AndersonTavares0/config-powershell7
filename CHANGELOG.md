# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- SECURITY.md com link para GitHub Private Vulnerability Reporting
- CONTRIBUTING.md com guia mínimo para contribuidores
- .editorconfig para padronização cross-editor
- .gitattributes para normalização de line endings
- Badge de CI dinâmico no README (estado real do build)
- Branch protection ativada na main (PR + CI obrigatórios)
- System32/SysWOW64 startup guard — redirect independente de módulos,
  executa antes do config.ps1 para proteger sessões Admin

### Changed
- LICENSE: adicionado copyright holder (Anderson Tavares, 2026)
- PR template: corrigido caminho dos testes (tab → `.\tests\`)
- CI: adicionado PSScriptAnalyzer (erros bloqueiam, warnings informativos)
- AGENTS.md: removidas seções stale, adicionado PR/release workflow
  e tabela de governance files

### Fixed
- install.ps1: removido passo duplicado de instalação do PowerShell 7
- install.ps1: `$targetProfile` agora exibe caminho correto no sumário
- install.ps1: detecção de executáveis via `-CommandName` explícito
  (substitui regex frágil que quebrava para `oh-my-posh` e `pwsh`)

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
