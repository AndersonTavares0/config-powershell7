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

The project includes three test suites:

### 1. Pester Tests (CI)

`tests/Pester.Tests.ps1` — High-integrity Pester test suite used in CI/CD (`powershell-pipeline.yml`). Covers platform, config, cache, git, system, and text_utils modules with invariant-violation tests (Crash > Corrupt principle).

```powershell
Invoke-Pester tests/Pester.Tests.ps1
```

### 2. Profile Installation Health Check

`tests/Test-ProfileInstallation.ps1` — Comprehensive post-installation health check using a custom framework (Strict-Mode ready).

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
| **Module Syntax** | Parses all scripts against strict parser rules |
| **Profile Loading** | Measures boot time (WARN at 200ms, FAIL at 400ms) |
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

### 3. Unit Tests (Custom Framework)

`tests/Microsoft.PowerShell_profile.Tests.ps1` — Custom framework test suite covering performance, config, cache TTL, navigation, file operations, text processing, system functions, Git functions, and structured error handling.

```powershell
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose
```

---

## Test Integration

### CI/CD Pipelines

The repository uses **GitHub Actions** with two pipelines:

| Pipeline | File | Triggers |
|---|---|---|
| **Original CI** | `.github/workflows/test.yml` | push/PR to `main` |
| **Strict CI/CD** | `.github/workflows/powershell-pipeline.yml` | push/PR to `main` |

The strict pipeline (`powershell-pipeline.yml`) has 5 stages:
1. **Static Analysis** — PSScriptAnalyzer with strict rules, no `Write-Host` in modules/lib
2. **Security Audit** — Hardcoded credential detection, `$ErrorActionPreference = 'Stop'` enforcement
3. **Pester Unit Tests** — Coverage targets on core modules (`config.ps1`, `cache.ps1`, `git.ps1`, `system.ps1`, `text_utils.ps1`, `platform.ps1`)
4. **Environmental Validation** — Clean session, no profile leakage
5. **Deploy/Artifact** — Zip packaging with step outputs

### Framework

- `tests/Test-ProfileInstallation.ps1` implements a custom test framework (functions: `Test-Result`, `Test-Skip`, `Assert-True`, `Assert-Equal`, etc.) optimized for diagnostic output.
- `tests/Pester.Tests.ps1` uses Pester 5.x for CI — includes invariant-violation tests that inject illegal states to verify the "Crash > Corrupt" principle.
- `tests/Microsoft.PowerShell_profile.Tests.ps1` uses the same custom framework for behavioral integration tests (navigation, file ops, text processing).

### Test Strategy

The test files dynamically verify `$global:ProfileLoaded` and evaluate the profile in isolation to prevent side-effects, guaranteeing zero false-positives under `Set-StrictMode -Version Latest`.

### Platform handling in tests

- `docs` and `dtop`: check if `GetFolderPath()` returns empty string (Linux) and skip the location assert
- `df`: only executed if platform is Windows
- `up2`: verifies grandparent exists before executing
- `pubip`: gracefully handles network unavailability (skip, don't fail)

---

## Technical Notes

### Good decisions

- **MD5 fingerprint with guaranteed Dispose** — correctly handles unmanaged resource via `try/finally`
- **`filter` for `grep`** — efficient line-by-line pipeline processing
- **`sed` with atomic write + size limit** — temp file on same volume guarantees OS-level rename; 50MB limit prevents DoS
- **Explicit `$script:` scope** — avoids silent scoping issues
- **`lazyg` with CI detection** — correct behavior in automated environments
- **`gcmt` instead of `gcm`** — avoids collision with native `Get-Command` alias
- **`gss` instead of `gs`** — avoids collision with `Get-Service` in PS 5.1
- **`sudo !!`** — QoL feature robustly implemented using PS history
- **TTL cache (60 min)** — hot path skips `Get-Command` and MD5 entirely; fingerprint recalculation only when TTL expires
- **Cross-platform `sudo`** — Windows elevation via `Start-Process -Verb RunAs`, Linux/macOS via native `/usr/bin/sudo`

### Observations

- **`sudo` uses `-NoExit`** — the elevated window does not close after executing the command, which may be unexpected for users expecting Unix `sudo` behavior (close when done)
- **`pubip` without configurable timeout** — timeout is fixed at 3 seconds per endpoint; on slow networks there may be a noticeable delay on the first call
- **Cache TTL is time-based (60 min)** — cache is invalidated by fingerprint change OR TTL expiration, whichever comes first
- **`sed` does literal replacement** — no regex support; uses `String.Replace()` literal, unlike Unix `sed`
- **`sed` has 50MB size limit** — larger files are rejected for DoS protection

### Possible improvements (without changing current behavior)

- Expose `-TimeoutSec` as a parameter in `pubip`
- Support regex in `sed` via `-Regex` parameter
- Add `-WhatIf` to `sed` to preview changes before applying

---

*Revision: 05/2026 — Compatible with PS 5.1+ / PS Core 7+ / Windows 10+ / Linux / macOS*
