# Modules & Features

## Description

This repository contains a custom PowerShell profile
(`Microsoft.PowerShell_profile.ps1`) that loads automatically in every
terminal session. The profile defines functions, aliases, and settings that
increase productivity, standardize the environment, and reduce startup time
through a TTL-based plugin caching system.

---

## Features

- **TTL Plugin Cache** — 24-hour Time-To-Live for Zoxide and Oh My Posh; hot
  path skips `Get-Command` and `Get-FileHash` entirely (~5ms validation +
  ~120ms OMP init + ~30ms zoxide init)
- **Inline Config Paths** — Cache and theme paths resolved inline on Windows
  (no function definition + parameter binding overhead)
- **Quick navigation** — aliases for directories and filesystem movement
- **Utility functions** — Unix-like equivalents (`touch`, `which`, `grep`,
  `head`, `tail`, `sed`)
- **Git shortcuts** — full Git workflow with functions and aliases
  (conditional on git availability)
- **System functions** — cross-platform info, processes, disk, DNS, and
  public IP
- **Clipboard** — copy and paste via pipeline
- **Privilege elevation** — `sudo` on Windows (UAC), Linux, and macOS
- **Configured PSReadLine** — smart history, key navigation, autocomplete,
  prediction
- **Boot summary** — displays startup time, modules, and admin status on
  each session

---

## Usage

When opening a new PowerShell session, the profile loads automatically and
displays a boot summary:

```
PS 7.6.1 . OMP:default . Zoxide [420ms]
```

The line shows: PS version, loaded modules, startup time color-coded
(green < 300ms, yellow < 600ms, red > 600ms). Admin sessions append
`[ADMIN]`.

---

## Aliases

All aliases available in the profile:

| Alias | Function/Command | Description |
|---|---|---|
| `Clear-Cache` | `Clear-PluginCache` | Removes the plugin cache |
| `icons` | `Import-TerminalIcons` | Loads the Terminal-Icons module |
| `cpy` | `Copy-ToClipboard` | Copies pipeline output to clipboard |
| `k9` | `pkill` | Kills a process by name |
| `gss` | `gst` | `git status -sb` |

---

## Functions

### Navigation

| Function | Description | Example |
|---|---|---|
| `docs` | Navigate to `~/Documents` | `docs` |
| `dtop` | Navigate to `~/Desktop` | `dtop` |
| `home` | Navigate to `$HOME` | `home` |
| `up` | Go up one level (`cd ..`) | `up` |
| `up2` | Go up two levels (`cd ..\..`) | `up2` |
| `la` | List files (excluding hidden) in table | `la` |
| `ll` | List files (including hidden) in table | `ll` |
| `Get-ProfileStartDirectory` | Show configured startup fallback directory | `Get-ProfileStartDirectory` |
| `Set-ProfileStartDirectory <path>` | Persist startup fallback via `POWERSHELL_START_DIR` | `Set-ProfileStartDirectory "$HOME"` |
| `Clear-ProfileStartDirectory` | Remove startup fallback override | `Clear-ProfileStartDirectory` |
| `mkcd <path>` | Create directory and enter it | `mkcd projects\new` |
| `nf <file>` | Create empty file | `nf config.json` |

### Files and Text

| Function | Description | Example |
|---|---|---|
| `touch <file>` | Create file or update timestamp | `touch notes.txt` |
| `which <cmd>` | Show command path | `which git` |
| `unzip <file> [dest]` | Extract ZIP (default dest: `.`) | `unzip archive.zip .\output` |
| `head <file> [n]` | Show first n lines (default: 10) | `head log.txt -Lines 5` |
| `tail <file> [n]` | Show last n lines (default: 10) | `tail log.txt -Lines 20` |
| `grep <pattern>` | Filter input via pipeline | `Get-Content log.txt \| grep "error"` |
| `Copy-ToClipboard` / `cpy` | Copy pipeline to clipboard | `cat file.txt \| cpy` |
| `pst` | Paste clipboard content | `pst` |
| `sed <file> <find> <replace>` | Atomic text replacement (50MB limit) | `sed config.txt "old" "new" -Backup` |

### System

