# config-powershell7 — AGENTS.md

## Architecture

- **Entrypoint**: `Microsoft.PowerShell_profile.ps1` — dot-sourced by `$PROFILE` (or via installer stub)
- **Double-load guard**: `$env:__PROFILE_LOADED` — profile returns early if already set
- **Repo root resolution**: `$script:ProfileRoot` uses `$env:__PROFILE_REPO_ROOT`, falls back to `$PSScriptRoot`
- **Loading order is critical**: config (0) → cache (1) → navigation → git → system → psreadline → text_utils
- **Config is mandatory**: missing `modules/config/config.ps1` causes early return; all other modules are try/catch wrapped
- **Config paths inline on Windows**: `CachePath` and `ThemePath` resolved inline (no functions) to avoid function definition + parameter binding overhead
- **Modules use dot-sourcing** (`. $path`), not `Import-Module`
- **psreadline** is its own module (`modules/psreadline/`), not nested under `system/`
- **Platform detection split**: `lib/platform.ps1` is for standalone scripts; modules use inline detection in config.ps1 via `$script:Config`
- **Shared libs** in `lib/`: `platform.ps1` (detection), `ux-helpers.ps1` (Write-Ok/Warn/Fail/Info/Step), `profile-paths.ps1` (Get-TargetProfilePath)
- **Plugin boot cache** (`modules/cache/cache.ps1`): 24h TTL skips `Get-Command` + `Get-FileHash` on hot path (~5ms validation, ~120ms OMP init). Uses `LastWriteTime` + file size (not SHA256) for fingerprint. Cache file: `$HOME\.cache_pwsh_plugins.ps1` (Windows) or `$XDG_CACHE_HOME/pwsh/plugins_cache.ps1` (Linux/macOS)
- **`gcm` collision**: `gcm` is a native PS alias for `Get-Command` — git commit uses `gcmt`, not `gcm`

## Conventions

- `Set-StrictMode -Version Latest` everywhere — no uninitialized vars, no hidden scoping
- `$script:` scope for module-private vars, `$env:` for `__PROFILE_REPO_ROOT` and `__PROFILE_LOADED`
- `#Requires -Version 5.1` at top of all runnable scripts
- `[SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]` on `param()` blocks (not file-level)
- Lazy loading via aliases (e.g. `icons` → `Import-TerminalIcons` → Terminal-Icons module)
- Navigation paths (`docs`, `dtop`) use lazy-init `[Environment]::GetFolderPath` (saves ~2-6ms at boot)
- No bare `catch {}` — always log `$_.Exception.Message`

## Commands

```powershell
# Install — WPF GUI (Windows):   install.cmd  (calls setup.ps1)
# Install — headless/CLI:        .\setup.ps1  (auto-detects WPF, falls back to CLI)
# Install — legacy (CI):         .\install.ps1 -NonInteractive
# Uninstall:                     .\uninstall.ps1
# Remote one-liner:              irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex
# Post-source diagnostic:        Test-ProfileInstallation
```

## Tests

Custom framework (not Pester) — functions: `Test-Result`, `Test-Skip`, `Assert-True`, `Assert-Equal`, `Assert-NotNull`, `Assert-False`.

```powershell
.\tests\Test-ProfileInstallation.ps1 -Detailed           # 64 post-install health checks
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose   # Behavioral integration tests
.\tests\Setup.Tests.ps1 -Verbose                          # 32 TDD tests for setup modules
.\tests\benchmark.ps1 -Runs 10                            # Profile boot timing (fresh pwsh processes)
```

CI (`.github/workflows/test.yml`) copies profile + modules to `$PROFILE` path, runs all 3 suites on push/PR to `main`. Windows-only runner.

## GSD Workflow

Project planning lives in `.planning/`. Standard GSD loop for each phase:

```
/gsd-plan-phase <N>       # plan → research → verify
/gsd-execute-phase <N>    # execute all plans in phase
/gsd-discuss-phase <N>    # gather context before planning
/gsd-progress              # check status, advance workflow
```

**Current phase:** Phase 1 (Defensive Hardening) — Fix PSReadLine history bloat, UTF-8 encoding guard, atomic cache writes, Reload-Profile function.

**Config:** YOLO mode (auto-approve), coarse granularity (5 phases), parallel execution.

**Roadmap:** 5 phases, 29 v1 requirements total.

## Knowledge Graph

`graphify-out/` contains a local knowledge graph (gitignored — not present after fresh clone). Regenerate with:

```
/graphify
```
