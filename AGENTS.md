# config-powershell7 — AGENTS.md

## Architecture

- **Entrypoint**: `Microsoft.PowerShell_profile.ps1` — dot-sourced by `$PROFILE` (or via installer stub)
- **Double-load guard**: `$env:__PROFILE_LOADED` at line 16 — profile returns early if already set
- **Repo root resolution**: `$script:ProfileRoot` uses `$env:__PROFILE_REPO_ROOT`, falls back to `$PSScriptRoot`
- **Loading order is critical**: config (0) → cache (1) → navigation → git → system → psreadline → text_utils
- **Config is mandatory**: missing `modules/config/config.ps1` causes early return; all other modules are try/catch wrapped (non-critical)
- **Modules use dot-sourcing** (`. $path`), not `Import-Module`
- **psreadline** is its own module (`modules/psreadline/`), not nested under `system/`
- **Platform detection split**: `lib/platform.ps1` is for standalone scripts (install/uninstall/tests); modules use inline detection in `config.ps1` via `$script:Config`
- **Shared libs** in `lib/`: `platform.ps1` (detection), `ux-helpers.ps1` (Write-Ok/Warn/Fail/Info/Step), `profile-paths.ps1` (Get-TargetProfilePath)
- **Plugin boot cache** (`modules/cache/cache.ps1`): TTL-based (24h), skips `Get-Command` and `Get-FileHash` on hot path (~5ms cache validation, ~120ms OMP init execution). Uses `LastWriteTime` + file size (not SHA256) for change detection. Cache file at `$HOME\.cache_pwsh_plugins.ps1` (Windows) or `$XDG_CACHE_HOME/pwsh/plugins_cache.ps1` (Linux)
- **Setup GUI installer** (`setup/`): Modular WPF GUI installer with CLI fallback. Entry point `setup.ps1` delegates to `setup/setup.ps1`. Six sub-modules: `core.ps1`, `deps.ps1`, `profile.ps1`, `orchestrator.ps1`, `gui.ps1`, `cli.ps1`. Runspace-based UI with synchronized logging via `[hashtable]::Synchronized()`.
- **TDD test suite** (`tests/Setup.Tests.ps1`): 32 assertions covering `Write-GuiLog`, `Get-WingetPath`, `Get-ProfilePath`, `Install-Profile`, `Uninstall-Profile`, orchestrator dry-run, and syntax validation.

## Conventions

- `Set-StrictMode -Version Latest` everywhere — no uninitialized vars, no hidden scoping
- `$script:` scope for module-private variables, `$env:` for `__PROFILE_REPO_ROOT` and `__PROFILE_LOADED`
- `#Requires -Version 5.1` at top of all runnable scripts
- `[SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]` on `param()` blocks (not file-level) — used in profile, install, ux-helpers to suppress PSScriptAnalyzer
- Lazy loading via aliases (e.g. `icons` → `Import-TerminalIcons` → Terminal-Icons module)
- English function names, documentation in `docs/`
- No bare `catch {}` — always log `$_.Exception.Message`

## Tests

Custom framework (not Pester) — functions: `Test-Result`, `Test-Skip`, `Assert-True`, `Assert-Equal`, etc.

```powershell
# CI runs these 3 files (all use custom framework):
.\tests\Setup.Tests.ps1                                  # 32 setup module TDD tests
.\tests\Test-ProfileInstallation.ps1 -Detailed          # 64 post-install checks
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose  # Behavioral integration tests
```

CI (`.github/workflows/test.yml`) copies profile + modules to `$PROFILE` path, runs all 3 suites on push/PR to `main`.

## Knowledge Graph

`graphify-out/` contains a persistent knowledge graph of this repo (126 nodes, 135 edges, 21 communities). Query it with:

```powershell
/graphify query "<question>"
# or trace a specific path:
/graphify query "<question>" --dfs
```

## Key Commands

```powershell
# Install (no elevation needed)
.\install.cmd                    # double-click WPF GUI (Windows)
.\install.ps1                    # legacy headless CLI (CI/test compat)
.\setup.ps1                      # new GUI/CLI installer entry point

# Uninstall
.\uninstall.ps1
.\uninstall.cmd

# After sourcing, diagnostics available:
Test-ProfileInstallation
```