| Function | Description | Example |
|---|---|---|
| `pkill <name>` / `k9` | Kill process by name (cross-platform) | `pkill notepad` |
| `pgrep <name>` | List processes by name with details | `pgrep chrome` |
| `flushdns` | Clear DNS cache (cross-platform) | `flushdns` |
| `df` | Show disk usage by volume | `df` |
| `pubip [-Force]` | Display public IP (cached 5 min) | `pubip` / `pubip -Force` |
| `sysinfo` | Hardware, OS, platform, and uptime summary | `sysinfo` |

### Git

> Git functions are only created if the `git` command is available in PATH.

| Function | Git Equivalent | Example |
|---|---|---|
| `gst` / `gss` | `git status -sb` | `gst` |
| `ga` | `git add .` | `ga` |
| `gcmt <msg>` | `git commit -m <msg>` | `gcmt "fix: typo"` |
| `gco <branch>` | `git checkout <branch>` | `gco main` |
| `gpush` | `git push` | `gpush` |
| `gpull` | `git pull` | `gpull` |
| `glog` | `git log --oneline --graph -15` | `glog` |
| `gundo` | `git reset --soft HEAD~1` | `gundo` |
| `gdiff` | `git diff` | `gdiff` |
| `gcl <url>` | `git clone <url>` | `gcl https://github.com/user/repo` |
| `gcom <msg>` | `git add .` + `git commit -m` | `gcom "feat: add filter"` |
| `lazyg <msg>` | `add` + `commit` + `push` (with confirmation) | `lazyg "chore: update deps"` |

### Administration

```powershell
# Open a new elevated PowerShell window
sudo

# Run a specific command as Administrator (Windows) or root (Linux/macOS)
sudo Get-Service

# Re-run the last command from history as Admin
sudo !!
```

### Cache and Plugins

| Function | Alias | Description |
|---|---|---|
| `Clear-PluginCache` | `Clear-Cache` | Removes the plugin cache file and prompts restart |
| `Import-TerminalIcons` | `icons` | Loads Terminal-Icons module (double-load check) |

---

## Performance

### TTL Plugin Cache System

The profile avoids reloading Zoxide and Oh My Posh from scratch every session
by using a cache file with a 24-hour Time-To-Live.

**How it works:**

1. On startup, reads the first line of the cache file
   (`# fp:<hash> ts:<unix_epoch>`).
2. If TTL is still valid (< 24h), loads the cache directly — skips
   `Get-Command` and `Get-FileHash` entirely (~5ms hot path validation, then
   ~120ms for OMP init script execution via dot-source).
3. If TTL has expired, recalculates the fingerprint using `LastWriteTime` +
   file size (not SHA256). If unchanged, only updates the timestamp (no
   rebuild needed).
4. If fingerprint differs (tools updated, theme changed), regenerates the
   cache.

**Estimated savings:** ~200-300ms per session when the cache is valid.
**Benchmark (5 runs, fresh processes):** ~420ms average (77% Cache/OMP, 17%
Config, 4% PSReadLine, 2% others).
Run `.\tests\benchmark.ps1` to measure your actual boot times.

### PSReadLine

Configured with smart history (no duplicates, up to 5,000 entries), arrow key
navigation, and menu autocomplete (Tab). On PS 7+, also enables history
prediction with ListView.

### Boot Summary

At the end of loading, the profile displays the total boot time and loaded
modules, color-coded:

- Green: < 300ms (fast hot path, minimal plugins)
- Yellow: 300-600ms (typical boot with OMP + zoxide)
- Red: > 600ms (cache miss or slow disk)

---

# Technical Reference

## Overview

`Microsoft.PowerShell_profile.ps1` is a startup profile for PowerShell
5.1+/7+ on Windows, Linux, and macOS. It loads automatically in every new
session via `$PROFILE` and has these core objectives:

- Minimize boot time through TTL-based plugin caching
- Expose a consistent set of utility aliases and functions
- Configure PSReadLine for an improved command-line editing experience
- Ensure robustness through error handling, explicit scoping, and structured
  error records

The profile is modular: individual `.ps1` files are dot-sourced in strict
loading order (config -> cache -> navigation -> git -> system -> psreadline ->
text_utils).

---

## Profile Architecture

