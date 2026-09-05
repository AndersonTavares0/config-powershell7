# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### CI
- `validate.yml`: full validation workflow (suites on PR, disposable-runner
  end-to-end installer on manual dispatch with idempotency, theme-change,
  child-shell, failure-propagation, and uninstall checks)

### Added
- Managed Alacritty configuration with PowerShell 7 shell, Nerd Font, theme
  fragments, validation, legacy YAML migration, and reversible user overrides
- Regression coverage for repeat installs, profile preservation, path escaping,
  Alacritty adoption, and configuration restoration

### Changed
- Installer now targets the PowerShell 7 `CurrentUserAllHosts` profile and
  updates a marked block without replacing user-owned profile content
- Remote installs use the latest stable GitHub Release and stage repository
  replacement before activation
- Default managed repository location moved from Documents to
  `LocalApplicationData` to avoid OneDrive redirection
- `install.cmd` now invokes the modular `setup.ps1` flow
- Execution policy is inspected and reported instead of changed silently
- Profile load guards now use process-local PowerShell variables, preventing
  child shells from skipping profile initialization
- Alacritty is enabled by default and requires version 0.14 or newer

## [v0.3] — 2026-07-07

### Added
- Bootstrapper user agency: `irm | iex` now shows summary, asks for
  install directory, and requires explicit consent before downloading
- Local flow (`.\setup.ps1` in valid repo) delegates directly to launcher
  with zero prompts
- Headless mode (`-NonInteractive` / `$env:CI`) skips prompts, uses defaults
- Overwrite safety: existing directory without valid repo asks confirmation
  before replacing
- Download-Repo creates parent directory before extraction (handles deep
  custom install paths)
- Input sanitization: `Read-Host` output trimmed to avoid leading/trailing
  spaces in path

### Changed
- `setup.ps1` refactored as bootstrapper with 3 flows (local, remote, headless)
- Removed temp-location heuristics (`Test-IsTempLocation`, `Resolve-RepoPath`)
- Added `-NonInteractive` parameter

### Tests
- `tests/Setup.Tests.ps1`: +27 bootstrapper tests (53 → 80):
  - Syntax, content assertions, behavioral `Test-IsValidRepo` with mock dirs
  - AST verification of flow branches (local, headless, consent, overwrite)
  - AST verification of Download-Repo (try/catch, parent dir, cleanup, return)
  - AST verification of Invoke-Launcher (Test-Path, dot-source)

### CI
- `.github/workflows/test.yml`: `Setup.Tests.ps1` added to CI pipeline

## [v0.2] — 2026-07

### Added
- Post-install summary agora exibe Theme, Cache e Terminal message,
  substituindo bloco de versões de ferramentas (#52)
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
- WPF GUI installer redesigned with VS Code dark palette (`#1E1E1E`,
  `#569CD6` accent)
- OMP theme selection at install time with live prompt bar preview
  (segment-level foreground/background colors from theme JSON)
- Terminal color theme selection (Catppuccin, Dracula, Nord, Tokyo Night,
  One Half Dark) for Windows Terminal and Alacritty
- Topgrade optional install (universal package updater)
- ScrollViewer, layout rounding, and keyboard navigation in GUI for
  accessibility and HiDPI support
- OMP theme list loaded asynchronously via background job (no UI freeze)
- Terminal theme section collapses when checkbox unchecked

### Changed
- GUI installer label clarified: "Install Alacritty terminal emulator"
- Chocolatey removed from GUI/orchestrator flow (still available via CLI)
- Removed "Required: PSReadLine + Terminal-Icons" text from GUI
- `InstallModules` always `$true` from GUI (modules are non-optional)
- All paths use `[Environment]::GetFolderPath()` — no hardcoded user paths
- Em dashes (`—`) replaced with hyphens in source to fix PS 5.1 parser issues

### Fixed
- tests/Setup.Tests.ps1: parser error "Missing closing '}'" causado por
  em dash `—` (U+2014) na linha 495 — substituído por hífen comum
- Microsoft.PowerShell_profile.Tests.ps1: parser não reconhecia `catch`
  como keyword na linha 504 — adicionado UTF-8 BOM (#70)
- Test-ProfileInstallation.ps1: Missing closing `}` falso positivo nas
  linhas 45/59 — adicionado UTF-8 BOM (#71)
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
- install.ps1: UTF-8 corruption in error messages with em dashes causing
  parser failures
- install.ps1: outdated CLI menus updated for new dependency options
- setup/modules/gui.ps1: unused variables in OMP preview handler removed

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

[Unreleased]: https://github.com/AndersonTavares0/config-powershell7/compare/v0.3...HEAD
[v0.3]: https://github.com/AndersonTavares0/config-powershell7/releases/tag/v0.3
[v0.2]: https://github.com/AndersonTavares0/config-powershell7/releases/tag/v0.2
[v0.1]: https://github.com/AndersonTavares0/config-powershell7/releases/tag/v0.1
