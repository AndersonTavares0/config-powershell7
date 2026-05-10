# Modules & Features

## Description

This repository contains a custom PowerShell profile (`Microsoft.PowerShell_profile.ps1`) that is automatically loaded in every terminal session. The profile defines functions, aliases, and settings that increase productivity, standardize the environment, and reduce startup time through a TTL-based plugin caching system.

---

## Features

- **TTL Plugin Cache** — 60-minute Time-To-Live for Zoxide and Oh My Posh; hot path skips `Get-Command` and SHA256 entirely (~5ms)
- **Quick navigation** — aliases for directories and filesystem movement
- **Utility functions** — Unix-like equivalents (`touch`, `which`, `grep`, `head`, `tail`, `sed`)
- **Git shortcuts** — full Git workflow with functions and aliases (conditional on git availability)
- **System functions** — cross-platform info, processes, disk, DNS, and public IP
- **Clipboard** — copy and paste via pipeline
- **Privilege elevation** — `sudo` on Windows (UAC), Linux, and macOS
- **Configured PSReadLine** — smart history, key navigation, autocomplete, prediction
- **Boot summary** — displays startup time, modules, and admin status on each session

---

## Usage

When opening a new PowerShell session, the profile loads automatically and displays a boot summary:

```
PS 7.4.2 · OMP:atomic · Zoxide [85ms]
```

The line shows: PS version, loaded modules, startup time color-coded (green < 300ms, yellow < 600ms, red > 600ms). Admin sessions append `[ADMIN]`.

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
| `sed <file> <find> <replace> [-Backup]` | Atomic text replacement in file (50MB limit) | `sed config.txt "old" "new" -Backup` |

### System

| Function | Description | Example |
|---|---|---|
| `pkill <name>` / `k9` | Kill process by name (cross-platform) | `pkill notepad` |
| `pgrep <name>` | List processes by name with details | `pgrep chrome` |
| `flushdns` | Clear DNS cache (cross-platform) | `flushdns` |
| `df` | Show disk usage by volume | `df` |
| `pubip [-Force]` | Display public IP (cached 5 min per session) | `pubip` / `pubip -Force` |
| `sysinfo` | Hardware, OS, platform, and uptime summary | `sysinfo` |

### Git

> Git functions are only created if the `git` command is available in the PATH.

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
| `gcom <msg>` | `git add .` + `git commit -m` (with error checking) | `gcom "feat: add filter"` |
| `lazyg <msg> [-Force]` | `add` + `commit` + `push` (with interactive confirmation) | `lazyg "chore: update deps"` |

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
| `Clear-PluginCache` | `Clear-Cache` | Removes the plugin cache file and prompts terminal restart |
| `Import-TerminalIcons` | `icons` | Loads Terminal-Icons module (with double-load check) |

---

## Performance

### TTL Plugin Cache System

The profile avoids reloading Zoxide and Oh My Posh from scratch every session by using a cache file with a 60-minute Time-To-Live.

**How it works:**

1. On startup, reads the first line of the cache file (`# fp:<hash> ts:<unix_epoch>`).
2. If TTL is still valid (< 60 min), loads the cache directly — **skips `Get-Command` and SHA256 entirely** (~5ms hot path).
3. If TTL has expired, recalculates the SHA256 fingerprint. If unchanged, only updates the timestamp (no rebuild needed).
4. If fingerprint differs (tools updated, theme changed), regenerates the cache.

**Estimated savings:** ~200–300ms per session when the cache is valid (depending on `Get-Command` and plugin init costs).

### PSReadLine

Configured with smart history (no duplicates, up to 5,000 entries), arrow key navigation, and menu autocomplete (Tab). On PS 7+, also enables history prediction with ListView.

### Boot Summary

At the end of loading, the profile displays the total boot time and loaded modules, color-coded:

- 🟢 Green: < 300ms
- 🟡 Yellow: 300–600ms
- 🔴 Red: > 600ms

---

# Technical Reference

## Overview

`Microsoft.PowerShell_profile.ps1` is a startup profile for PowerShell 5.1+/7+ on Windows, Linux, and macOS. It is automatically loaded in every new session via `$PROFILE` and has the following core objectives:

- Minimize boot time through TTL-based plugin caching
- Expose a consistent set of utility aliases and functions
- Configure PSReadLine for an improved command-line editing experience
- Ensure robustness through error handling, explicit scoping, and structured error records

The profile is modular: individual `.ps1` files are dot-sourced in strict loading order (config → cache → navigation → git → system → psreadline → text_utils).

---

## Profile Architecture

The profile is modular, separating responsibilities into individual files imported by the main loader.

```
config-powershell7/
├── .github/workflows/          # CI/CD Automation (1 pipeline)
├── Microsoft.PowerShell_profile.ps1    # Main Loader
├── install.ps1                 # Automated installation script
├── uninstall.ps1               # Safe uninstallation script
├── install.cmd                 # Double-click installer (Windows)
├── uninstall.cmd               # Double-click uninstaller (Windows)
├── lib/                        # Shared Utilities
│   ├── platform.ps1            # Cross-platform detection + elevation check
│   ├── ux-helpers.ps1          # Console output (Write-Ok, Write-Warn, etc.)
│   └── profile-paths.ps1       # Profile path resolution
├── tests/                      # Test suites (custom + Pester)
│   ├── Test-ProfileInstallation.ps1    # Post-install health check
│   ├── Microsoft.PowerShell_profile.Tests.ps1  # Unit tests (custom framework)
│   └── Pester.Tests.ps1               # Pester CI tests
└── modules/
    ├── config/
    │   └── config.ps1                  # Centralized configuration (critical — loaded first)
    ├── cache/
    │   └── cache.ps1                   # TTL cache: Zoxide, Oh-My-Posh, Terminal-Icons
    ├── navigation/
    │   └── navigation.ps1              # Navigation aliases (up, mkcd, la)
    ├── git/
    │   └── git.ps1                     # Git aliases and functions (conditional)
    ├── system/
    │   └── system.ps1                  # Sudo, processes, DNS, IP, sysinfo
    ├── psreadline/
    │   └── psreadline.ps1              # PSReadLine config and keybindings
    └── text_utils/
        └── text_utils.ps1              # Touch, unzip, sed, grep, clipboard
```

---

## Startup Flow

The execution order when opening a new session:

```
1. PowerShell loads $PROFILE automatically (Microsoft.PowerShell_profile.ps1).
2. Guard: checks $env:__PROFILE_LOADED to prevent double-loading.
3. Stopwatch starts for performance measurement.
4. Resolves repository root via $env:__PROFILE_REPO_ROOT or $PSScriptRoot.
5. Loads config module (critical — must succeed, return on failure).
6. Loads remaining modules in try/catch (non-critical — failure in one does not block others):
   ├── cache/cache.ps1:       TTL check → hot path or rebuild → dot-source cache.
   ├── navigation/navigation.ps1: Directory shortcuts (docs, dtop, up, mkcd).
   ├── git/git.ps1:           Git functions (only if git is in PATH).
   ├── system/system.ps1:     Platform-aware system utilities + sudo.
   ├── psreadline/psreadline.ps1: Terminal, history, keybindings.
   └── text_utils/text_utils.ps1: File manipulation (touch, sed, grep).
7. Stopwatch stops and boot summary is displayed.
```

> The function and alias definitions (step 6) are nearly instantaneous. The real boot cost is in the plugin initialization (`cache.ps1`).

---

## Plugin Caching System (TTL)

### Purpose

Avoid the startup cost of `zoxide init powershell` and `oh-my-posh init pwsh` on every session. Each adds ~100ms to boot time.

### Implementation

**Cache format (header line):**
```
# fp:<sha256_hash> ts:<unix_timestamp>
```

**TTL flow (`Initialize-PluginCache`):**

1. **Cache exists + TTL valid (< 60 min):** Load cache directly — **~5ms hot path** (no `Get-Command`, no SHA256).
2. **Cache exists + TTL expired:** Recalculate fingerprint. If unchanged, only update timestamp. If changed, rebuild cache.
3. **No cache:** Full rebuild (Get-Command zoxide + oh-my-posh, SHA256 fingerprint, StringBuilder generation).

**Fingerprint (`Get-PluginFingerprint`):**

The fingerprint is derived from binary paths, file versions (via `VersionInfo`), theme path, theme existence, and theme content hash (SHA256). Any change (tool update, theme switch, theme edit) invalidates the cache.