```
config-powershell7/
├── .github/workflows/          # CI/CD Automation
├── Microsoft.PowerShell_profile.ps1    # Main Loader
├── install.ps1                 # Legacy automated installer
├── uninstall.ps1               # Safe uninstaller
├── install.cmd                 # Double-click GUI launcher
├── uninstall.cmd               # Double-click uninstaller
├── setup.ps1                   # Entry point for new installer
├── setup/modules/
│   ├── core.ps1                # Platform detection, logging
│   ├── deps.ps1                # Dependency installers + theme data
│   ├── profile.ps1             # Profile link management
│   ├── orchestrator.ps1        # Install/uninstall orchestration
│   ├── gui.ps1                 # WPF XAML UI with runspaces
│   └── cli.ps1                 # Terminal menu fallback
├── lib/
│   ├── platform.ps1            # Cross-platform detection + elevation
│   ├── ux-helpers.ps1          # Console output helpers
│   └── profile-paths.ps1       # Profile path resolution
├── tests/
│   ├── benchmark.ps1                    # Boot timing benchmark
│   ├── Unit.Tests.ps1                  # Unit tests (cache, system, git, text)
│   ├── POSH_THEME.Tests.ps1            # 5 env-var theme tests
│   ├── Setup.Tests.ps1                 # Setup module tests
│   ├── Test-ProfileInstallation.ps1    # Post-install health checks
│   └── Microsoft.PowerShell_profile.Tests.ps1  # Integration tests
└── modules/
    ├── config/config.ps1           # Centralized config (critical, first)
    ├── cache/cache.ps1             # TTL cache + lazy loaders
    ├── navigation/navigation.ps1   # Directory shortcuts
    ├── git/git.ps1                 # Git aliases (conditional)
    ├── system/system.ps1           # Sudo, processes, DNS, IP, sysinfo
    ├── psreadline/psreadline.ps1   # PSReadLine config + keybindings
    └── text_utils/text_utils.ps1   # Touch, unzip, sed, grep, clipboard
```

---

## Startup Flow

The execution order when opening a new session:

```
1. PowerShell loads $PROFILE automatically.
2. Guard: checks a process-local global variable to prevent double-loading.
3. Stopwatch starts for performance measurement.
4. Resolves repository root via $PSScriptRoot.
5. Loads config module (critical -- must succeed, return on failure).
6. Loads remaining modules in try/catch (non-critical):
   - cache:    TTL check -> hot path or rebuild -> dot-source cache
   - navigation: Directory shortcuts + startup fallback
   - git:      Git functions (only if git is in PATH)
   - system:   Platform-aware system utilities + sudo
   - psreadline: Terminal, history, keybindings
   - text_utils: File manipulation (touch, sed, grep)
7. Stopwatch stops and boot summary is displayed.
8. Current directory preserved (redirects from System32 if Admin).
```

> The function and alias definitions (step 6) are nearly instantaneous. The
> real boot cost is in plugin initialization (cache.ps1).

---

## Plugin Caching System (TTL)

### Purpose

Avoid the startup cost of `zoxide init powershell` and
`oh-my-posh init pwsh` on every session. Each adds ~100ms to boot time.

### Implementation

**Cache format (header line):**
```
# fp:<fingerprint> ts:<unix_timestamp>
```

The fingerprint is a pipe-separated string (not SHA256) for fast generation.

**TTL flow (`Initialize-PluginCache`):**

1. **Cache exists + TTL valid (< 24h):** Load cache directly — ~5ms hot path
   validation (no `Get-Command`, no `Get-FileHash`), then ~120ms to dot-source
   cache (executes OMP init.ps1).
2. **Cache exists + TTL expired:** Recalculate fingerprint. If unchanged, only
   update timestamp. If changed, rebuild cache.
3. **No cache:** Full rebuild (Get-Command zoxide + oh-my-posh, LastWriteTime
   fingerprint, StringBuilder generation).

**Fingerprint (`Get-PluginFingerprint`):**

Derived from binary paths, file versions (via `VersionInfo`), `LastWriteTime`
of binaries, theme path, theme existence, and theme `LastWriteTime` + file
size (not SHA256). Any change (tool update, theme switch, theme edit)
invalidates the cache.

```powershell
$parts = @(
    $zcmd.Source,.                    # zoxide binary path
    $zcmd.VersionInfo.FileVersion.    # zoxide version
    $zcmd.LastWriteTimeUtc.Ticks.     # zoxide binary LastWriteTime
    $ocmd.Source.                     # oh-my-posh binary path
    $ocmd.VersionInfo.FileVersion.    # oh-my-posh version
    $ocmd.LastWriteTimeUtc.Ticks.     # oh-my-posh binary LastWriteTime
    $script:Config.ThemePath.         # theme file path
    [int](Test-Path $ThemePath).      # theme existence
    "$($theme.Length):$($theme.LastWriteTimeUtc.Ticks)". # theme info
)
$parts -join '|'.                     # plain string, no crypto hash
```

