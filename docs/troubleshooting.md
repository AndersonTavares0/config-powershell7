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

The project includes four test/benchmark suites:

### 0. Profile Boot Benchmark

`tests/benchmark.ps1` — Spawns 5+ fresh `pwsh -NoProfile` processes, measures each module load time individually, and reports per-module breakdown + average/min/max boot times.

```powershell
.\tests\benchmark.ps1          # default: 5 runs
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

### 1. Setup Module Tests (TDD)

`tests/Setup.Tests.ps1` — 32-assertion TDD suite covering the WPF GUI/CLI installer modules. Uses a custom framework (not Pester).

```powershell
.\tests\Setup.Tests.ps1
```

#### Coverage

| Module | Tested Items |
|---|---|
| **Write-GuiLog** | Synchronized log messages, all 5 types (Info, Step, Ok, Warn, Fail) |
| **Core Constants** | RepoOwner, RepoName, RepoZipUrl |
| **Get-WingetPath** | Returns existing file path (or skips if winget not installed) |
| **Get-ProfilePath** | Returns non-null from string or object `$PROFILE` |
| **Install-Profile** | Success, idempotency, missing repo handling |
| **Uninstall-Profile** | Detects own link, removes profile, cleans cache |
| **Orchestrator** | Dry-run creates profile link with dot-source reference |
| **Module Syntax** | Parses all setup `.ps1` files with `Parser.ParseFile` — zero errors |

### 2. Profile Installation Health Check

`tests/Test-ProfileInstallation.ps1` — Comprehensive post-installation health check (64 checks).

```powershell
cd config-powershell7
.\tests\Test-ProfileInstallation.ps1

# With verbose output
.\tests\Test-ProfileInstallation.ps1 -Detailed

# Or after sourcing the profile:
Test-ProfileInstallation
```

#### Coverage

| Category | Tested Items |
|---|---|
| **Profile Integrity** | Verifies dot-source logic in `$PROFILE` |
| **Module Syntax** | Parses all 7 profile modules against strict parser rules |
| **Profile Loading** | Measures boot time (WARN at 200ms, FAIL at 500ms) |
| **Functions & Aliases** | Verifies existence of all 26 functions + 5 aliases |
| **Config System** | Validates `$script:Config` object and all 8 properties |
| **Cache System** | Validates TTL header (fingerprint + timestamp) |

#### Expected output

```
  ╔══════════════════════════════════════════════╗
  ║   Profile Installation Health Check          ║
  ╚══════════════════════════════════════════════╝

  Profile Integrity
  ✔ Profile/Type — Profile dot-sources the config
  ...
  ════════════════════════════════════════════
  Results: 63 PASS, 0 FAIL, 0 WARN, 0 SKIP (64 total)
  ════════════════════════════════════════════
```

### 3. Behavioral Integration Tests

`tests/Microsoft.PowerShell_profile.Tests.ps1` — Custom framework test suite covering performance, config, cache TTL, navigation, file operations, text processing, system functions, Git functions, and structured error handling.

```powershell
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose
```

---

## Test Integration

### CI/CD Pipeline

The repository uses **GitHub Actions** with one pipeline:

| Pipeline | File | Triggers |
|---|---|---|
| **Original CI** | `.github/workflows/test.yml` | push/PR to `main` |

The pipeline copies profile + modules to `$PROFILE` path and runs the custom test suites.

### Framework

- `tests/Setup.Tests.ps1` uses a custom TDD framework (functions: `Test-Result`, `Test-Skip`, `Assert-True`, `Assert-Equal`, `Assert-NotNull`, `Assert-False`) with 32 assertions across 6 modules.
- `tests/Test-ProfileInstallation.ps1` implements a custom test framework (functions: `Test-Result`, `Test-Skip`, `Assert-True`, `Assert-Equal`, etc.) optimized for diagnostic output. 64 checks.
- `tests/Microsoft.PowerShell_profile.Tests.ps1` uses the same custom framework for behavioral integration tests (navigation, file ops, text processing).
- `tests/benchmark.ps1` uses `[Diagnostics.Stopwatch]` for precise micro-timing across fresh `pwsh -NoProfile` process invocations.

### Test Strategy

The test files dynamically verify `$env:__PROFILE_LOADED` and evaluate the profile in isolation to prevent side-effects, guaranteeing zero false-positives under `Set-StrictMode -Version Latest`.

### Platform handling in tests

- `docs` and `dtop`: check if `GetFolderPath()` returns empty string (Linux) and skip the location assert
- `df`: only executed if platform is Windows
- `up2`: verifies grandparent exists before executing
- `pubip`: gracefully handles network unavailability (skip, don't fail)

---

## Technical Notes

### Good decisions

- **LastWriteTime fingerprint** — uses `LastWriteTime` + file size instead of SHA256 (~0ms vs ~43ms), with guaranteed `try/finally` Dispose on the SHA256 object when it was used
- **`filter` for `grep`** — efficient line-by-line pipeline processing
- **`sed` with atomic write + size limit** — temp file on same volume guarantees OS-level rename; 50MB limit prevents DoS
- **Explicit `$script:` scope** — avoids silent scoping issues
- **`lazyg` with CI detection** — correct behavior in automated environments
- **`gcmt` instead of `gcm`** — avoids collision with native `Get-Command` alias
- **`gss` instead of `gs`** — avoids collision with `Get-Service` in PS 5.1
- **`sudo !!`** — QoL feature robustly implemented using PS history
- **TTL cache (24h)** — hot path skips `Get-Command` and `Get-FileHash` entirely; fingerprint recalculation only when TTL expires; uses `LastWriteTime` + size for fast change detection
- **Cross-platform `sudo`** — Windows elevation via `Start-Process -Verb RunAs`, Linux/macOS via native `/usr/bin/sudo`

### Observations

- **`sudo` uses `-NoExit`** — the elevated window does not close after executing the command, which may be unexpected for users expecting Unix `sudo` behavior (close when done)
- **`pubip` without configurable timeout** — timeout is fixed at 3 seconds per endpoint; on slow networks there may be a noticeable delay on the first call
- **Cache TTL is time-based (24h)** — cache is invalidated by fingerprint change OR TTL expiration, whichever comes first
- **`sed` does literal replacement** — no regex support; uses `String.Replace()` literal, unlike Unix `sed`
- **`sed` has 50MB size limit** — larger files are rejected for DoS protection
- **OMP hot path bottleneck (~150ms)** — the `oh-my-posh init` output calls a 25KB `init.ps1` (667 lines) that creates a dynamic module via `New-Module -ScriptBlock { ... }`. zoxide adds ~30ms for its init functions. Combined, Cache module dominates ~77% of total boot time (~340ms of ~420ms).

### Improvements applied

- **Inline config paths** — `CachePath` and `ThemePath` resolved inline in config.ps1 (no function definition + parameter binding overhead) — saves ~10ms on Windows boot
- **Boot benchmark** — `tests/benchmark.ps1` provides data-driven measurement of each module

### Possible improvements (not yet implemented)

- Expose `-TimeoutSec` as a parameter in `pubip`
- Support regex in `sed` via `-Regex` parameter
- Add `-WhatIf` to `sed` to preview changes before applying
- Lazy-load OMP on first prompt to save ~150ms boot time

---

*Revision: 05/2026 (v2 — Config inline paths, benchmark tool) — Compatible with PS 5.1+ / PS Core 7+ / Windows 10+ / Linux / macOS*