```powershell
$parts = @(
    $zcmd.Source                     # zoxide binary path
    $zcmd.VersionInfo.FileVersion    # zoxide version
    $ocmd.Source                     # oh-my-posh binary path
    $ocmd.VersionInfo.FileVersion    # oh-my-posh version
    $script:Config.ThemePath         # theme file path
    [int](Test-Path $ThemePath)      # theme existence
    (Get-FileHash $ThemePath -Algorithm SHA256).Hash   # theme content hash
)
# SHA256 with guaranteed Dispose via try/finally
```

**Regeneration (`Update-PluginCache`):**

The cache is a dynamically generated `.ps1` file built via `StringBuilder`. It contains:
- Header: `# fp:<hash> ts:<unix_epoch>`
- Zoxide initialization code (`zoxide init powershell`)
- Oh My Posh initialization code (with specific theme if it exists, or default)
- `$script:StartupModules.Add(...)` lines for the boot summary

**Loading:**

```powershell
if ($needRebuild) { script:Update-PluginCache -zcmd $zcmd -ocmd $ocmd }
if (Test-Path $script:Config.CachePath) { . $script:Config.CachePath }
```

### Cache location

- **Windows:** `$HOME\.cache_pwsh_plugins.ps1`
- **Linux/macOS (XDG):** `$XDG_CACHE_HOME/pwsh/plugins_cache.ps1` (fallback: `$HOME/.cache/pwsh/plugins_cache.ps1`)

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

Checked with `Get-Command Set-PSReadLineOption` before configuring — if unavailable, the block is silently skipped. Prediction features are conditional on PS 7+:

```powershell
if ($script:Config.PSMajor -ge 7) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
}
```

Keybindings: UpArrow (HistorySearchBackward), DownArrow (HistorySearchForward), Tab (MenuComplete), Ctrl+D (DeleteChar), Ctrl+W (BackwardDeleteWord), Ctrl+Left/Right (word navigation).

### Zoxide and Oh My Posh

Initialized via TTL cache. `Update-PluginCache` checks availability with `Get-Command` before including in the cache. Failures are logged with `Write-Warning`.

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

### Navigation

**`mkcd`**
- `[Parameter(Mandatory)]` — enables tab completion and prevents no-argument calls
- Uses `try/catch` with `Write-Error` instead of unhandled `New-Item`
- `-Force` on `New-Item` creates intermediate directories

**`nf`**
- Accepts `ValueFromPipeline` — allows `"file.txt" | nf`
- Processed in `process {}` block to support multiple pipeline items

### Files and Text

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
- Structured `ErrorRecord` via `$PSCmdlet.WriteError()`

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
- **50MB file size limit** — larger files rejected with structured error (DoS protection)
- Writes to a random-named `.tmp` file in the same directory as the target
- `Move-Item` from `.tmp` to target = atomic OS-level rename operation
- Optional `-Backup` creates a `.bak` before replacement
- `.tmp` cleanup in `catch` prevents orphaned files
- Supports `-WhatIf` via `SupportsShouldProcess`

### System

**`pkill`**
- Cross-platform: uses `Stop-Process` on Windows, native `/usr/bin/pkill -f` on Linux/macOS
- Supports `-WhatIf` via `SupportsShouldProcess`
- Structured `ErrorRecord` on failure

**`pgrep`**
- Cross-platform: uses `Where-Object` filter on Windows, native `/usr/bin/pgrep -f` on Linux/macOS
- On Windows: uses `Where-Object { $_.ProcessName -like "*$Name*" }` because `Get-Process -Name` does not accept mid-string wildcards
- Displays: Id, ProcessName, CPU, Mem(MB) formatted
- Structured `ErrorRecord` on failure

**`pubip`**
- Cache in `$script:CachedPublicIP` with 5-minute TTL — avoids multiple requests per session
- `-Force` bypasses cache and fetches fresh value
- 3 fallback endpoints: `api.ipify.org`, `icanhazip.com`, `ifconfig.me/ip`
- 3-second timeout per endpoint
- Catches `[System.Net.WebException]` separately for better diagnostics
- Structured `ErrorRecord` if all endpoints fail