**Cache location:**

- **Windows:** `$HOME\.cache_pwsh_plugins.ps1`
- **Linux/macOS (XDG):** `$XDG_CACHE_HOME/pwsh/plugins_cache.ps1`
  (fallback: `$HOME/.cache/pwsh/plugins_cache.ps1`)

**Manual invalidation:**

```powershell
Clear-PluginCache  # alias: Clear-Cache
# Restart the terminal after running
```

---

## Module Management

### Terminal-Icons

Loaded on demand via `Import-TerminalIcons` (alias: `icons`). Checks if
already loaded before importing:

```powershell
if (Get-Module Terminal-Icons) { return }
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
```

### PSReadLine

Checked with `Get-Command Set-PSReadLineOption` before configuring. Prediction
features are conditional on PS 7+:

```powershell
if ($script:Config.PSMajor -ge 7) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
}
```

Keybindings: UpArrow (HistorySearchBackward), DownArrow (HistorySearchForward),
Tab (MenuComplete), Ctrl+D (DeleteChar), Ctrl+W (BackwardDeleteWord),
Ctrl+Left/Right (word navigation).

### Zoxide and Oh My Posh

Initialized via TTL cache. `Update-PluginCache` checks availability with
`Get-Command` before including in the cache. Failures log via
`Write-Warning`.

---

## POSH_THEME (Runtime Theme Override)

You can switch your Oh My Posh theme at runtime without reinstalling:

```powershell
$env:POSH_THEME = 'montys'
```

The profile reads this variable at boot. Unset or empty falls back to the
theme selected during installation. The profile stub sets
`$env:POSH_THEME` at session start.

---

## Aliases -- Technical View

| Alias | Target | Rationale |
|---|---|---|
| `Clear-Cache` | `Clear-PluginCache` | PS-idiomatic name; alias for convenience |
| `icons` | `Import-TerminalIcons` | Shorthand for interactive use |
| `cpy` | `Copy-ToClipboard` | Equivalent to Unix `xclip`/`pbcopy` |
| `k9` | `pkill` | Container/CLI convention (SIGKILL = 9) |
| `gss` | `gst` | Mnemonic for `git status --short` |

**Note on `gcm`:** Avoided because `gcm` is a native PS alias for
`Get-Command`. The git commit function uses `gcmt` to prevent collision.

**Note on `gs`:** Avoided because it may collide with `Get-Service` in PS 5.1.

---

## Functions -- Technical Detail

### Navigation

**`mkcd`**
- `[Parameter(Mandatory)]` enables tab completion and prevents no-argument
  calls
- Uses `try/catch` with `Write-Error`
- `-Force` on `New-Item` creates intermediate directories

**`nf`**
- Accepts `ValueFromPipeline` for `"file.txt" | nf`
- Processed in `process {}` block for multiple pipeline items

### Files and Text

**`touch`**
- If file exists: updates `LastWriteTime`
- If not: creates with `New-Item -ItemType File -Force`
- Accepts `ValueFromPipeline`

**`which`**
- Uses `(Get-Command $Cmd -ErrorAction SilentlyContinue).Source`
- Emits `Write-Warning` if not found

**`unzip`**
- Default destination: `.` (current directory)
- Uses `Expand-Archive` with `-Force`
- Structured `ErrorRecord` via `$PSCmdlet.WriteError()`

**`head` / `tail`**
- `head`: `Get-Content -TotalCount $Lines`
- `tail`: `Get-Content -Tail $Lines`
- `-Lines` parameter with default value `10`

**`grep`**
- Implemented as `filter` (not `function`) for efficient pipeline processing
- Uses `Select-String -Pattern $Pattern`

**`Copy-ToClipboard` (cpy)**
- `begin/process/end` for correct pipeline accumulation
- Uses `StringBuilder` for efficiency
- `$null` explicitly ignored in `process {}`
- `TrimEnd()` removes trailing newlines

