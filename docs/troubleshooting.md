# Troubleshooting & Tests

## Troubleshooting

### Profile does not load

**Symptom:** no aliases or functions available after opening the terminal.

**Solution:**

```powershell
# Check if the profile exists
Test-Path $PROFILE

# Check which file is being loaded
$PROFILE

# Manually reload
. $PROFILE
```

### Execution Policy error

**Symptom:** `"File cannot be loaded because running scripts is disabled on this system."`

**Solution:**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### File blocked by Windows

**Symptom:** `"The file is not digitally signed."`

**Solution:**

```powershell
Get-ChildItem *.ps1 | Unblock-File
```

### Command not recognized after installation

**Symptom:** `"The term 'gst' is not recognized..."`

**Cause:** Git is not in PATH, or the profile was not reloaded.

**Solution:**

```powershell
# Check if git is available
Get-Command git -ErrorAction SilentlyContinue

# Reload the profile
. $PROFILE
```

### Modules not found

**Symptom:** Terminal-Icons or PSReadLine do not load.

**Solution:**

```powershell
Install-Module -Name Terminal-Icons -Scope CurrentUser
Install-Module -Name PSReadLine -Scope CurrentUser -Force
```

### Corrupted or outdated cache

**Symptom:** Oh My Posh or Zoxide do not initialize correctly.

**Solution:**

```powershell
Clear-Cache
# Restart the terminal after running
```

### flushdns does not work

**Symptom:** `"flushdns requires Administrator privileges."`

**Solution:** Run the terminal as Administrator or use `sudo flushdns`.

---

## Tests

The project includes six test/benchmark suites:

### 0. Profile Boot Benchmark

`tests/benchmark.ps1` -- Spawns 5+ fresh `pwsh -NoProfile` processes,
measures each module load time individually, and reports per-module breakdown
with average/min/max.

```powershell
.\tests\benchmark.ps1           # default: 5 runs
.\tests\benchmark.ps1 -Runs 10  # 10 runs for better signal
```

#### Sample output

```
Config    71.7 ms
Cache    343.4 ms
Nav         2.0 ms
Git         1.8 ms
System      4.7 ms
PSReadLine 18.0 ms
TextUtils   2.3 ms
Total     443.9 ms

Media: 414ms  Min: 398.7ms  Max: 443.9ms
```

### 1. Unit Tests (cache, system, git, text)

`tests/Unit.Tests.ps1` -- 100 assertions across 4 modules. Fastest
feedback loop for development (~350ms total).

```powershell
.\tests\Unit.Tests.ps1
```

#### Coverage

| Module | Assertions | What it tests |
|---|---|---|
| **Cache** | 30+ | Fingerprints, TTL hot/cold path, rebuild, clear, Terminal-Icons |
| **System** | 12+ | pubip cache/fallback, sudo sanitization |
| **Git** | 9 | gcom/lazyg LASTEXITCODE branching |
| **Text utils** | 10+ | sed validation/backup/cleanup, clipboard, touch |

### 2. POSH_THEME Tests

`tests/POSH_THEME.Tests.ps1` -- 5 assertions verifying the
`$env:POSH_THEME` override mechanism:

```powershell
.\tests\POSH_THEME.Tests.ps1
```

- POSH-01: env var overrides default theme
- POSH-02: unset env var uses atomic
- POSH-03: empty env var treated as unset
- POSH-04: missing theme file falls back to atomic
- POSH-05: warning mentions missing theme name

### 3. Setup Module Tests (TDD)

`tests/Setup.Tests.ps1` -- 32-assertion TDD suite covering the installer
modules:

```powershell
.\tests\Setup.Tests.ps1
```

#### Coverage

| Module | Tested Items |
|---|---|
| **Write-GuiLog** | Synchronized log messages, all 5 types |
| **Core Constants** | RepoOwner, RepoName, RepoZipUrl |
| **Get-WingetPath** | Returns existing file path (or skips if not found) |
| **Get-ProfilePath** | Returns non-null from string or object `$PROFILE` |
| **Install-Profile** | Success, idempotency, missing repo handling |
| **Uninstall-Profile** | Detects own link, removes profile, cleans cache |
| **Orchestrator** | Dry-run creates profile link with dot-source reference |
| **Module Syntax** | Parses all setup `.ps1` files with `Parser.ParseFile` |

### 4. Profile Installation Health Check

`tests/Test-ProfileInstallation.ps1` -- 64 checks across 6 categories:

```powershell
.\tests\Test-ProfileInstallation.ps1 -Detailed
```