**`sysinfo`**
- Cross-platform: dispatches to platform-specific functions
  - Windows: `Get-WindowsSystemInfo` — uses `Get-CimInstance Win32_OperatingSystem` + `Win32_ComputerSystem`
  - Linux: `Get-LinuxSystemInfo` — reads `/etc/os-release`, `/proc/meminfo`
  - macOS: `Get-MacSystemInfo` — uses `sysctl` for memory and boot time
- macOS uptime: parses `sysctl -n kern.boottime` with regex `sec\s*=\s*(\d+)`, converts via `[DateTimeOffset]::FromUnixTimeSeconds()`
- Returns `PSCustomObject` with platform-specific fields
- Fallback generates a generic object with best-effort data

**`flushdns`**
- Cross-platform: `Clear-DnsClientCache` (Windows Admin), `systemd-resolve --flush-caches` / `nscd -i hosts` (Linux), `dscacheutil -flushcache` + `killall -HUP mDNSResponder` (macOS)
- Windows: checks `$script:Config.IsAdmin` before executing; silent failure with `Write-Warning` if not Admin

**`df`**
- Cross-platform: `Get-Volume` on Windows, native `df -h` on Linux/macOS
- Structured `ErrorRecord` on failure

### Git

**`gcom`**
- Checks `$LASTEXITCODE` after `git add .` — if it fails, does not execute the commit

**`lazyg`**
- Detects interactive environment via `[Environment]::UserInteractive`, `$env:CI`, `$IsLinux`, `$IsMacOS`
- In non-interactive environments (CI, Linux, macOS): skips confirmation (or requires `-Force`)
- Uses `[Console]::ReadLine()` instead of `ReadKey()` — compatible with environments without an interactive console
- Checks `$LASTEXITCODE` after each step (`git add`, `git commit`, `git push`) — failure at any step aborts the rest

### Sudo

**`sudo`**
- Cross-platform: detects Linux/macOS and delegates to native `/usr/bin/sudo` if available
- Windows: `Start-Process -Verb RunAs` with UAC elevation
- Detects `!!` as a special argument and replaces it with the last history command (`Get-History -Count 1`)
- Windows: selects `pwsh` (PS 7+) or `powershell` (PS 5.1) based on `$script:Config.PSMajor`
- Uses `-EncodedCommand` with Unicode Base64 to preserve quotes and special characters in complex commands
- Sanitizes commands: removes null bytes and control characters (U+0000–U+001F except tab/newline)
- Supports `-WhatIf` via `SupportsShouldProcess`
- Structured `ErrorRecord` on failure

---

## Security and Robustness

### Explicit `$script:` scope

All variables shared between functions use explicit `$script:`, preventing leakage into the user session's global scope and avoiding ambiguity in function contexts.

### `script:`-scoped functions

Internal functions (`Get-PluginFingerprint`, `Update-PluginCache`, `Initialize-PluginCache`, `Get-WindowsSystemInfo`, `Get-LinuxSystemInfo`, `Get-MacSystemInfo`, `Test-InteractiveSession`) are declared as `function script:...`, making them invisible to end users and limiting their scope to the module.

### Structured error handling

Critical functions use `[CmdletBinding()]` with `$PSCmdlet.WriteError()` for structured `ErrorRecord` objects, enabling proper `-ErrorAction` support and `$Error` variable integration:

- `pkill`, `pgrep`, `flushdns`, `df`, `pubip` — structured `ErrorRecord` with descriptive error IDs
- `sed`, `unzip` — structured `ErrorRecord` with specific error categories

### No silent failures

- All `catch` blocks log at minimum `Write-Verbose` (informational) or `Write-Warning` (actual failures)
- Zero bare `catch {}` blocks in the codebase
- Plugin init failures write `Write-Warning` (visible to user)
- Cache save failure writes `Write-Warning`

### Guaranteed Dispose

The SHA256 object in `Get-PluginFingerprint` uses `try/finally` to guarantee `Dispose()` even on exception, preventing unmanaged resource leaks.

### Boot summary in scriptblock

The boot summary runs inside the loader file with local variables (`$bootMs`, `$color`, `$moduleList`, `$adminTag`) that do not leak into the user session.

### `$ErrorActionPreference = 'Stop'`

Enforced in all standalone scripts (`install.ps1`, `uninstall.ps1`, test files, CI pipeline).