**`sed`**
- Reads with `[System.IO.File]::ReadAllText` (UTF8+BOM) for PS 5.1/7
  compatibility
- **50MB file size limit** with structured error (DoS protection)
- Writes to a random-named `.tmp` file in the same directory
- `Move-Item` from `.tmp` to target = atomic OS-level rename
- Optional `-Backup` creates a `.bak` before replacement
- `.tmp` cleanup in `catch` prevents orphaned files
- Supports `-WhatIf` via `SupportsShouldProcess`

### System

**`pkill`**
- Cross-platform: uses `Stop-Process` on Windows, native `pkill -f` on
  Linux/macOS
- Supports `-WhatIf` via `SupportsShouldProcess`
- Structured `ErrorRecord` on failure

**`pgrep`**
- Cross-platform: `Where-Object` filter on Windows, native `pgrep -f` on
  Linux/macOS
- On Windows: uses `Where-Object { $_.ProcessName -like "*$Name*" }`
  because `Get-Process -Name` does not accept mid-string wildcards
- Displays: Id, ProcessName, CPU, Mem(MB)

**`pubip`**
- Cache in `$script:CachedPublicIP` with 5-minute TTL
- `-Force` bypasses cache and fetches fresh value
- 3 fallback endpoints: `api.ipify.org`, `icanhazip.com`, `ifconfig.me/ip`
- 3-second timeout per endpoint
- Structured `ErrorRecord` if all endpoints fail

**`sysinfo`**
- Cross-platform dispatcher to platform-specific functions:
  - Windows: `Get-WindowsSystemInfo` -- `Get-CimInstance`
  - Linux: `Get-LinuxSystemInfo` -- `/etc/os-release`, `/proc/meminfo`
  - macOS: `Get-MacSystemInfo` -- `sysctl` for memory and boot time
- macOS uptime: parses `sysctl -n kern.boottime` with regex
  `sec\s*=\s*(\d+)`, converts via `[DateTimeOffset]::FromUnixTimeSeconds()`
- Returns `PSCustomObject` with platform-specific fields
- Fallback generates a generic object with best-effort data

**`flushdns`**
- Cross-platform: `Clear-DnsClientCache` (Windows Admin),
  `systemd-resolve --flush-caches` / `nscd -i hosts` (Linux),
  `dscacheutil -flushcache` + `killall -HUP mDNSResponder` (macOS)
- Windows: checks `$script:Config.IsAdmin` before executing

**`df`**
- Cross-platform: `Get-Volume` on Windows, native `df -h` on Linux/macOS
- Structured `ErrorRecord` on failure

### Git

**`gcom`**
- Checks `$LASTEXITCODE` after `git add .` -- if it fails, does not execute
  the commit

**`lazyg`**
- Detects interactive environment via `[Environment]::UserInteractive`,
  `$env:CI`, `$IsLinux`, `$IsMacOS`
- Non-interactive (CI, Linux, macOS): skips confirmation (or requires
  `-Force`)
- Uses `[Console]::ReadLine()` for environments without interactive console
- Checks `$LASTEXITCODE` after each step -- failure at any step aborts

### Sudo

**`sudo`**
- Cross-platform: delegates to native `sudo` on Linux/macOS
- Windows: `Start-Process -Verb RunAs` with UAC elevation
- Detects `!!` as special argument and replaces it with last history command
- Uses `-EncodedCommand` with Unicode Base64 for complex commands
- Sanitizes commands: removes null bytes and control characters
- Supports `-WhatIf` via `SupportsShouldProcess`

---

## Security and Robustness

### Explicit `$script:` scope

All variables shared between functions use explicit `$script:`, preventing
leakage into the user session's global scope.

### `script:`-scoped functions

Internal functions (`Get-PluginFingerprint`, `Update-PluginCache`,
`Initialize-PluginCache`, etc.) are declared as `function script:...`, making
them invisible to end users.

### Structured error handling

Critical functions use `[CmdletBinding()]` with `$PSCmdlet.WriteError()` for
structured `ErrorRecord` objects, enabling `-ErrorAction` support and `$Error`
integration.

### No silent failures

- All `catch` blocks log at minimum `Write-Verbose` or `Write-Warning`
- Zero bare `catch {}` blocks in the codebase
- Plugin init failures write `Write-Warning` (visible to user)

### Guaranteed Dispose

