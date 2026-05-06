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

**Symptom:** `"flushdns requer privilégios de Administrador."`

**Solution:** Run the terminal as Administrator or use `sudo flushdns`.

---


## Tests

The project includes an advanced, Strict-Mode compliant unit testing suite in `tests/Test-ProfileInstallation.ps1`.

### Run

```powershell
cd config-powershell7
.\tests\Test-ProfileInstallation.ps1

# With verbose output
.\tests\Test-ProfileInstallation.ps1 -Verbose
```

### Coverage

| Category | Tested Items |
|---|---|
| **Profile Integrity** | Ensures proper dot-sourcing logic |
| **Module Syntax** | Parses all scripts against strict parser rules |
| **Profile Loading** | Asserts extreme performance (< 200ms) |
| **Functions & Aliases** | Verifies logic existence (Git, System, Files) |
| **Config System** | Verifies object presence and variables |
| **Cache System** | Validates Time-To-Live (TTL) timestamps |

### Expected output

```
  ╔══════════════════════════════════════════════╗
  ║   Profile Installation Health Check          ║
  ╚══════════════════════════════════════════════╝

  Profile Integrity
  ✔ Profile/Type - Profile dot-sources the config
  ...
  ════════════════════════════════════════════
  Results: 57 PASS, 0 FAIL, 0 WARN, 0 SKIP (57 total)
  ════════════════════════════════════════════
```

- 🟢 All passed: profile is working correctly.
- 🔴 Some failed: check dependencies and Execution Policy.

---

# Test Integration

## Test Integration

### Framework

The file `tests/Test-ProfileInstallation.ps1` implements a custom test framework optimized for CI/CD environments.

### Strategy

The test file dynamically verifies `$global:ProfileLoaded` and evaluates the profile in isolation to prevent side-effects, guaranteeing zero false-positives under `Set-StrictMode -Version Latest`.

### Test suites (15 suites)

| # | Suite | Approach |
|---|---|---|
| 1 | Navigation Functions | Executes and verifies `Get-Location` |
| 2 | File Operations (mkcd, nf, touch) | Creates temp files/directories and verifies existence |
| 3 | Text Processing (head, tail) | Creates 5-line file, verifies count and content |
| 4 | System Functions (pkill, pgrep) | Verifies function/alias existence |
| 5 | Helper Functions (which) | Executes and verifies absence of error |
| 6 | Clipboard Functions (cpy, pst) | Verifies existence |
| 7 | Git Functions | Verifies existence of all 13 functions/aliases (skip if git absent) |
| 8 | Plugin Cache System | Verifies cache function and alias existence |
| 9 | Display Functions (la, ll) | Executes and verifies non-null return |
| 10 | Additional Navigation (dtop, up2) | Executes and verifies `Get-Location` |
| 11 | File Operation Utilities (unzip) | Verifies existence |
| 12 | System Information (df, pubip, sysinfo) | Executes (skip df on Linux) and verifies return |
| 13 | Advanced Text Processing (grep, sed) | Verifies existence |
| 14 | Copy-ToClipboard | Verifies existence |
| 15 | flushdns | Verifies existence |

### Platform handling in tests

- `docs` and `dtop`: check if `GetFolderPath()` returns empty string (Linux) and skip the location assert
- `df`: only executed if `$PSVersionTable.OS -match 'Windows'`
- `up2`: verifies grandparent exists before executing

### Test output

```
========================================
PowerShell Profile Unit Tests
========================================
  ✓ PASS: Profile loads without errors
  ✓ PASS: docs function navigates to Documents
  ...
  ✓ PASS: flushdns function exists
========================================
TEST SUMMARY
========================================
Total Tests: XX
Passed:      XX
Failed:      0
========================================
```

Exit code: `0` (success) or `1` (failure).

---

## Technical Notes

### Good decisions

- **MD5 fingerprint with guaranteed Dispose** — correctly handles unmanaged resource
- **`filter` for `grep`** — correct and efficient pipeline processing
- **`sed` with atomic write** — temp file on the same volume guarantees OS-level rename
- **Explicit `$script:`** — avoids silent scoping issues
- **`lazyg` with CI detection** — correct behavior in automated environments
- **`gcmt` instead of `gcm`** — avoids collision with `Get-Command`
- **`gss` instead of `gs`** — avoids collision with `Get-Service`
- **`sudo !!`** — QoL feature robustly implemented using PS history

### Observations

- **`sudo` uses `-NoExit`** — the elevated window does not close after executing the command, which may be unexpected for users expecting Unix `sudo` behavior (close when done)
- **`pubip` without configurable timeout** — timeout is fixed at 3 seconds; on slow networks there may be a noticeable delay on the first call
- **Cache has no time-based TTL** — the cache is invalidated only by fingerprint change, not by time elapsed. If a tool is updated without changing the binary path, the cache will not be regenerated automatically
- **`sed` does literal replacement** — no regex support; uses `String.Replace()` literal, unlike Unix `sed`

### Possible improvements (without changing current behavior)

- Add TTL support to the plugin cache (e.g., expire after N days)
- Expose `-TimeoutSec` as a parameter in `pubip`
- Support regex in `sed` via `-Regex` parameter
- Add `-WhatIf` to `sed` to preview changes before applying

---

*Revision: 04/29/2026 — Compatible with PS 5.1+ / PS Core 7+ / Windows 10+*