### ExecutionPolicy

The profile requires `RemoteSigned` or higher at `CurrentUser` scope. Downloaded files must be unblocked with `Unblock-File` to avoid the digital signature error.

### Sudo and privileges

`flushdns` checks `$script:Config.IsAdmin` before executing. `sudo` uses platform-appropriate elevation mechanisms without storing credentials.

---

## Compatibility

| Scenario | Behavior |
|---|---|
| Windows 10+ | Full support — all features enabled |
| Linux (Fedora) | Full support — native `sudo`, XDG paths, native tools |
| macOS | Full support — native `sudo`, `sysctl`, platform detection |
| PS 5.1, without updated PSReadLine | PSReadLine configured without history prediction |
| PS 7+, with PSReadLine | History prediction enabled with ListView |
| No git in PATH | Git module entirely skipped; `Write-Verbose` logs the reason |
| Without Zoxide | Cache generated without Zoxide initialization; `Write-Warning` on init fail |
| Without Oh My Posh | Cache generated without Oh My Posh initialization; `Write-Warning` on init fail |
| Without `atomic.omp.json` theme | Oh My Posh uses default theme automatically |
| CI environment (`$env:CI`) | `lazyg` skips interactive confirmation; `sudo` skips `ShouldProcess` prompts |
| Non-admin Windows session | `flushdns` warns; `sudo` opens UAC prompt |

---

## Performance

### Reference measurements

| Scenario | Expected boot time |
|---|---|
| With Oh My Posh + Zoxide, valid cache (TTL hot path) | < 150ms |
| With Oh My Posh + Zoxide, TTL expired, fingerprint unchanged | < 200ms |
| With Oh My Posh + Zoxide, cache miss (full rebuild) | < 400ms |

### Applied techniques

| Technique | Where | Impact |
|---|---|---|
| TTL cache with hot path | cache.ps1 (`Initialize-PluginCache`) | ~5ms when valid (skips `Get-Command` and SHA256 entirely) |
| Incremental SHA256 fingerprint with versions | `Get-PluginFingerprint` | Invalidates cache on tool updates |
| Theme content hash in fingerprint | `Get-PluginFingerprint` | Invalidates on theme edits |
| `StringBuilder` for cache generation | `Update-PluginCache` | Avoids string concatenation in loop |
| `StringBuilder` in `Copy-ToClipboard` | text_utils.ps1 | Efficiency in long pipelines |
| Single-line cache read | `Initialize-PluginCache` (`-TotalCount 1`) | Avoids reading entire file for TTL check |
| Conditional Git loading | git.ps1 | Avoids failure if git not installed |
| `filter` for `grep` | text_utils.ps1 | Line-by-line processing without buffering |
| `[System.IO.File]` for `sed` | text_utils.ps1 | Consistent encoding between PS 5.1 and 7 |
| 5-min TTL on `pubip` | system.ps1 | Avoids network calls in same session |
| Early return before `Get-Command` | cache.ps1 (`Initialize-PluginCache` hot path) | Saves 40–100ms by deferring `Get-Command zoxide`/`oh-my-posh` to cold path |
| Navigation lazy-init (`docs`, `dtop`) | navigation.ps1 | Saves 2–6ms by deferring `[Environment]::GetFolderPath` to first call |

---

---

## Automated Testing and CI

### Three Test Suites

| Test Suite | Framework | Use |
|---|---|---|
| `tests/Pester.Tests.ps1` | Pester 5.x | CI pipeline — strict invariant tests |
| `tests/Test-ProfileInstallation.ps1` | Custom | Post-install health check — 64 checks across 6 categories |
| `tests/Microsoft.PowerShell_profile.Tests.ps1` | Custom | Behavioral integration — navigation, file ops, error handling |

### Running Tests

```powershell
# Pester CI tests
Invoke-Pester tests/Pester.Tests.ps1

# Post-install health check
.\tests\Test-ProfileInstallation.ps1 -Detailed
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose

# After sourcing the profile:
Test-ProfileInstallation
```

### GitHub Actions (CI/CD)

One pipeline validates every push or pull request to `main`:

- **`test.yml`** — copies profile + modules to `$PROFILE` path, runs custom test suites

Environment: **Windows Server** (`windows-latest`).
