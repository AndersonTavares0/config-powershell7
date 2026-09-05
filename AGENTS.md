# config-powershell7 — AGENTS.md

## Architecture

- **Entrypoint**: `Microsoft.PowerShell_profile.ps1` -- dot-sourced by
  `$PROFILE` (or via installer stub)
- **Double-load guard**: process-local
  `$global:__CONFIG_POWERSHELL7_PROFILE_LOADED`; child shells do not inherit it
- **Repo root resolution**: `$script:ProfileRoot` uses `$PSScriptRoot`
- **Installer profile target**: `$PROFILE.CurrentUserAllHosts`; installer owns
  only its marked block and preserves surrounding user content
- **Managed install root**: Windows defaults to
  `[Environment]::GetFolderPath('LocalApplicationData')\config-powershell7`
- **Loading order is critical**: config (0) -> cache (1) -> navigation -> git
  -> system -> psreadline -> text_utils
- **Config is mandatory**: missing `modules/config/config.ps1` causes early
  return; all other modules are try/catch wrapped
- **Config paths inline on Windows**: `CachePath` and `ThemePath` resolved
  inline (no functions) to avoid function definition + parameter binding
  overhead
- **Modules use dot-sourcing** (`. $path`), not `Import-Module`
- **psreadline** is its own module (`modules/psreadline/`), not nested under
  `system/`
- **Platform detection split**: `lib/platform.ps1` is for standalone scripts;
  modules use inline detection in config.ps1 via `$script:Config`
- **Shared libs** in `lib/`: `platform.ps1` (detection), `ux-helpers.ps1`
  (Write-Ok/Warn/Fail/Info/Step), `profile-paths.ps1` (Get-TargetProfilePath)
- **Plugin boot cache** (`modules/cache/cache.ps1`): 24h TTL skips
  `Get-Command` + `Get-FileHash` on hot path (~5ms validation, ~120ms OMP
  init). Uses `LastWriteTime` + file size (not SHA256) for fingerprint. Cache
  file: `$HOME\.cache_pwsh_plugins.ps1` (Windows) or
  `$XDG_CACHE_HOME/pwsh/plugins_cache.ps1` (Linux/macOS)
- **`gcm` collision**: `gcm` is a native PS alias for `Get-Command` -- git
  commit uses `gcmt`, not `gcm`

## Conventions

- `Set-StrictMode -Version Latest` everywhere -- no uninitialized vars, no
  hidden scoping
- `$script:` scope for module-private vars; process-local `$global:` variables
  only for profile load and unblock guards
- `#Requires -Version 5.1` at top of all runnable scripts
- `[SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]` on `param()`
  blocks (not file-level)
- Lazy loading via aliases (e.g. `icons` -> `Import-TerminalIcons` ->
  Terminal-Icons module)
- Navigation paths (`docs`, `dtop`) use lazy-init
  `[Environment]::GetFolderPath` (saves ~2-6ms at boot)
- No bare `catch {}` -- always log `$_.Exception.Message`

## POSH_THEME

- `$env:POSH_THEME` overrides the OMP theme at runtime. Profile reads it
  each session. Unset/empty falls back to `atomic`. The installer sets this
  in the profile stub.

## Commands

```powershell
# Install -- WPF GUI (Windows):   install.cmd  (calls setup.ps1)
# Install -- headless/CLI:        .\setup.ps1  (auto-detects WPF, falls back to CLI)
# Install -- legacy (CI):         .\install.ps1 -NonInteractive
# Uninstall:                      .\uninstall.ps1
# Remote one-liner:               irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex
# Post-source diagnostic:         Test-ProfileInstallation
# Release (tag + GitHub Release): git tag -a v<versao> -m "mensagem" && git push origin v<versao> && gh release create v<versao> --title "v<versao>" --notes-file CHANGELOG.md
```

## PR Workflow

- **PR template obrigatorio**: todo PR deve usar
  `.github/pull_request_template.md` -- preencher todos os campos, nao criar
  body do zero
- **Branch protection**: `main` exige PR + CI passando -- sem push direto
- **CHANGELOG.md**: atualizar em todo PR que adiciona, modifica ou remove
  comportamento
- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`,
  `chore:`, `ci:`

## Tests

Custom framework (not Pester) -- functions: `Test-Result`, `Test-Skip`,
`Assert-True`, `Assert-Equal`, `Assert-NotNull`, `Assert-False`.

```powershell
.\tests\Unit.Tests.ps1                              # unit tests (fastest feedback)
.\tests\POSH_THEME.Tests.ps1                        # 5 POSH_THEME env-var tests
.\tests\Test-ProfileInstallation.ps1 -Detailed      # post-install health checks
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose  # Behavioral integration
.\tests\Setup.Tests.ps1 -Verbose                     # setup module tests
.\tests\benchmark.ps1 -Runs 10                       # profile boot timing; compare cold/warm cache
```

CI (`.github/workflows/test.yml`) roda em push/PR na `main`: setup profile ->
PSScriptAnalyzer -> unit tests. Windows-only runner. PSScriptAnalyzer:
**erros bloqueiam CI, warnings sao informativos** (~184 warnings
preexistentes ignorados).

## Governance files

| File | Location | Purpose |
|---|---|---|
| `SECURITY.md` | root | Vulnerability reporting via PVR |
| `CONTRIBUTING.md` | `.github/` | Minimal contributor guide |
| `CHANGELOG.md` | root | Version history (update per PR) |
| `.editorconfig` | root | Editor-agnostic formatting |
| `.gitattributes` | root | Line ending normalization |