No unmanaged resources in `Get-PluginFingerprint` -- fingerprint uses
`LastWriteTime` + file size string concatenation, no SHA256 or crypto objects
that require `Dispose()`.

### `$ErrorActionPreference = 'Stop'`

Enforced in all standalone scripts (`install.ps1`, `uninstall.ps1`, test
files, CI pipeline).

### ExecutionPolicy

The profile requires `RemoteSigned` or higher at `CurrentUser` scope.
Downloaded files must be unblocked with `Unblock-File` to avoid the digital
signature error.

---

## Compatibility

| Scenario | Behavior |
|---|---|
| Windows 10+ | Full support -- all features enabled |
| Linux (Fedora) | Full support -- native `sudo`, XDG paths |
| macOS | Full support -- native `sudo`, `sysctl` |
| PS 5.1, without updated PSReadLine | Configured without history prediction |
| PS 7+, with PSReadLine | History prediction with ListView |
| No git in PATH | Git module entirely skipped |
| Without Zoxide | Cache generated without Zoxide init |
| Without Oh My Posh | Cache generated without OMP init |
| CI environment (`$env:CI`) | `lazyg` skips confirmation; `sudo` skips prompts |
| Non-admin Windows session | `flushdns` warns; `sudo` opens UAC prompt |

---

## Performance

### Reference measurements

| Scenario | Expected boot time |
|---|---|
| With OMP + Zoxide, valid cache (TTL hot path) | ~420ms |
| With OMP + Zoxide, TTL expired, fingerprint unchanged | ~450ms |
| With OMP + Zoxide, cache miss (full rebuild) | ~650ms |

> Real benchmark (5 runs, fresh pwsh processes): **414ms average** (min
> 398ms, max 444ms). Cache module dominates at ~340ms (77% of boot). Run
> `.\tests\benchmark.ps1` for current measurements.

Interpret cold and warm cache runs separately. A cold run happens after
`Clear-Cache`, TTL expiration, tool updates, or theme changes, and may rebuild
the plugin cache. A warm run has a valid TTL and unchanged fingerprint, so it
uses the hot path. The `Cache` line includes Oh My Posh initialization from the
generated cache, so it is expected to be the largest slice when OMP is enabled.

### Applied techniques

| Technique | Where | Impact |
|---|---|---|
| TTL cache with hot path | cache.ps1 | ~5ms validation when valid |
| LastWriteTime fingerprint | `Get-PluginFingerprint` | ~0ms vs SHA256 ~43ms |
| File size + timestamp in fingerprint | `Get-PluginFingerprint` | Detects edits without SHA256 |
| `StringBuilder` for cache generation | `Update-PluginCache` | Avoids string concatenation |
| Conditional Git loading | git.ps1 | Avoids failure if git absent |
| `filter` for `grep` | text_utils.ps1 | Line-by-line without buffering |
| 5-min TTL on `pubip` | system.ps1 | Avoids network calls per session |
| Navigation lazy-init | navigation.ps1 | Saves 2-6ms at boot |
| Inline config paths | config.ps1 | Eliminates function overhead |

---

## Automated Testing and CI

### Test Suites

| Test Suite | Scope | Description |
|---|---|---|
| `tests/Unit.Tests.ps1` | Unit | Cache, system, git, text utils |
| `tests/POSH_THEME.Tests.ps1` | Theme | POSH_THEME env var override |
| `tests/Setup.Tests.ps1` | Setup | Installer modules |
| `tests/Test-ProfileInstallation.ps1` | Health | Post-install health check |
| `tests/Microsoft.PowerShell_profile.Tests.ps1` | Integration | Behavioral integration |
| `tests/benchmark.ps1` | Benchmark | Boot timing (fresh pwsh processes) |

### Running Tests

```powershell
# Unit tests (fastest feedback)
.\tests\Unit.Tests.ps1

# POSH_THEME tests
.\tests\POSH_THEME.Tests.ps1

# Post-install health check
.\tests\Test-ProfileInstallation.ps1 -Detailed

# Integration tests
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose

# Boot benchmark (5+ runs)
.\tests\benchmark.ps1 -Runs 10
```

### GitHub Actions (CI/CD)

One pipeline validates every push or pull request to `main`:

- **`test.yml`** -- copies profile + modules to `$PROFILE` path, runs
  PSScriptAnalyzer, runs custom test suites on `windows-latest`.
