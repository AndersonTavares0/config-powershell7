# config-powershell7 — AGENTS.md

## Architecture

- **Entrypoint**: `Microsoft.PowerShell_profile.ps1` — dot-sourced by `$PROFILE`
- **Install**: `install.ps1` sets `$env:__PROFILE_REPO_ROOT` then dot-sources the profile
- **Loading order is critical**: config (0) → cache (1) → navigation → git → system → psreadline → text_utils
- **psreadline** is its own module (`modules/psreadline/`), not nested under `system/`
- Config (`modules/config/config.ps1`) is mandatory; all other modules are try/catch wrapped (non-critical)
- Internal modules use **dot-sourcing** (`. $path`), not `Import-Module`
- Shared libs in `lib/`: `platform.ps1`, `ux-helpers.ps1`, `profile-paths.ps1`
- Plugin boot cache (`modules/cache/cache.ps1`): TTL-based, skips SHA256 hash on hot path (~5ms)

## Conventions

- `Set-StrictMode -Version Latest` everywhere — no uninitialized vars, no hidden scoping
- `$script:` scope for module-private variables, `$env:` for `__PROFILE_REPO_ROOT` and `__PROFILE_LOADED` (migrated from `$global:`)
- `#Requires -Version 5.1` at top of all runnable scripts
- Lazy loading via aliases (e.g. `icons` → `Import-TerminalIcons` → Terminal-Icons module)
- English function names, bilingual docs (`docs/en/`, `docs/pt-br/`)

## Tests

Custom framework (not Pester) — functions: `Test-Result`, `Test-Skip`, `Assert-True`, `Assert-Equal`, etc.

```powershell
# Full test suite (runs both files)
.\tests\Test-ProfileInstallation.ps1 -Detailed
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose
```

CI (`.github/workflows/test.yml`) copies profile + modules to `$PROFILE` path, then runs both on push/PR to `main`.

## Key Commands

```powershell
# Install (no elevation needed)
.\install.ps1

# Uninstall
.\uninstall.ps1

# After sourcing, diagnostics available:
Test-ProfileInstallation
```
