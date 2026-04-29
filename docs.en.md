[← Back to readme.en.md](readme.en.md)

# Technical Documentation — PowerShell Profile

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![Tests](https://img.shields.io/badge/Tests-15%20suites-brightgreen)

---

## Table of Contents

1. [Overview](#overview)
2. [Profile Architecture](#profile-architecture)
3. [Startup Flow](#startup-flow)
4. [Plugin Caching System](#plugin-caching-system)
5. [Module Management](#module-management)
6. [Aliases — Technical View](#aliases--technical-view)
7. [Functions — Technical Detail](#functions--technical-detail)
8. [Security and Robustness](#security-and-robustness)
9. [Compatibility](#compatibility)
10. [Performance](#performance)
11. [Test Integration](#test-integration)
12. [Technical Notes](#technical-notes)

---

## Overview

`Microsoft.PowerShell_profile.ps1` is a startup profile for PowerShell 5.1+/7+ on Windows. It is automatically loaded in every new session via `$PROFILE` and has the following core objectives:

- Minimize boot time through plugin caching
- Expose a consistent set of utility aliases and functions
- Configure PSReadLine for an improved command-line editing experience
- Ensure robustness through error handling and explicit scoping

The file is structured into 9 numbered sections, clearly delimited by header comments.

---

## Profile Architecture

```
Microsoft.PowerShell_profile.ps1
│
├── Section 1: INITIALIZATION
│   ├── Boot stopwatch
│   ├── $script: scoped variables
│   ├── PS version detection
│   └── Admin privilege detection
│
├── Section 2: PLUGINS & CACHE
│   ├── Centralized paths (CachePath, ThemePath)
│   ├── Clear-PluginCache / Clear-Cache
│   ├── Import-TerminalIcons / icons
│   ├── Get-PluginFingerprint (script-scoped)
│   ├── Update-PluginCache (script-scoped)
│   └── Cache load/invalidation logic
│
├── Section 3: PSREADLINE
│   ├── Mode and history configuration
│   ├── Key handlers (arrows, Tab, Ctrl+*)
│   └── History prediction (PS 7+ only)
│
├── Section 4: NAVIGATION
│   ├── docs, dtop, home, up, up2
│   ├── la, ll
│   └── mkcd, nf
│
├── Section 5: FILES AND TEXT
│   ├── touch, which, unzip
│   ├── head, tail, grep
│   ├── Copy-ToClipboard / cpy, pst
│   └── sed
│
├── Section 6: SYSTEM
│   ├── pkill / k9, pgrep
│   ├── flushdns, df
│   ├── pubip
│   └── sysinfo
│
├── Section 7: GIT
│   ├── Conditional loading (requires git in PATH)
│   ├── gst/gss, ga, gcmt, gco
│   ├── gpush, gpull, glog, gundo, gdiff
│   ├── gcl, gcom, lazyg
│   └── Alias gss → gst
│
├── Section 8: SUDO
│   └── sudo (!! support, EncodedCommand, PS 5.1/7)
│
└── Section 9: BOOT SUMMARY
    ├── Stop stopwatch
    ├── Set window title (with [ADMIN] if elevated)
    └── Display time and loaded modules
```

---

## Startup Flow

The execution order when opening a new session:

```
1. PowerShell loads $PROFILE automatically
2. Section 1: Stopwatch starts, $script: variables defined
3. Section 2: Plugin cache is checked/loaded
   ├── Current fingerprint calculated (MD5)
   ├── If equal to cache → . $CachePath (fast path)
   └── If different → Update-PluginCache + . $CachePath
4. Section 3: PSReadLine configured (conditionally)
5. Sections 4–8: Functions and aliases defined
6. Section 7 (Git): Loaded only if git is in PATH
7. Section 9: Stopwatch stopped, boot summary displayed
```

> Function definition sections (4–8) are nearly instantaneous. The real boot cost is in section 2 (cache miss) and executing the loaded cache.

---

## Plugin Caching System

### Purpose

Avoid the startup cost of `zoxide init powershell` and `oh-my-posh init pwsh` on every session. Each adds ~100ms to boot time.

### Implementation

**Fingerprint (Get-PluginFingerprint):**

```powershell
$parts = @(
    (Get-Command zoxide     -ErrorAction SilentlyContinue)?.Source
    (Get-Command oh-my-posh -ErrorAction SilentlyContinue)?.Source
    $script:ThemePath
    [int](Test-Path $script:ThemePath)
)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($parts -join '|')
$md5   = [System.Security.Cryptography.MD5]::Create()
try    { [System.BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '' }
finally{ $md5.Dispose() }
```

The fingerprint is derived from binary paths and the existence of the theme file. Any change (tool update, theme switch) invalidates the cache.

**Regeneration (Update-PluginCache):**

The cache is a dynamically generated `.ps1` file built via `StringBuilder`. It contains:
- Zoxide initialization code (`zoxide init powershell`)
- Oh My Posh initialization code (with specific theme if it exists, or default)
- `$script:StartupModules.Add(...)` lines for the boot summary

**Loading:**

```powershell
if ($script:CachedFP -ne $script:CurrentFP) { script:Update-PluginCache }
if (Test-Path $script:CachePath)             { . $script:CachePath }
```

### Cache location

```
$HOME\.cache_pwsh_plugins.ps1
```

### Manual invalidation

```powershell
Clear-PluginCache  # alias: Clear-Cache
# Restart the terminal
```

---

## Module Management

### Terminal-Icons

Loaded on demand via `Import-TerminalIcons` function (alias: `icons`). Checks if already loaded before importing to prevent double-loading:

```powershell
if (Get-Module Terminal-Icons) { return }
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
```

### PSReadLine

Checked with `Get-Command Set-PSReadLineOption` before configuring — if unavailable, the block is silently skipped. Features conditional on PS 7+:

```powershell
if ($script:PSMajor -ge 7) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
}
```

### Zoxide and Oh My Posh

Initialized via cache. `Update-PluginCache` checks availability with `Get-Command` before including in the cache.

---

## Aliases — Technical View

| Alias | Target | Rationale |
|---|---|---|
| `Clear-Cache` | `Clear-PluginCache` | PS-idiomatic name (`Verb-Noun`) kept as primary; alias for convenience |
| `icons` | `Import-TerminalIcons` | Shorthand for interactive use |
| `cpy` | `Copy-ToClipboard` | Equivalent to Unix `xclip`/`pbcopy` |
| `k9` | `pkill` | Container/CLI convention (SIGKILL = 9) |
| `gss` | `gst` | Mnemonic alternative for `git status --short` |

**Note on `gcm`:** The alias `gcm` was intentionally avoided as it is a native PowerShell alias for `Get-Command`. The function uses `gcmt` to prevent collision.

**Note on `gs`:** The alias `gs` was avoided as it may collide with `Get-Service` in PS 5.1 environments.

---

## Functions — Technical Detail

### Section 4: Navigation

**`mkcd`**
- `[Parameter(Mandatory)]` — enables tab completion and prevents no-argument calls
- Uses `try/catch` with `Write-Error` instead of unhandled `New-Item`
- `-Force` on `New-Item` creates intermediate directories

**`nf`**
- Accepts `ValueFromPipeline` — allows `"file.txt" | nf`
- Processed in `process {}` block to support multiple pipeline items

### Section 5: Files and Text

**`touch`**
- If file exists: updates `LastWriteTime` via `(Get-Item $File).LastWriteTime = Get-Date`
- If not: creates with `New-Item -ItemType File -Force`
- Accepts `ValueFromPipeline`

**`which`**
- Uses `(Get-Command $Cmd -ErrorAction SilentlyContinue).Source`
- Emits `Write-Warning` if not found (no exception thrown)

**`unzip`**
- Default destination: `.` (current directory)
- Uses `Expand-Archive` with `-Force` (overwrites)
- `try/catch` with `Write-Error` on failure

**`head` / `tail`**
- `head`: `Get-Content -TotalCount $Lines`
- `tail`: `Get-Content -Tail $Lines`
- `-Lines` parameter with default value `10`

**`grep`**
- Implemented as `filter` (not `function`) — optimized for pipeline, processes line by line
- Uses `Select-String -Pattern $Pattern`

**`Copy-ToClipboard` (cpy)**
- Implemented with `begin/process/end` for correct pipeline accumulation
- Uses `StringBuilder` for efficiency
- `$null` explicitly ignored in `process {}`
- `TrimEnd()` on final result removes trailing newlines

**`sed`**
- Reads with `[System.IO.File]::ReadAllText` with UTF8+BOM encoding (compatible with PS 5.1 and 7)
- Writes to a temporary `.tmp` file in the same directory as the target
- `Move-Item` from `.tmp` to target = atomic OS-level rename operation
- Optional `-Backup` creates a `.bak` before replacement
- `.tmp` cleanup in `catch` prevents orphaned files

### Section 6: System

**`pgrep`**
- Uses `Where-Object { $_.ProcessName -like "*$Name*" }` instead of `-Name` directly, because `Get-Process -Name` does not accept mid-string wildcards
- Displays: Id, ProcessName, CPU, Mem(MB) formatted

**`pubip`**
- Cache in `$script:CachedPublicIP` — avoids multiple requests per session
- `-Force` bypasses cache and fetches fresh value
- 3 fallback endpoints: `api.ipify.org`, `icanhazip.com`, `ifconfig.me/ip`
- 3-second timeout per endpoint
- Catches `[System.Net.WebException]` separately for better diagnostics

**`sysinfo`**
- Primary: `Get-CimInstance Win32_OperatingSystem` + `Win32_ComputerSystem`
- Fallback (if CIM fails): reads `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion`
- Returns `PSCustomObject` with fields: Computer, User, OS, PS, Uptime, RAM_GB

**`flushdns`**
- Checks `$script:IsAdmin` before executing `Clear-DnsClientCache`
- Silent failure with `Write-Warning` if not Admin

### Section 7: Git

**`gcom`**
- Checks `$LASTEXITCODE` after `git add .` — if it fails, does not execute the commit

**`lazyg`**
- Detects interactive environment via `[Environment]::UserInteractive` and `$env:CI`, `$IsLinux`, `$IsMacOS`
- In non-interactive environments (CI, Linux, macOS): skips confirmation (or requires `-Force`)
- Uses `[Console]::ReadLine()` instead of `ReadKey()` — compatible with environments without an interactive console
- Checks `$LASTEXITCODE` after `git add` and `git commit` — failure at any step aborts the rest

### Section 8: Sudo

**`sudo`**
- Detects `!!` as a special argument and replaces it with the last history command (`Get-History -Count 1`)
- Selects `pwsh` (PS 7+) or `powershell` (PS 5.1) based on `$script:PSMajor`
- Uses `-EncodedCommand` with Unicode Base64 to preserve quotes and special characters in complex commands
- Without arguments: opens a new empty elevated session

---

## Security and Robustness

### Explicit `$script:` scope

All variables shared between functions use explicit `$script:`, preventing leakage into the user session's global scope and avoiding ambiguity in function contexts.

### `script:`-scoped functions

`Get-PluginFingerprint` and `Update-PluginCache` are declared as `function script:...`, making them invisible to end users and limiting their scope to the profile file.

### Guaranteed Dispose

The MD5 object in `Get-PluginFingerprint` uses `try/finally` to guarantee `Dispose()` even on exception, preventing unmanaged resource leaks.

### Boot summary in scriptblock

Section 9 runs inside `& { ... }` so local variables (`$ms`, `$color`, `$plugins`, `$admin`) do not leak into the user session.

### Error handling

- `try/catch` in functions with side effects (`mkcd`, `unzip`, `sed`, `sysinfo`, `lazyg`)
- `Write-Error` for fatal function errors
- `Write-Warning` for warning conditions (no permission, endpoint unavailable)
- `Write-Verbose` for diagnostic information (no noise in normal output)
- `-ErrorAction SilentlyContinue` on `Get-Command` and other existence checks

### ExecutionPolicy

The profile requires `RemoteSigned` or higher at `CurrentUser` scope. Downloaded files must be unblocked with `Unblock-File` to avoid the digital signature error.

### Sudo and privileges

`flushdns` checks `$script:IsAdmin` before executing. `sudo` uses `Start-Process -Verb RunAs` to request UAC elevation, without storing credentials.

---

## Compatibility

| Scenario | Behavior |
|---|---|
| PS 5.1, without updated PSReadLine | PSReadLine configured without history prediction |
| PS 7+, with PSReadLine | History prediction enabled with ListView |
| No git in PATH | Entire section 7 skipped; `Write-Verbose` logs the reason |
| Without Zoxide | Cache generated without Zoxide initialization |
| Without Oh My Posh | Cache generated without Oh My Posh initialization |
| Without `atomic.omp.json` theme | Oh My Posh uses default theme automatically |
| Linux/macOS (PS Core) | `lazyg` skips interactive confirmation; `df` and `flushdns` may fail |
| CI environment (`$env:CI`) | `lazyg` detects and skips interactive confirmation |

---

## Performance

### Reference measurements

| Scenario | Expected boot time |
|---|---|
| Without Oh My Posh / Zoxide, valid cache | < 100ms |
| With Oh My Posh + Zoxide, valid cache | < 200ms |
| With Oh My Posh + Zoxide, cache miss | < 400ms (single regeneration) |

### Applied techniques

| Technique | Where | Impact |
|---|---|---|
| Plugin initialization cache | Section 2 | ~200ms saved per session |
| Incremental MD5 fingerprint | `Get-PluginFingerprint` | Invalidates cache only when necessary |
| `StringBuilder` for cache generation | `Update-PluginCache` | Avoids string concatenation in loop |
| `StringBuilder` in `Copy-ToClipboard` | Section 5 | Efficiency in long pipelines |
| Single-line cache read | Section 2 (`-TotalCount 1`) | Avoids reading entire file to verify fingerprint |
| Conditional Git loading | Section 7 | Avoids failure if git not installed |
| `filter` for `grep` | Section 5 | Line-by-line processing without buffering |
| `[System.IO.File]` for `sed` | Section 5 | Consistent encoding between PS 5.1 and 7 |

---

## Test Integration

### Framework

The file `Microsoft.PowerShell_profile.Tests_diff.ps1` implements a custom test framework with:

- `Test-Result` — records result (name, passed/failed, message)
- `Assert-Equal` — equality comparison
- `Assert-True` / `Assert-False` — boolean assertions
- `Assert-NotNull` — null check
- `New-MockFile` / `Remove-MockFile` helpers — create/cleanup temporary files

### Strategy

The test file loads the real profile via `. $PROFILE` at the start. All subsequent tests operate in the real environment. This ensures that what is tested is exactly what the user loads.

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