| Category | Checks |
|---|---|
| Profile Integrity | Verifies dot-source logic in `$PROFILE` |
| Module Syntax | Parses all 7 profile modules |
| Profile Loading | Measures boot time (WARN at 200ms, FAIL at 500ms) |
| Functions & Aliases | Verifies all 26 functions + 5 aliases |
| Config System | Validates `$script:Config` object |
| Cache System | Validates TTL header (fingerprint + timestamp) |

### 5. Behavioral Integration Tests

`tests/Microsoft.PowerShell_profile.Tests.ps1` -- Custom framework suite
covering performance, config, cache TTL, navigation, file operations, text
processing, system functions, Git functions, and structured error handling:

```powershell
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose
```

---

## Test Integration

### CI/CD Pipeline

The repository uses **GitHub Actions** with one pipeline:

| Pipeline | File | Triggers |
|---|---|---|
| Original CI | `.github/workflows/test.yml` | push/PR to `main` |

The pipeline copies profile + modules to `$PROFILE` path, runs
PSScriptAnalyzer (errors block CI, warnings are informational), then runs
the custom test suites on a Windows runner.

### Framework

All test suites use a custom framework (not Pester) with these functions:
`Test-Result`, `Test-Skip`, `Assert-True`, `Assert-Equal`, `Assert-NotNull`,
`Assert-False`. Tests dynamically verify `$env:__PROFILE_LOADED` and evaluate
the profile in isolation to prevent side-effects, guaranteeing zero
false-positives under `Set-StrictMode -Version Latest`.

### Platform handling in tests

- `docs` and `dtop`: skip location assert if `GetFolderPath()` returns empty
  (Linux)
- `df`: only executed on Windows
- `up2`: verifies grandparent exists before executing
- `pubip`: gracefully handles network unavailability (skip, don't fail)

---

## Technical Notes

### Good decisions

- **LastWriteTime fingerprint** -- uses `LastWriteTime` + file size instead of
  SHA256 (~0ms vs ~43ms)
- **`filter` for `grep`** -- efficient line-by-line pipeline processing
- **`sed` with atomic write + size limit** -- temp file on same volume
  guarantees OS-level rename; 50MB limit prevents DoS
- **Explicit `$script:` scope** -- avoids silent scoping issues
- **`lazyg` with CI detection** -- correct behavior in automated environments
- **`gcmt` instead of `gcm`** -- avoids collision with native `Get-Command`
  alias
- **`gss` instead of `gs`** -- avoids collision with `Get-Service` in PS 5.1
- **`sudo !!`** -- QoL feature robustly implemented using PS history
- **TTL cache (24h)** -- hot path skips `Get-Command` and `Get-FileHash`
  entirely
- **Cross-platform `sudo`** -- Windows via `Start-Process -Verb RunAs`,
  Linux/macOS via native `sudo`

### Observations

- **`sudo` uses `-NoExit`** -- the elevated window does not close after
  executing the command, which may be unexpected for users expecting Unix
  `sudo` behavior
- **`pubip` without configurable timeout** -- timeout is fixed at 3 seconds
  per endpoint
- **Cache TTL is time-based (24h)** -- invalidated by fingerprint change OR
  TTL expiration
- **`sed` does literal replacement** -- no regex support; uses
  `String.Replace()` literal
- **`sed` has 50MB size limit** -- larger files are rejected for DoS
  protection
- **OMP hot path bottleneck (~150ms)** -- `oh-my-posh init` output calls a
  25KB `init.ps1` (667 lines) that creates a dynamic module via
  `New-Module -ScriptBlock { ... }`. Combined with zoxide ~30ms, the cache
  module dominates ~77% of total boot time (~340ms of ~420ms)

### Improvements applied

- **Inline config paths** -- resolved inline in config.ps1, no function
  overhead, saves ~10ms on Windows boot
- **Boot benchmark** -- `tests/benchmark.ps1` provides data-driven measurement
- **Unicode-safe source** -- em dashes replaced with hyphens to fix PS 5.1
  parser corruption

### Possible improvements (not yet implemented)

- Expose `-TimeoutSec` as a parameter in `pubip`
- Support regex in `sed` via `-Regex` parameter
- Add `-WhatIf` to `sed` to preview changes before applying
- Lazy-load OMP on first prompt to save ~150ms boot time

---

*Revision: 07/2026 (v3 -- GUI installer overhaul, theme selection, terminal
themes, POSH_THEME env var, 100 unit tests) -- Compatible with PS 5.1+ / PS
Core 7+ / Windows 10+ / Linux / macOS*
